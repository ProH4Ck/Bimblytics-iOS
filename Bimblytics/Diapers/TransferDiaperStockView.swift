//
//  TransferDiaperStockView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 07/04/2026.
//


import SwiftUI
import SwiftData

struct TransferDiaperStockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(
        filter: #Predicate<InventoryLocation> { location in
            !location.isArchived
        },
        sort: [
            SortDescriptor(\InventoryLocation.sortOrder),
            SortDescriptor(\InventoryLocation.name)
        ]
    )
    private var locations: [InventoryLocation]
    
    let inventoryItem: DiaperInventoryItem
    
    @State private var quantityText: String = ""
    @State private var selectedDestinationLocationId: PersistentIdentifier?
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false
    
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 12)
    ]
    
    var body: some View {
        Form {
            Section("Transfer") {
                TextField("Quantity", text: $quantityText)
                    .keyboardType(.numberPad)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(destinationLocations) { location in
                        destinationTile(for: location)
                    }
                }
                
                if let selectedDestinationLocation {
                    LabeledContent("Selected destination", value: selectedDestinationLocation.name)
                }

                if let destinationStockAfterTransfer {
                    LabeledContent("New destination total") {
                        Text("\(destinationStockAfterTransfer)")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            
            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle("Transfer stock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveTransfer()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
                .disabled(!canSave || isSaving)
            }
        }
    }
    
    private var destinationLocations: [InventoryLocation] {
        let currentLocationId = inventoryItem.location?.persistentModelID
        
        return locations.filter { location in
            location.persistentModelID != currentLocationId
        }
    }
    
    private var selectedDestinationLocation: InventoryLocation? {
        guard let selectedDestinationLocationId else {
            return nil
        }
        
        return destinationLocations.first(where: { $0.persistentModelID == selectedDestinationLocationId })
    }
    
    private var destinationStockAfterTransfer: Int? {
        guard let selectedDestinationLocation, let parsedQuantity else {
            return nil
        }

        return stockQuantity(in: selectedDestinationLocation) + parsedQuantity
    }
    
    private var parsedQuantity: Int? {
        let trimmedValue = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let value = Int(trimmedValue), value > 0 else {
            return nil
        }
        
        return value
    }
    
    private var canSave: Bool {
        guard let parsedQuantity else {
            return false
        }
        
        guard selectedDestinationLocation != nil else {
            return false
        }
        
        return parsedQuantity <= inventoryItem.quantityOnHand
    }
    
    @ViewBuilder
    private func destinationTile(for location: InventoryLocation) -> some View {
        let isSelected = selectedDestinationLocationId == location.persistentModelID
        let quantity = stockQuantity(in: location)
        
        Button {
            selectedDestinationLocationId = location.persistentModelID
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(location.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(quantity == 1 ? "\(quantity) piece" : "\(quantity) pieces")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .background(isSelected ? AppColors.primary.opacity(0.12) : AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppColors.primary : AppColors.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func stockQuantity(in location: InventoryLocation) -> Int {
        guard let diaperSizeId = inventoryItem.diaperSize?.persistentModelID else {
            return 0
        }
        
        return location.inventoryItems.first(where: { item in
            item.diaperSize?.persistentModelID == diaperSizeId
        })?.quantityOnHand ?? 0
    }
    
    private func saveTransfer() {
        guard let quantity = parsedQuantity else {
            errorMessage = "Enter a valid quantity greater than zero."
            return
        }
        
        guard quantity <= inventoryItem.quantityOnHand else {
            errorMessage = "The transfer quantity cannot exceed the available stock."
            return
        }
        
        guard let diaperSize = inventoryItem.diaperSize else {
            errorMessage = "The selected diaper size is no longer available."
            return
        }
        
        guard let sourceLocation = inventoryItem.location else {
            errorMessage = "The source location is no longer available."
            return
        }
        
        guard let destinationLocation = selectedDestinationLocation else {
            errorMessage = "Select a destination location."
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let service = DiaperInventoryService(modelContext: modelContext)
            
            _ = try service.transferStock(
                for: diaperSize,
                quantity: quantity,
                from: sourceLocation,
                to: destinationLocation,
                note: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                reference: nil
            )
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

#Preview("Transfer Diaper Stock") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperInventoryItem>(
        sortBy: [
            SortDescriptor(\DiaperInventoryItem.quantityOnHand, order: .reverse)
        ]
    )

    let inventoryItem = (try? context.fetch(descriptor).first) ?? DiaperInventoryItem(quantityOnHand: 12)

    return NavigationStack {
        TransferDiaperStockView(inventoryItem: inventoryItem)
    }
    .modelContainer(container)
}

#Preview("Transfer Diaper Stock - Dark") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperInventoryItem>(
        sortBy: [
            SortDescriptor(\DiaperInventoryItem.quantityOnHand, order: .reverse)
        ]
    )

    let inventoryItem = (try? context.fetch(descriptor).first) ?? DiaperInventoryItem(quantityOnHand: 12)

    return NavigationStack {
        TransferDiaperStockView(inventoryItem: inventoryItem)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
