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
    @State private var showingFeedingForm = false
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
            .navigationBarTitleDisplayMode(.large)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingBabyList = true
                    } label: {
                        Image(systemName: "person.2.circle")
                            .foregroundColor(AppColors.primary)
                    }
                    .accessibilityLabel("Baby list")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink {
                            DiaperInventoryOverviewView()
                        } label: {
                            Label {
                                Text("Diaper inventory")
                            } icon: {
                                Image("DiaperIcon")
                                    .renderingMode(.template)
                            }
                        }

                        NavigationLink {
                            FoodCatalogView()
                        } label: {
                            Label("Food catalog", systemImage: "fork.knife")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(AppColors.primary)
                    }
                    .accessibilityLabel("Management options")
                }
            }
            .sheet(isPresented: $showingDiaperForm) {
                if let selectedBabyID {
                    NewDiaperChangeView(babyId: selectedBabyID)
                }
            }
            .sheet(isPresented: $showingFeedingForm) {
                if let selectedBabyID {
                    NewFeedingEventView(babyId: selectedBabyID)
                }
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
            } message: { event in
                switch event.kind {
                case .diaperChange:
                    Text("This will delete the diaper change event and its related stock movement.")
                case .feeding:
                    Text("This will delete the feeding event.")
                }
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
                    case .feeding:
                        return true
                    }
                }

                if !items.isEmpty {
                    sectionHeader(title: "Quick actions")

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12, alignment: .top)],
                        spacing: 12
                    ) {
                        ForEach(items) { item in
                            Button {
                                handle(operation: item)
                            } label: {
                                OperationTile(item: item)
                            }
                            .buttonStyle(.plain)
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

                NavigationLink {
                    BabyEventsView(baby: baby)
                } label: {
                    HStack {
                        Text("View all events")
                            .font(.body.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(AppColors.primary)
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
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AppColors.background)
    }

    private func handle(operation: OperationItem) {
        switch operation.kind {
        case .diaper:
            showingDiaperForm = true
        case .feeding:
            showingFeedingForm = true
        }
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

    private func operations(for baby: Baby) -> [OperationItem] {
        return [
            OperationItem(
                icon: Image("DiaperIcon"),
                title: "Diaper change",
                subtitle: "Track the latest diaper change",
                colors: [AppColors.surface],
                kind: .diaper
            ),
            OperationItem(
                icon: Image("BabyBottleIcon"),
                title: "Feeding",
                subtitle: "Track baby feeding",
                colors: [AppColors.surface],
                kind: .feeding
            )
        ]
    }

    private func recentEvents(for baby: Baby) -> [RecentEvent] {
        let babyId = baby.id

        var events: [RecentEvent] = []

        let diaperDescriptor = FetchDescriptor<DiaperChangeEvent>(
            predicate: #Predicate<DiaperChangeEvent> { event in
                event.babyId == babyId
            },
            sortBy: [SortDescriptor(\DiaperChangeEvent.date, order: .reverse)]
        )

        if let diaperChanges = try? modelContext.fetch(diaperDescriptor) {
            events.append(contentsOf: diaperChanges.map { change in
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
                    kind: .diaperChange(change),
                    icon: "drop.fill",
                    title: title,
                    subtitle: nil,
                    date: change.date,
                    color: AppColors.primary
                )
            })
        }

        let feedingDescriptor = FetchDescriptor<FeedingEvent>(
            predicate: #Predicate<FeedingEvent> { event in
                event.babyId == babyId
            },
            sortBy: [SortDescriptor(\FeedingEvent.eventDate, order: .reverse)]
        )

        if let feedingEvents = try? modelContext.fetch(feedingDescriptor) {
            events.append(contentsOf: feedingEvents.map { feeding in
                RecentEvent(
                    kind: .feeding(feeding),
                    icon: "fork.knife",
                    title: "Feeding · \(feeding.foodName)",
                    subtitle: feeding.quantityDisplayText,
                    date: feeding.eventDate,
                    color: AppColors.accent
                )
            })
        }

        return Array(
            events
                .sorted { lhs, rhs in
                    lhs.date > rhs.date
                }
                .prefix(5)
        )
    }

    private func delete(event: RecentEvent) {
        do {
            switch event.kind {
            case .diaperChange(let changeEvent):
                if let stockMovementId = changeEvent.stockMovementId,
                   let linkedMovement = linkedStockMovement(withId: stockMovementId) {
                    if let inventoryItem = linkedMovement.inventoryItem {
                        inventoryItem.quantityOnHand -= linkedMovement.quantityDelta
                        inventoryItem.updatedAt = .now
                    }

                    modelContext.delete(linkedMovement)
                }

                modelContext.delete(changeEvent)
            case .feeding(let feedingEvent):
                modelContext.delete(feedingEvent)
            }

            try modelContext.save()
        } catch {
            // Keep current UX simple for now.
        }

        pendingEventDeletion = nil
    }

    private func linkedStockMovement(withId id: String) -> DiaperStockMovement? {
        let descriptor = FetchDescriptor<DiaperStockMovement>()

        guard let movements = try? modelContext.fetch(descriptor) else {
            return nil
        }

        return movements.first(where: { movement in
            String(describing: movement.persistentModelID) == id
        })
    }
}

struct RecentEvent: Identifiable, Hashable {
    let id = UUID()
    let kind: RecentEventKind
    let icon: String
    let title: String
    let subtitle: String?
    let date: Date
    let color: Color
}

enum RecentEventKind: Hashable {
    case diaperChange(DiaperChangeEvent)
    case feeding(FeedingEvent)
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

                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }

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

private struct NewFeedingEventView: View {
    let babyId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<FoodUnit> { !$0.isArchived },
        sort: [
            SortDescriptor(\FoodUnit.sortOrder),
            SortDescriptor(\FoodUnit.name)
        ]
    )
    private var units: [FoodUnit]

    @State private var eventDate: Date = .now
    @State private var selectedFood: FoodItem?
    @State private var selectedUnit: FoodUnit?
    @State private var quantityText: String = ""
    @State private var notes: String = ""
    @State private var isShowingFoodPicker = false

    private var quantity: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        selectedFood != nil && selectedUnit != nil && (quantity ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker(
                        "Date and time",
                        selection: $eventDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Food") {
                    Button {
                        isShowingFoodPicker = true
                    } label: {
                        HStack {
                            Text("Food")
                            Spacer()
                            Text(selectedFood?.name ?? "Select")
                                .foregroundStyle(selectedFood == nil ? AppColors.textSecondary : AppColors.textPrimary)
                        }
                    }

                    Picker("Unit", selection: $selectedUnit) {
                        Text("Select")
                            .tag(Optional<FoodUnit>.none)

                        ForEach(units) { unit in
                            Text(unitLabel(for: unit))
                                .tag(Optional(unit))
                        }
                    }
                }

                Section("Quantity") {
                    TextField("Quantity", text: $quantityText)
                        .keyboardType(.decimalPad)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New feeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!canSave)
                    .accessibilityLabel("Save feeding")
                }
            }
            .sheet(isPresented: $isShowingFoodPicker) {
                NavigationStack {
                    FoodCatalogView { food in
                        selectedFood = food
                        selectedUnit = food.defaultUnit ?? selectedUnit
                        isShowingFoodPicker = false
                    }
                    .navigationTitle("Select food")
                }
            }
            .onChange(of: selectedFood) { _, newValue in
                if selectedUnit == nil {
                    selectedUnit = newValue?.defaultUnit
                }
            }
        }
    }

    private func save() {
        guard let selectedFood,
              let selectedUnit,
              let quantity,
              quantity > 0 else {
            return
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let event = FeedingEvent(
            babyId: babyId,
            eventDate: eventDate,
            foodName: selectedFood.name,
            foodCategoryName: selectedFood.category?.name,
            quantity: quantity,
            unitName: selectedUnit.name,
            unitSymbol: selectedUnit.symbol,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            foodItem: selectedFood
        )

        modelContext.insert(event)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save feeding event: \(error.localizedDescription)")
        }
    }

    private func unitLabel(for unit: FoodUnit) -> String {
        let trimmedSymbol = unit.symbol.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSymbol.isEmpty {
            return unit.name
        }

        return "\(unit.name) (\(trimmedSymbol))"
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
