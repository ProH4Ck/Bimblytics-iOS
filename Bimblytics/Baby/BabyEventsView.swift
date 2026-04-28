//
//  BabyEventsView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 27/04/2026.
//

import SwiftUI
import SwiftData

struct BabyEventsView: View {
    let baby: Baby
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var events: [RecentEvent] = []
    @State private var isLoading = false
    @State private var hasMoreEvents = true
    @State private var loadedLimit = 20
    
    private let pageSize = 20
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(events) { event in
                    RecentEventRow(
                        event: event,
                        onDeleteTapped: {}
                    )
                    .listRowBackground(AppColors.surface)
                    .onAppear {
                        loadMoreIfNeeded(currentEvent: event)
                    }
                }
                
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(AppColors.background)
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
            .scrollContentBackground(.hidden)
            .task {
                loadEvents(reset: true)
            }
        }
        .padding(16)
        .background(AppColors.background)
        .navigationTitle("All events")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func loadMoreIfNeeded(currentEvent: RecentEvent) {
        guard hasMoreEvents else {
            return
        }
        
        guard currentEvent.id == events.last?.id else {
            return
        }
        
        loadedLimit += pageSize
        loadEvents(reset: false)
    }
    
    private func loadEvents(reset: Bool) {
        guard !isLoading else {
            return
        }
        
        if reset {
            loadedLimit = pageSize
            hasMoreEvents = true
        }
        
        isLoading = true
        
        let fetchedEvents = fetchEvents(limit: loadedLimit + 1)
        events = Array(fetchedEvents.prefix(loadedLimit))
        hasMoreEvents = fetchedEvents.count > loadedLimit
        isLoading = false
    }
    
    private func fetchEvents(limit: Int) -> [RecentEvent] {
        let babyId = baby.id
        var result: [RecentEvent] = []
        
        var diaperDescriptor = FetchDescriptor<DiaperChangeEvent>(
            predicate: #Predicate<DiaperChangeEvent> { event in
                event.babyId == babyId
            },
            sortBy: [SortDescriptor(\DiaperChangeEvent.date, order: .reverse)]
        )
        diaperDescriptor.fetchLimit = limit
        
        if let diaperChanges = try? modelContext.fetch(diaperDescriptor) {
            result.append(contentsOf: diaperChanges.map { change in
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
        
        var feedingDescriptor = FetchDescriptor<FeedingEvent>(
            predicate: #Predicate<FeedingEvent> { event in
                event.babyId == babyId
            },
            sortBy: [SortDescriptor(\FeedingEvent.eventDate, order: .reverse)]
        )
        feedingDescriptor.fetchLimit = limit
        
        if let feedingEvents = try? modelContext.fetch(feedingDescriptor) {
            result.append(contentsOf: feedingEvents.map { feeding in
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
        
        return result.sorted { lhs, rhs in
            lhs.date > rhs.date
        }
    }
}

#Preview("Baby Events") {
    struct BabyEventsPreviewContainer: View {
        @Query(sort: [SortDescriptor(\Baby.name)]) private var babies: [Baby]
        var body: some View {
            NavigationStack {
                BabyEventsView(baby: babies.first!)
            }
        }
    }

    return BabyEventsPreviewContainer()
        .modelContainer(PreviewData.makeContainer())
}

#Preview("Baby Events Dark") {
    struct BabyEventsPreviewContainer: View {
        @Query(sort: [SortDescriptor(\Baby.name)]) private var babies: [Baby]
        var body: some View {
            NavigationStack {
                BabyEventsView(baby: babies.first!)
            }
        }
    }

    return BabyEventsPreviewContainer()
        .modelContainer(PreviewData.makeContainer())
        .preferredColorScheme(.dark)
}
