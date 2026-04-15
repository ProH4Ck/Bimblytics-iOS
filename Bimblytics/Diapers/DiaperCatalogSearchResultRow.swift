//
//  DiaperCatalogSearchResultRow.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import SwiftUI
import SwiftData

struct DiaperCatalogSearchResultRow: View {
    let diaperSize: DiaperSize
    let totalQuantity: Int
    let stockByLocation: [LocationStockSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(brandName)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(modelName)
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(sizeName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 12)

                if hasExistingStock {
                    stockBadge
                }
            }

            if let rangeText = rangeText, !rangeText.isEmpty {
                Text(rangeText)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if hasExistingStock {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current stock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)

                    Text("\(totalQuantity) total")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primary)

                    if !stockByLocation.isEmpty {
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(stockByLocation) { locationStock in
                                locationChip(locationStock)
                            }
                        }
                    }
                }
                .padding(10)
                .background(AppColors.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.vertical, 6)
    }

    private var brandName: String {
        diaperSize.model?.brand?.name ?? "Unknown brand"
    }

    private var modelName: String {
        diaperSize.model?.name ?? "Unknown model"
    }

    private var sizeName: String {
        diaperSize.displayName
    }

    private var rangeText: String? {
        diaperSize.sizeRange
    }

    private var hasExistingStock: Bool {
        totalQuantity > 0
    }

    private var stockBadge: some View {
        Text("\(totalQuantity)")
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.primary.opacity(0.12), in: Capsule())
    }

    private func locationChip(_ item: LocationStockSummary) -> some View {
        Text("\(item.locationName): \(item.quantity)")
            .font(.caption)
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppColors.surface, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppColors.primary.opacity(0.14), lineWidth: 1)
            )
    }
}

#Preview("Catalog Search Result Row - With Stock") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperSize>(
        sortBy: [
            SortDescriptor(\DiaperSize.code)
        ]
    )

    let diaperSize = (try? context.fetch(descriptor).first) ?? DiaperSize(
        code: "3",
        descriptionText: "Midi",
        sizeRange: "4 - 9 kg",
        source: .userCustom
    )

    return DiaperCatalogSearchResultRow(
        diaperSize: diaperSize,
        totalQuantity: 47,
        stockByLocation: [
            LocationStockSummary(locationName: "Home", quantity: 42),
            LocationStockSummary(locationName: "Outing bag", quantity: 5)
        ]
    )
    .padding()
    .background(AppColors.background)
    .modelContainer(container)
}

#Preview("Catalog Search Result Row - Empty Stock") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<DiaperSize>(
        sortBy: [
            SortDescriptor(\DiaperSize.code, order: .reverse)
        ]
    )

    let diaperSize = (try? context.fetch(descriptor).first) ?? DiaperSize(
        code: "4",
        descriptionText: "Maxi",
        sizeRange: "7 - 18 kg",
        source: .userCustom
    )

    return DiaperCatalogSearchResultRow(
        diaperSize: diaperSize,
        totalQuantity: 0,
        stockByLocation: []
    )
    .padding()
    .background(AppColors.background)
    .modelContainer(container)
}
