//
//  NewFeedingEventView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 29/04/2026.
//

import SwiftUI
import SwiftData

struct NewFeedingEventView: View {
    let babyId: UUID
    private let familyId: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query
    private var units: [FoodUnit]

    init(babyId: UUID, familyId: String? = nil) {
        self.babyId = babyId
        self.familyId = familyId
        _units = Query(
            filter: #Predicate<FoodUnit> { unit in
                unit.familyId == familyId && !unit.isArchived
            },
            sort: [
                SortDescriptor(\FoodUnit.sortOrder),
                SortDescriptor(\FoodUnit.name)
            ]
        )
    }

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
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Text(selectedFood?.name ?? "Select")
                                .foregroundStyle(selectedFood == nil ? AppColors.primary : AppColors.textPrimary)
                        }
                    }

                    Picker("Unit", selection: $selectedUnit) {
                        Text("Select")
                            .tag(Optional<FoodUnit>.none)
                            .foregroundStyle(AppColors.primary)

                        ForEach(units) { unit in
                            Text(unitLabel(for: unit))
                                .tag(Optional(unit))
                        }
                    }
                    .tint(AppColors.primary)
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
                    FoodCatalogView(familyId: familyId) { food in
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

private struct NewFeedingEventPreviewContainer: View {
    @Query(sort: [SortDescriptor(\Baby.name)]) private var babies: [Baby]

    var body: some View {
        if let baby = babies.first {
            NewFeedingEventView(babyId: baby.id)
        } else {
            ContentUnavailableView(
                "No baby",
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: Text("Preview data does not contain any baby.")
            )
        }
    }
}

#Preview("New Feeding Event") {
    NewFeedingEventPreviewContainer()
        .modelContainer(PreviewData.makeContainer())
}

#Preview("New Feeding Event Dark") {
    NewFeedingEventPreviewContainer()
        .modelContainer(PreviewData.makeContainer())
        .preferredColorScheme(.dark)
}
