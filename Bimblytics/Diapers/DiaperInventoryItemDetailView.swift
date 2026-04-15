//
//  DiaperInventoryItemDetailView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 07/04/2026.
//

import SwiftUI
import SwiftData

struct DiaperInventoryItemDetailView: View {
    let inventoryItem: DiaperInventoryItem
    @State private var isShowingManualCorrection: Bool = false
    @State private var isShowingTransfer: Bool = false

    var body: some View {
        List {
            Section("Diaper") {
                LabeledContent("Brand", value: inventoryItem.diaperSize?.model?.brand?.name ?? "-")
                LabeledContent("Model", value: inventoryItem.diaperSize?.model?.name ?? "-")
                LabeledContent("Size", value: inventoryItem.diaperSize?.displayName ?? "-")

                if let sizeRange = inventoryItem.diaperSize?.sizeRange, !sizeRange.isEmpty {
                    LabeledContent("Range", value: sizeRange)
                }

                LabeledContent("Location", value: inventoryItem.location?.name ?? "-")
            }

            Section("Stock") {
                LabeledContent("Remaining", value: "\(inventoryItem.quantityOnHand)")

                if let lowStockThreshold = inventoryItem.lowStockThreshold {
                    LabeledContent("Low stock threshold", value: "\(lowStockThreshold)")
                }

                if let packageQuantity = inventoryItem.packageQuantity {
                    LabeledContent("Package quantity", value: "\(packageQuantity)")
                }
            }

            Section("Movements") {
                if sortedMovements.isEmpty {
                    Text("No movements recorded yet")
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    ForEach(sortedMovements) { movement in
                        movementRow(movement)
                    }
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isShowingTransfer = true
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .accessibilityLabel("Transfer stock")

                Button {
                    isShowingManualCorrection = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Correct manually")
            }
        }
        .sheet(isPresented: $isShowingManualCorrection) {
            NavigationStack {
                ManualDiaperStockCorrectionView(inventoryItem: inventoryItem)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingTransfer) {
            NavigationStack {
                TransferDiaperStockView(inventoryItem: inventoryItem)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var sortedMovements: [DiaperStockMovement] {
        inventoryItem.movements.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    @ViewBuilder
    private func movementRow(_ movement: DiaperStockMovement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(movementTitle(for: movement))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(movement.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text(formattedQuantityDelta(for: movement))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(quantityColor(for: movement))
            }

            HStack {
                Text("Resulting stock")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Text("\(movement.resultingQuantity ?? inventoryItem.quantityOnHand)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
            }

            if let note = movement.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func movementTitle(for movement: DiaperStockMovement) -> String {
        switch movement.typeEnum {
        case .purchase:
            return "Purchase"
        case .manualLoad:
            return "Manual load"
        case .consumption:
            return "Consumption"
        case .correction:
            return "Manual correction"
        case .discard:
            return "Discard"
        case .transferIn:
            return "Transfer in"
        case .transferOut:
            return "Transfer out"
        }
    }

    private func formattedQuantityDelta(for movement: DiaperStockMovement) -> String {
        if movement.quantityDelta > 0 {
            return "+\(movement.quantityDelta)"
        }

        return "\(movement.quantityDelta)"
    }

    private func quantityColor(for movement: DiaperStockMovement) -> Color {
        if movement.quantityDelta > 0 {
            return AppColors.primary
        }

        if movement.quantityDelta < 0 {
            return AppColors.accent
        }

        return AppColors.textSecondary
    }

    private var navigationTitleText: String {
        let brand = inventoryItem.diaperSize?.model?.brand?.name ?? ""
        let model = inventoryItem.diaperSize?.model?.name ?? ""
        let size = inventoryItem.diaperSize?.displayName ?? ""

        let parts = [brand, model, size].filter { !$0.isEmpty }
        return parts.isEmpty ? "Inventory" : parts.joined(separator: " ")
    }
}

#Preview("Inventory Item Detail") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperInventoryItem>(
        sortBy: [
            SortDescriptor(\DiaperInventoryItem.quantityOnHand, order: .reverse)
        ]
    )

    let inventoryItem = (try? context.fetch(descriptor).first) ?? DiaperInventoryItem(quantityOnHand: 12)

    return NavigationStack {
        DiaperInventoryItemDetailView(inventoryItem: inventoryItem)
    }
    .modelContainer(container)
}

#Preview("Inventory Item Detail Dark") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperInventoryItem>(
        sortBy: [
            SortDescriptor(\DiaperInventoryItem.quantityOnHand, order: .reverse)
        ]
    )

    let inventoryItem = (try? context.fetch(descriptor).first) ?? DiaperInventoryItem(quantityOnHand: 12)

    return NavigationStack {
        DiaperInventoryItemDetailView(inventoryItem: inventoryItem)
    }
    .preferredColorScheme(.dark)
    .modelContainer(container)
}
