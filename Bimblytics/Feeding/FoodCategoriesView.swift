//
//  FoodCategoriesView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 23/04/2026.
//

import SwiftUI
import SwiftData

struct FoodCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var editMode: EditMode = .inactive

    @Query(
        sort: [
            SortDescriptor(\FoodCategory.sortOrder),
            SortDescriptor(\FoodCategory.name)
        ]
    )
    private var categories: [FoodCategory]

    @State private var searchText: String = ""
    @State private var isShowingNewCategorySheet: Bool = false
    @State private var categoryToEdit: FoodCategory?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Food categories")
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search categories..."
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if !activeCategories.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            EditButton()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if editMode != .active {
                            Button {
                                isShowingNewCategorySheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Add category")
                        }
                    }
                }
                .environment(\.editMode, $editMode)
        }
        .sheet(isPresented: $isShowingNewCategorySheet) {
            NavigationStack {
                FoodCategoryFormView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $categoryToEdit) { category in
            NavigationStack {
                FoodCategoryFormView(category: category)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var content: some View {
        if filteredCategories.isEmpty {
            ContentUnavailableView(
                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No categories" : "No results",
                systemImage: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "square.grid.2x2" : "magnifyingglass",
                description: Text(
                    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "No food categories available."
                    : "Try a different search term."
                )
            )
        } else {
            List {
                if !activeCategories.isEmpty {
                    Section("Active") {
                        ForEach(activeCategories) { category in
                            FoodCategoryRow(category: category) {
                                archive(category)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                categoryToEdit = category
                            }
                            .listRowBackground(AppColors.surface)
                        }
                        .onMove(perform: { indices, newOffset in
                            var sortedCategories = activeCategories.sorted(by: { $0.sortOrder < $1.sortOrder })
                            sortedCategories.move(fromOffsets: indices, toOffset: newOffset)
                            for (index, item) in sortedCategories.enumerated() {
                                item.sortOrder = index
                            }
                            saveContext()
                        })
                    }
                }

                if !archivedCategories.isEmpty {
                    Section("Archived") {
                        ForEach(archivedCategories) { category in
                            FoodCategoryRow(category: category) {
                                restore(category)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                categoryToEdit = category
                            }
                            .listRowBackground(AppColors.surface)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
        }
    }

    private var filteredCategories: [FoodCategory] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return categories
        }

        let normalizedQuery = trimmedQuery.localizedLowercase

        return categories.filter { category in
            category.name.localizedLowercase.contains(normalizedQuery)
        }
    }

    private var activeCategories: [FoodCategory] {
        filteredCategories
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var archivedCategories: [FoodCategory] {
        filteredCategories
            .filter { $0.isArchived }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func archive(_ category: FoodCategory) {
        category.isArchived = true
        category.updatedAt = .now
        saveContext()
    }

    private func restore(_ category: FoodCategory) {
        category.isArchived = false
        category.updatedAt = .now
        saveContext()
    }

    private func delete(_ category: FoodCategory) {
        modelContext.delete(category)
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save category changes: \(error.localizedDescription)")
        }
    }
}

private struct FoodCategoryRow: View {
    let category: FoodCategory
    let onToggleArchived: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if editModeIsActive {
                Button {
                    onToggleArchived()
                } label: {
                    Image(systemName: category.isArchived ? "arrow.uturn.backward.circle.fill" : "archivebox.circle.fill")
                        .font(.title3)
                        .foregroundStyle(category.isArchived ? .green : .orange)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(category.isArchived ? "Restore category" : "Archive category")
            }

            Text(category.name)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.vertical, 4)
    }

    @Environment(\.editMode) private var editMode

    private var editModeIsActive: Bool {
        editMode?.wrappedValue == .active
    }
}

private struct FoodCategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let category: FoodCategory?

    @State private var name: String

    init(category: FoodCategory? = nil) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        Form {
            Section("Category details") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle(category == nil ? "New category" : "Edit category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            if let category {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleArchivedState(for: category)
                    } label: {
                        Image(systemName: category.isArchived ? "arrow.uturn.backward" : "archivebox")
                    }
                    .accessibilityLabel(category.isArchived ? "Restore category" : "Archive category")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark")
                }
                .disabled(!canSave)
                .accessibilityLabel("Save category")
            }
        }
    }

    private func toggleArchivedState(for category: FoodCategory) {
        category.isArchived.toggle()
        category.updatedAt = .now

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to update category archive state: \(error.localizedDescription)")
        }
    }

    private func save() {
        if let category {
            category.name = trimmedName
            category.updatedAt = .now
        } else {
            let nextSortOrder = (try? modelContext.fetch(FetchDescriptor<FoodCategory>()))?.count ?? 0

            let newCategory = FoodCategory(
                name: trimmedName,
                sortOrder: nextSortOrder,
                isSystem: false,
                isArchived: false
            )
            modelContext.insert(newCategory)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save category: \(error.localizedDescription)")
        }
    }
}

#Preview("Food Categories") {
    FoodCategoriesView()
        .modelContainer(PreviewData.makeContainer())
}

#Preview("Food Categories Dark") {
    FoodCategoriesView()
        .modelContainer(PreviewData.makeContainer())
        .preferredColorScheme(.dark)
}
