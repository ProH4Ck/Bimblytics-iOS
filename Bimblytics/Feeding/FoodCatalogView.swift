//
//  FoodCatalogView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 23/04/2026.
//

import SwiftUI
import SwiftData

struct FoodCatalogView: View {
    private let onSelect: ((FoodItem) -> Void)?

    init(onSelect: ((FoodItem) -> Void)? = nil) {
        self.onSelect = onSelect
    }

    @Query(
        sort: [
            SortDescriptor(\FoodItem.name)
        ]
    )
    private var foodItems: [FoodItem]

    @Query(
        sort: [
            SortDescriptor(\FoodCategory.sortOrder),
            SortDescriptor(\FoodCategory.name)
        ]
    )
    private var categories: [FoodCategory]

    @State private var searchText: String = ""
    @State private var isShowingNewFoodSheet: Bool = false

    var body: some View {
        content
            .navigationTitle("Food catalog")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search food, category, unit..."
            )
            .toolbar {
                if onSelect == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            NavigationLink {
                                FoodCategoriesView()
                            } label: {
                                Label("Manage categories", systemImage: "square.grid.2x2")
                            }

                            NavigationLink {
                                FoodUnitsView()
                            } label: {
                                Label("Manage units", systemImage: "scalemass")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Food catalog options")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingNewFoodSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add food")
                    }
                }
            }
            .sheet(isPresented: $isShowingNewFoodSheet) {
                NavigationStack {
                    NewFoodItemView()
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var content: some View {
        if filteredItems.isEmpty {
            ContentUnavailableView(
                searchText.isEmpty ? (onSelect == nil ? "No foods" : "No foods to select") : "No results",
                systemImage: searchText.isEmpty ? "fork.knife" : "magnifyingglass",
                description: Text(
                    searchText.isEmpty
                    ? (onSelect == nil ? "The food catalog is empty." : "Add foods to the catalog before tracking a feeding event.")
                    : "Try searching by food name, category, or unit."
                )
            )
        } else {
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            if let onSelect {
                                Button {
                                    onSelect(item)
                                } label: {
                                    FoodCatalogRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(AppColors.surface)
                            } else {
                                FoodCatalogRow(item: item)
                                    .listRowBackground(AppColors.surface)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
        }
    }

    private var filteredItems: [FoodItem] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return foodItems.sorted(by: sortItems)
        }

        return foodItems
            .filter { item in
                matches(item: item, query: trimmedQuery)
            }
            .sorted(by: sortItems)
    }

    private var sections: [FoodCatalogSection] {
        var result: [FoodCatalogSection] = categories.compactMap { category in
            let categoryItems = filteredItems
                .filter { item in
                    item.category?.id == category.id
                }
                .sorted(by: sortItems)

            guard !categoryItems.isEmpty else {
                return nil
            }

            return FoodCatalogSection(
                title: category.name,
                items: categoryItems
            )
        }

        let uncategorizedItems = filteredItems
            .filter { item in
                item.category == nil || item.category?.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
            }
            .sorted(by: sortItems)

        if !uncategorizedItems.isEmpty {
            result.append(
                FoodCatalogSection(
                    title: "Uncategorized",
                    items: uncategorizedItems
                )
            )
        }

        return result
    }

    private func matches(item: FoodItem, query: String) -> Bool {
        let normalizedQuery = query.localizedLowercase

        let searchableFields: [String] = [
            item.name,
            item.category?.name ?? "",
            item.defaultUnit?.name ?? "",
            item.defaultUnit?.symbol ?? ""
        ]

        return searchableFields.contains { field in
            field.localizedLowercase.contains(normalizedQuery)
        }
    }

    private func sortItems(lhs: FoodItem, rhs: FoodItem) -> Bool {
        let lhsCategory = lhs.category?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rhsCategory = rhs.category?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let lhsHasCategory = !lhsCategory.isEmpty
        let rhsHasCategory = !rhsCategory.isEmpty

        if lhsHasCategory != rhsHasCategory {
            return lhsHasCategory && !rhsHasCategory
        }

        if lhsCategory != rhsCategory {
            return lhsCategory.localizedCaseInsensitiveCompare(rhsCategory) == .orderedAscending
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private struct FoodCatalogSection: Identifiable {
    let title: String
    let items: [FoodItem]

    var id: String {
        title
    }
}

private struct FoodCatalogRow: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 6) {
                if let categoryName = item.category?.name,
                   !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(categoryName)
                }

                if let unit = item.defaultUnit {
                    if let categoryName = item.category?.name,
                       !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("•")
                    }

                    Text(unitLabel(for: unit))
                }
            }
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func unitLabel(for unit: FoodUnit) -> String {
        let trimmedSymbol = unit.symbol.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSymbol.isEmpty {
            return unit.name
        }

        return "\(unit.name) (\(trimmedSymbol))"
    }
}

private struct NewFoodItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<FoodCategory> { !$0.isArchived },
        sort: [
            SortDescriptor(\FoodCategory.sortOrder),
            SortDescriptor(\FoodCategory.name)
        ]
    )
    private var categories: [FoodCategory]

    @Query(
        filter: #Predicate<FoodUnit> { !$0.isArchived },
        sort: [
            SortDescriptor(\FoodUnit.sortOrder),
            SortDescriptor(\FoodUnit.name)
        ]
    )
    private var units: [FoodUnit]

    @State private var name: String = ""
    @State private var selectedCategoryId: FoodCategory.ID?
    @State private var selectedUnitId: FoodUnit.ID?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        Form {
            Section("Food details") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Picker("Category", selection: $selectedCategoryId) {
                    Text("None")
                        .tag(Optional<FoodCategory.ID>.none)

                    ForEach(categories) { category in
                        Text(category.name)
                            .tag(Optional(category.id))
                    }
                }

                Picker("Default unit", selection: $selectedUnitId) {
                    Text("None")
                        .tag(Optional<FoodUnit.ID>.none)

                    ForEach(units) { unit in
                        Text(unitLabel(for: unit))
                            .tag(Optional(unit.id))
                    }
                }
            }
        }
        .navigationTitle("New food")
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
                .accessibilityLabel("Save food")
            }
        }
    }

    private func save() {
        let selectedCategory = categories.first { category in
            category.id == selectedCategoryId
        }

        let selectedUnit = units.first { unit in
            unit.id == selectedUnitId
        }

        let foodItem = FoodItem(
            name: trimmedName,
            category: selectedCategory,
            defaultUnit: selectedUnit
        )

        modelContext.insert(foodItem)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save food item: \(error.localizedDescription)")
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

#Preview("Food Catalog") {
    NavigationStack {
        FoodCatalogView()
    }
    .modelContainer(PreviewData.makeContainer())
}

#Preview("Food Catalog Dark") {
    NavigationStack {
        FoodCatalogView()
    }
    .modelContainer(PreviewData.makeContainer())
    .preferredColorScheme(.dark)
}
