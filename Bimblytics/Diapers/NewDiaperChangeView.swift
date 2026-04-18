//
//  NewDiaperChangeView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 16/04/2026.
//

import SwiftUI
import SwiftData

struct NewDiaperChangeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\InventoryLocation.name)])
    private var locations: [InventoryLocation]

    @Query(sort: [SortDescriptor(\DiaperSize.code)])
    private var diaperSizes: [DiaperSize]

    @State private var selectedDate: Date = .now
    @State private var selectedLocation: InventoryLocation?
    @State private var selectedSize: DiaperSize?
    @State private var isShowingDiaperSearch: Bool = false

    @State private var peeLevel: DiaperLevel = .medium
    @State private var poopLevel: DiaperLevel = .none

    @State private var notes: String = ""

    var body: some View {
        Form {
            // Date
            Section("When") {
                DatePicker(
                    "Date & time",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            
            // Diaper
            Section("Diaper") {
                Button {
                    isShowingDiaperSearch = true
                } label: {
                    HStack {
                        Text("Model / Size")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(selectedSizeDisplay)
                            .foregroundStyle(selectedSize == nil ? .secondary : .primary)
                        
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Location
            Section("Location") {
                Picker("Inventory location", selection: $selectedLocation) {
                    Text("Select").tag(Optional<InventoryLocation>.none)
                    
                    ForEach(locations) { location in
                        Text(location.name)
                            .tag(Optional(location))
                    }
                }

                if let remainingStockInSelectedLocation {
                    LabeledContent("Remaining stock") {
                        Text("\(remainingStockInSelectedLocation)")
                            .foregroundStyle(remainingStockInSelectedLocation > 0 ? AppColors.primary : AppColors.accent)
                    }

                    if remainingStockInSelectedLocation == 0 {
                        Text("No stock is available for the selected diaper in this location.")
                            .font(.footnote)
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }

            // Levels
            Section("Levels") {
                levelPicker(
                    title: "Pee",
                    selection: $peeLevel,
                    systemImage: "drop.fill"
                )
                
                levelPicker(
                    title: "Poop",
                    selection: $poopLevel,
                    systemImage: "circle.fill"
                )
            }

            // Notes
            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Diaper change")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(!canSave)
            }
        }
        .sheet(isPresented: $isShowingDiaperSearch) {
            NavigationStack {
                DiaperCatalogSearchView { size in
                    selectedSize = size
                    isShowingDiaperSearch = false
                }
            }
            .presentationDetents([.large])
        }
    }

    private var canSave: Bool {
        guard selectedSize != nil, selectedLocation != nil else {
            return false
        }

        guard let remainingStockInSelectedLocation else {
            return false
        }

        return remainingStockInSelectedLocation > 0
    }

    private var remainingStockInSelectedLocation: Int? {
        guard let selectedSize, let selectedLocation else {
            return nil
        }

        return selectedLocation.inventoryItems.first(where: { item in
            item.diaperSize?.persistentModelID == selectedSize.persistentModelID
        })?.quantityOnHand ?? 0
    }

    private var hasStockInSelectedLocation: Bool {
        guard let remainingStockInSelectedLocation else {
            return false
        }

        return remainingStockInSelectedLocation > 0
    }

    private func save() {
        guard hasStockInSelectedLocation else {
            return
        }

        let event = DiaperChangeEvent(
            date: selectedDate,
            diaperSize: selectedSize,
            location: selectedLocation,
            peeLevel: peeLevel,
            poopLevel: poopLevel,
            notes: notes.isEmpty ? nil : notes
        )

        modelContext.insert(event)
        dismiss()
    }

    private var selectedSizeDisplay: String {
        guard let selectedSize else {
            return "Select"
        }

        return [
            selectedSize.model?.brand?.name,
            selectedSize.model?.name,
            selectedSize.displayName
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    @ViewBuilder
    private func levelPicker(
        title: String,
        selection: Binding<DiaperLevel>,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)

            Slider(
                value: Binding(
                    get: { Double(selection.wrappedValue.rawValue) },
                    set: { selection.wrappedValue = DiaperLevel(rawValue: Int($0.rounded())) ?? .none }
                ),
                in: 0...4,
                step: 1
            )

            HStack {
                Text("0")
                Spacer()
                Text("4")
            }
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)

            Text(selection.wrappedValue.description)
                .font(.footnote)
                .foregroundStyle(AppColors.primary)
        }
    }
}

#Preview("New Diaper Change") {
    NavigationStack {
        NewDiaperChangeView()
    }
    .modelContainer(DiaperInventoryPreviewData.makeContainer())
}

#Preview("New Diaper Change Dark") {
    NavigationStack {
        NewDiaperChangeView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(DiaperInventoryPreviewData.makeContainer())
}
