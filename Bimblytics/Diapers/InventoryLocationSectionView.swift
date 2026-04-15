//
//  InventoryLocationSectionView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import SwiftUI
import SwiftData

struct InventoryLocationSectionView: View {
    let location: InventoryLocation
    let onEditLocation: (InventoryLocation) -> Void

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 12)
    ]

    private var visibleItems: [DiaperInventoryItem] {
        location.inventoryItems
            .filter { $0.quantityOnHand > 0 || !$0.movements.isEmpty }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if visibleItems.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(visibleItems) { item in
                        NavigationLink {
                            DiaperInventoryItemDetailView(inventoryItem: item)
                        } label: {
                            DiaperInventoryTileView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(location.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            if location.isDefault {
                Text("Default")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.primary.opacity(0.12), in: Capsule())
            }

            Spacer()

            let totalQuantity = visibleItems.reduce(0) { partialResult, item in
                partialResult + item.quantityOnHand
            }

            Text("\(totalQuantity) pcs")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            Menu {
                Button {
                    onEditLocation(location)
                } label: {
                    Label("Edit location", systemImage: "pencil")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .accessibilityLabel("Location actions")
        }
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(AppColors.surface)
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
            )
            .overlay(
                Text("No diaper stock in this location")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            )
    }
}

#Preview("Location Section") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext
    
    let descriptor = FetchDescriptor<InventoryLocation>(
        sortBy: [
            SortDescriptor(\InventoryLocation.sortOrder),
            SortDescriptor(\InventoryLocation.name)
        ]
    )
    
    let location = (try? context.fetch(descriptor).first) ?? InventoryLocation(name: "Preview")
    
    return NavigationStack {
        InventoryLocationSectionView(location: location) { _ in
        }
            .padding()
            .background(AppColors.background)
    }
    .modelContainer(container)
}

#Preview("Location Section Dark") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext

    let descriptor = FetchDescriptor<InventoryLocation>(
        sortBy: [
            SortDescriptor(\InventoryLocation.sortOrder),
            SortDescriptor(\InventoryLocation.name)
        ]
    )

    let location = (try? context.fetch(descriptor).first) ?? InventoryLocation(name: "Preview")

    return NavigationStack {
        InventoryLocationSectionView(location: location) { _ in
        }
            .padding()
            .background(AppColors.background)
    }
    .preferredColorScheme(.dark)
    .modelContainer(container)
}
