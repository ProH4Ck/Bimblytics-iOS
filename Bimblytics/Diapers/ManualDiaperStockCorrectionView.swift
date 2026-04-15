//
//  ManualDiaperStockCorrectionView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 07/04/2026.
//

import SwiftUI
import SwiftData

struct ManualDiaperStockCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let inventoryItem: DiaperInventoryItem

    @State private var quantityDeltaText: String = ""
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false

    var body: some View {
        Form {
            Section("Correction") {
                TextField("Quantity change", text: $quantityDeltaText)
                    .keyboardType(.numbersAndPunctuation)

                Text("Use a positive number to add stock or a negative number to remove stock.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)

                if let projectedQuantity {
                    LabeledContent("Resulting stock") {
                        Text("\(projectedQuantity)")
                            .foregroundStyle(projectedQuantity == 0 ? AppColors.textSecondary : AppColors.textPrimary)
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
        .navigationTitle("Manual correction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveCorrection()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
                .disabled(!canSave || isSaving)
            }
        }
    }

    private var parsedQuantityDelta: Int? {
        let trimmedValue = quantityDeltaText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty, let value = Int(trimmedValue), value != 0 else {
            return nil
        }

        return value
    }

    private var projectedQuantity: Int? {
        guard let parsedQuantityDelta else {
            return nil
        }

        let result = inventoryItem.quantityOnHand + parsedQuantityDelta
        return result >= 0 ? result : nil
    }

    private var canSave: Bool {
        guard let parsedQuantityDelta else {
            return false
        }

        guard inventoryItem.diaperSize != nil, inventoryItem.location != nil else {
            return false
        }

        return inventoryItem.quantityOnHand + parsedQuantityDelta >= 0
    }

    private func saveCorrection() {
        guard let quantityDelta = parsedQuantityDelta else {
            errorMessage = "Enter a non-zero correction value."
            return
        }

        guard let diaperSize = inventoryItem.diaperSize else {
            errorMessage = "The selected diaper size is no longer available."
            return
        }

        guard let location = inventoryItem.location else {
            errorMessage = "The selected location is no longer available."
            return
        }

        guard inventoryItem.quantityOnHand + quantityDelta >= 0 else {
            errorMessage = "The correction would result in a negative stock quantity."
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let service = DiaperInventoryService(modelContext: modelContext)

            try service.adjustStock(
                for: diaperSize,
                in: location,
                quantityDelta: quantityDelta,
                note: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

#Preview("Manual Diaper Stock Correction") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperInventoryItem>(
        sortBy: [
            SortDescriptor(\DiaperInventoryItem.quantityOnHand, order: .reverse)
        ]
    )

    let inventoryItem = (try? context.fetch(descriptor).first) ?? DiaperInventoryItem(quantityOnHand: 12)

    return NavigationStack {
        ManualDiaperStockCorrectionView(inventoryItem: inventoryItem)
    }
    .modelContainer(container)
}

#Preview("Manual Diaper Stock Correction Dark") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperInventoryItem>(
        sortBy: [
            SortDescriptor(\DiaperInventoryItem.quantityOnHand, order: .reverse)
        ]
    )

    let inventoryItem = (try? context.fetch(descriptor).first) ?? DiaperInventoryItem(quantityOnHand: 12)

    return NavigationStack {
        ManualDiaperStockCorrectionView(inventoryItem: inventoryItem)
    }
    .preferredColorScheme(.dark)
    .modelContainer(container)
}
