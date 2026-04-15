//
//  DiaperInventoryTileView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import SwiftUI
import SwiftData

struct DiaperInventoryTileView: View {
    let item: DiaperInventoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topRow

            VStack(alignment: .leading, spacing: 4) {
                Text(brandName)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Text(modelName)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                sizeRow
            }

            Spacer(minLength: 0)

            quantityBlock
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    private var topRow: some View {
        HStack {
            statusBadge

            Spacer()

            if let threshold = item.lowStockThreshold {
                Text("Min \(threshold)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var sizeRow: some View {
        HStack {
            Text(sizeName)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            if let rangeText = rangeText, !rangeText.isEmpty {
                Text("(" + rangeText + ")")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var quantityBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(item.quantityOnHand)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text(item.quantityOnHand == 1 ? "piece available" : "pieces available")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.14), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var brandName: String {
        item.diaperSize?.model?.brand?.name ?? "Unknown brand"
    }

    private var modelName: String {
        item.diaperSize?.model?.name ?? "Unknown model"
    }

    private var sizeName: String {
        item.diaperSize?.displayName ?? "Unknown size"
    }

    private var rangeText: String? {
        item.diaperSize?.sizeRange
    }

    private var statusText: String {
        if item.quantityOnHand == 0 {
            return "Out"
        }

        if item.isLowStock {
            return "Low"
        }

        return "OK"
    }

    private var statusColor: Color {
        if item.quantityOnHand == 0 {
            return AppColors.secondary
        }

        if item.isLowStock {
            return AppColors.accent
        }

        return AppColors.primary
    }

    private var cardBackgroundColor: Color {
        if item.quantityOnHand == 0 {
            return AppColors.secondary.opacity(0.08)
        }

        if item.isLowStock {
            return AppColors.accent.opacity(0.10)
        }

        return AppColors.surface
    }

    private var cardBorderColor: Color {
        if item.quantityOnHand == 0 {
            return AppColors.secondary.opacity(0.30)
        }

        if item.isLowStock {
            return AppColors.accent.opacity(0.35)
        }

        return AppColors.primary.opacity(0.14)
    }
}

#Preview("Tile - Normal") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperInventoryItem>(
        sortBy: [
            SortDescriptor(\DiaperInventoryItem.quantityOnHand, order: .reverse)
        ]
    )

    let item = (try? context.fetch(descriptor).first) ?? DiaperInventoryItem(quantityOnHand: 12)

    return DiaperInventoryTileView(item: item)
        .padding()
        .frame(width: 220)
        .modelContainer(container)
}

#Preview("Tile - Low Stock") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperInventoryItem>()
    let items = (try? context.fetch(descriptor)) ?? []

    let item = items.first(where: { $0.isLowStock && $0.quantityOnHand > 0 })
        ?? DiaperInventoryItem(quantityOnHand: 2, lowStockThreshold: 5)

    return DiaperInventoryTileView(item: item)
        .padding()
        .frame(width: 220)
        .modelContainer(container)
}

#Preview("Tile - Out of Stock") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperInventoryItem>()
    let items = (try? context.fetch(descriptor)) ?? []

    let item = items.first(where: { $0.quantityOnHand == 0 })
        ?? DiaperInventoryItem(quantityOnHand: 0, lowStockThreshold: 2)

    return DiaperInventoryTileView(item: item)
        .padding()
        .frame(width: 220)
        .modelContainer(container)
}
