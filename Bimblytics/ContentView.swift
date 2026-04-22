//
//  ContentView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 04/04/2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: [SortDescriptor(\Baby.name)]) private var babies: [Baby]
    @State private var selectedBabyID: UUID?
    @State private var showingDiaperForm = false
    @State private var showingBabyList = false
    @State private var pendingEventDeletion: RecentEvent?
    @State private var isShowingDeleteEventAlert = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @Environment(\.modelContext) private var modelContext

    private var shouldShowOnboarding: Bool {
        guard !ProcessInfo.processInfo.isRunningForPreviews else {
            return false
        }

        return !hasCompletedOnboarding || babies.isEmpty
    }

    private var selectedBaby: Baby? {
        guard let selectedBabyID else {
            return babies.first
        }

        return babies.first(where: { $0.id == selectedBabyID }) ?? babies.first
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedBabyID) {
                ForEach(babies) { baby in
                    page(for: baby)
                        .tag(Optional(baby.id))
                }
            }
            .background(AppColors.background)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .navigationTitle(selectedBaby?.name ?? "Bimblytics")
            .navigationSubtitle(Text(selectedBaby?.ageText() ?? ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingBabyList = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundColor(AppColors.primary)
                    }
                    .accessibilityLabel("Baby list")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DiaperInventoryOverviewView()
                    } label: {
                        Image("DiaperIcon")
                            .renderingMode(.template)
                            .foregroundColor(AppColors.primary)
                    }
                    .accessibilityLabel("Diaper inventory")
                }
               
            }
            .sheet(isPresented: $showingDiaperForm) {
                NewDiaperChangeView(babyId: selectedBabyID!)
            }
            .sheet(isPresented: $showingBabyList) {
                BabyListView()
            }
            .alert("Delete event?", isPresented: $isShowingDeleteEventAlert, presenting: pendingEventDeletion) { event in
                Button("Delete", role: .destructive) {
                    delete(event: event)
                }
                Button("Cancel", role: .cancel) {
                    pendingEventDeletion = nil
                }
            } message: { _ in
                Text("This will delete the diaper change event and its related stock movement.")
            }
            .onAppear {
                ensureSelectedBaby()
            }
            .onChange(of: babies) { _, _ in
                ensureSelectedBaby()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { shouldShowOnboarding }, set: { _ in })) {
            OnboardingView { newBaby in
                modelContext.insert(newBaby)
                selectedBabyID = newBaby.id
                hasCompletedOnboarding = true
            }
        }
    }

    private func ensureSelectedBaby() {
        guard let firstBaby = babies.first else {
            selectedBabyID = nil
            return
        }

        guard let selectedBabyID else {
            self.selectedBabyID = firstBaby.id
            return
        }

        let containsSelectedBaby = babies.contains(where: { $0.id == selectedBabyID })
        if !containsSelectedBaby {
            self.selectedBabyID = firstBaby.id
        }
    }


    @ViewBuilder
    private func page(for baby: Baby) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let items = operations(for: baby).filter { item in
                    switch item.kind {
                    case .diaper:
                        return baby.diaperEnabled
                    }
                }

                if !items.isEmpty {
                    sectionHeader(title: "Quick actions")

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12, alignment: .top)],
                        spacing: 12
                    ) {
                        ForEach(items) { item in
                            switch item.kind {
                            case .diaper:
                                Button {
                                    showingDiaperForm = true
                                } label: {
                                    OperationTile(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                let events = recentEvents(for: baby)
                sectionHeader(title: "Latest events")

                if events.isEmpty {
                    emptyEventsCard
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            RecentEventRow(
                                event: event,
                                onDeleteTapped: {
                                    pendingEventDeletion = event
                                    isShowingDeleteEventAlert = true
                                }
                            )

                            if index != events.count - 1 {
                                Divider()
                                    .overlay(AppColors.primary.opacity(0.08))
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AppColors.background)
    }

    @ViewBuilder
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyEventsCard: some View {
        Text("No recent events")
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
            )
    }

    private func lastEventText(date: Date?, prefix: String) -> String {
        guard let date else { return "\(prefix): mai" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return "\(prefix): \(relative)"
    }

    private func operations(for baby: Baby) -> [OperationItem] {
        return [
            OperationItem(
                icon: Image("DiaperIcon"),
                title: "Diaper change",
                subtitle: "Track the latest diaper change",
                colors: [AppColors.surface],
                kind: .diaper
            )
        ]
    }
    
    private func recentEvents(for baby: Baby) -> [RecentEvent] {
        let babyId = baby.id

        let descriptor = FetchDescriptor<DiaperChangeEvent>(
            predicate: #Predicate<DiaperChangeEvent> { event in
                event.babyId == babyId
            },
            sortBy: [SortDescriptor(\DiaperChangeEvent.date, order: .reverse)]
        )

        do {
            let diaperChanges = try modelContext.fetch(descriptor)

            return Array(diaperChanges.prefix(5)).map { change in
                let diaperTitle = [
                    change.diaperSize?.model?.brand?.name,
                    change.diaperSize?.model?.name,
                    change.diaperSize?.displayName
                ]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " • ")

                let title: String
                if diaperTitle.isEmpty {
                    title = "Diaper change"
                } else {
                    title = "Diaper change · \(diaperTitle)"
                }

                return RecentEvent(
                    changeEvent: change,
                    icon: "drop.fill",
                    title: title,
                    date: change.date,
                    color: AppColors.primary
                )
            }
        } catch {
            return []
        }
    }

    private func delete(event: RecentEvent) {
        let changeEvent = event.changeEvent

        do {
            if let stockMovementId = changeEvent.stockMovementId,
               let linkedMovement = modelContext.model(for: stockMovementId) as? DiaperStockMovement {
                if let inventoryItem = linkedMovement.inventoryItem {
                    inventoryItem.quantityOnHand -= linkedMovement.quantityDelta
                    inventoryItem.updatedAt = .now
                }

                modelContext.delete(linkedMovement)
            }

            modelContext.delete(changeEvent)
            try modelContext.save()
        } catch {
            // Keep current UX simple for now.
        }

        pendingEventDeletion = nil
    }
}

struct RecentEvent: Identifiable, Hashable {
    let id = UUID()
    let changeEvent: DiaperChangeEvent
    let icon: String
    let title: String
    let date: Date
    let color: Color
}

struct RecentEventRow: View {
    let event: RecentEvent
    let onDeleteTapped: () -> Void

    private var relativeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: event.date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(event.color.opacity(0.14))
                Image(systemName: event.icon)
                    .font(.headline)
                    .foregroundStyle(event.color)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                Text(relativeText)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 0)

            Menu {
                Button(role: .destructive) {
                    onDeleteTapped()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Event actions")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

#Preview("ContentView") {
    ContentView()
        .background(AppColors.background)
        .modelContainer(PreviewData.makeContainer())
        .tint(AppColors.primary)
}

#Preview("ContentView - Dark") {
    ContentView()
        .background(AppColors.background)
        .modelContainer(PreviewData.makeContainer())
        .tint(AppColors.primary)
        .preferredColorScheme(.dark)
}

private extension ProcessInfo {
    var isRunningForPreviews: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
