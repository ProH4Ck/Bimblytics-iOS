//
//  DiaperCatalogSearchView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import SwiftUI
import SwiftData

struct DiaperCatalogSearchView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: [
            SortDescriptor(\DiaperSize.code)
        ]
    )
    private var diaperSizes: [DiaperSize]

    @State private var searchText: String = ""
    @State private var isShowingNewDiaperEntrySheet: Bool = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add diaper stock")
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search brand, model, size..."
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingNewDiaperEntrySheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("New diaper model")
                    }
                }
        }
        .sheet(isPresented: $isShowingNewDiaperEntrySheet) {
            NavigationStack {
                NewDiaperCatalogEntryView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var content: some View {
        if filteredSizes.isEmpty {
            ContentUnavailableView(
                searchText.isEmpty ? "No diaper models" : "No results",
                systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                description: Text(
                    searchText.isEmpty
                    ? "The diaper catalog is empty."
                    : "Try searching by brand, model, size, or range."
                )
            )
        } else {
            List {
                ForEach(filteredSizes) { diaperSize in
                    NavigationLink {
                        AddDiaperStockView(diaperSize: diaperSize)
                    } label: {
                        DiaperCatalogSearchResultRow(
                            diaperSize: diaperSize,
                            totalQuantity: totalQuantity(for: diaperSize),
                            stockByLocation: stockByLocation(for: diaperSize)
                        )
                    }
                    .listRowBackground(AppColors.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
        }
    }

    private var filteredSizes: [DiaperSize] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return diaperSizes
                .sorted(by: sortSizes)
        }

        return diaperSizes
            .filter { diaperSize in
                matches(diaperSize: diaperSize, query: trimmedQuery)
            }
            .sorted(by: sortSizes)
    }

    private func matches(diaperSize: DiaperSize, query: String) -> Bool {
        let normalizedQuery = query.localizedLowercase

        let searchableFields: [String] = [
            diaperSize.model?.brand?.name ?? "",
            diaperSize.model?.name ?? "",
            diaperSize.code,
            diaperSize.descriptionText ?? "",
            diaperSize.sizeRange
        ]

        return searchableFields.contains { field in
            field.localizedLowercase.contains(normalizedQuery)
        }
    }

    private func sortSizes(lhs: DiaperSize, rhs: DiaperSize) -> Bool {
        let lhsTotal = totalQuantity(for: lhs)
        let rhsTotal = totalQuantity(for: rhs)

        let lhsHasStock = lhsTotal > 0
        let rhsHasStock = rhsTotal > 0

        if lhsHasStock != rhsHasStock {
            return lhsHasStock && !rhsHasStock
        }

        let lhsBrand = lhs.model?.brand?.name ?? ""
        let rhsBrand = rhs.model?.brand?.name ?? ""

        if lhsBrand != rhsBrand {
            return lhsBrand.localizedCaseInsensitiveCompare(rhsBrand) == .orderedAscending
        }

        let lhsModel = lhs.model?.name ?? ""
        let rhsModel = rhs.model?.name ?? ""

        if lhsModel != rhsModel {
            return lhsModel.localizedCaseInsensitiveCompare(rhsModel) == .orderedAscending
        }

        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    private func totalQuantity(for diaperSize: DiaperSize) -> Int {
        diaperSize.inventoryItems.reduce(0) { partialResult, item in
            partialResult + item.quantityOnHand
        }
    }

    private func stockByLocation(for diaperSize: DiaperSize) -> [LocationStockSummary] {
        diaperSize.inventoryItems
            .filter { $0.quantityOnHand > 0 }
            .compactMap { item in
                guard let location = item.location else {
                    return nil
                }

                return LocationStockSummary(
                    locationName: location.name,
                    quantity: item.quantityOnHand
                )
            }
            .sorted { lhs, rhs in
                lhs.locationName.localizedCaseInsensitiveCompare(rhs.locationName) == .orderedAscending
            }
    }

    private func displayTitle(for diaperSize: DiaperSize) -> String {
        let brand = diaperSize.model?.brand?.name ?? ""
        let model = diaperSize.model?.name ?? ""
        let size = diaperSize.displayName

        return [brand, model, size]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

#Preview("Catalog Search") {
    DiaperCatalogSearchView()
        .modelContainer(DiaperInventoryPreviewData.makeContainer())
}

#Preview("Catalog Search Dark") {
    DiaperCatalogSearchView()
        .modelContainer(DiaperInventoryPreviewData.makeContainer())
        .preferredColorScheme(.dark)
}
