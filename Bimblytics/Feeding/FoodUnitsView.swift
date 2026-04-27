//
//  FoodUnitsView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 23/04/2026.
//

import SwiftUI
import SwiftData

struct FoodUnitsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var editMode: EditMode = .inactive

    @Query(
        sort: [
            SortDescriptor(\FoodUnit.sortOrder),
            SortDescriptor(\FoodUnit.name)
        ]
    )
    private var units: [FoodUnit]

    @State private var searchText: String = ""
    @State private var isShowingNewUnitSheet: Bool = false
    @State private var unitToEdit: FoodUnit?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Food units")
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search units..."
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if !activeUnits.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            EditButton()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if editMode != .active {
                            Button {
                                isShowingNewUnitSheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Add unit")
                        }
                    }
                }
                .environment(\.editMode, $editMode)
        }
        .sheet(isPresented: $isShowingNewUnitSheet) {
            NavigationStack {
                FoodUnitFormView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $unitToEdit) { unit in
            NavigationStack {
                FoodUnitFormView(unit: unit)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var content: some View {
        if filteredUnits.isEmpty {
            ContentUnavailableView(
                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No units" : "No results",
                systemImage: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "scalemass" : "magnifyingglass",
                description: Text(
                    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "No food units available."
                    : "Try a different search term."
                )
            )
        } else {
            List {
                if !activeUnits.isEmpty {
                    Section("Active") {
                        ForEach(activeUnits) { unit in
                            FoodUnitRow(unit: unit) {
                                archive(unit)
                            }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    unitToEdit = unit
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        unitToEdit = unit
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button(role: .destructive) {
                                        delete(unit)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .listRowBackground(AppColors.surface)
                        }
                        .onMove(perform: moveActiveUnits)
                    }
                }

                if !archivedUnits.isEmpty {
                    Section("Archived") {
                        ForEach(archivedUnits) { unit in
                            FoodUnitRow(unit: unit) {
                                restore(unit)
                            }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    unitToEdit = unit
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        unitToEdit = unit
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button(role: .destructive) {
                                        delete(unit)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
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

    private var filteredUnits: [FoodUnit] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return units
        }

        let normalizedQuery = trimmedQuery.localizedLowercase

        return units.filter { unit in
            unit.name.localizedLowercase.contains(normalizedQuery)
            || unit.symbol.localizedLowercase.contains(normalizedQuery)
        }
    }

    private var activeUnits: [FoodUnit] {
        filteredUnits
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var archivedUnits: [FoodUnit] {
        filteredUnits
            .filter { $0.isArchived }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func moveActiveUnits(from source: IndexSet, to destination: Int) {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        guard editMode == .active else {
            return
        }

        var reorderedUnits = activeUnits
        reorderedUnits.move(fromOffsets: source, toOffset: destination)

        for (index, unit) in reorderedUnits.enumerated() {
            unit.sortOrder = index
            unit.updatedAt = .now
        }

        let reorderedUnitIds = Set(reorderedUnits.map(\.id))
        let archivedItems = units
            .filter { $0.isArchived && !reorderedUnitIds.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        let archivedStartIndex = reorderedUnits.count

        for (index, unit) in archivedItems.enumerated() {
            unit.sortOrder = archivedStartIndex + index
            unit.updatedAt = .now
        }

        saveContext()
    }

    private func archive(_ unit: FoodUnit) {
        unit.isArchived = true
        unit.updatedAt = .now
        saveContext()
    }

    private func restore(_ unit: FoodUnit) {
        unit.isArchived = false
        unit.updatedAt = .now
        saveContext()
    }

    private func delete(_ unit: FoodUnit) {
        modelContext.delete(unit)
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save unit changes: \(error.localizedDescription)")
        }
    }
}

private struct FoodUnitRow: View {
    let unit: FoodUnit
    let onToggleArchived: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if editModeIsActive {
                Button {
                    onToggleArchived()
                } label: {
                    Image(systemName: unit.isArchived ? "arrow.uturn.backward.circle.fill" : "archivebox.circle.fill")
                        .font(.title3)
                        .foregroundStyle(unit.isArchived ? .green : .orange)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(unit.isArchived ? "Restore unit" : "Archive unit")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(unit.name)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                let trimmedSymbol = unit.symbol.trimmingCharacters(in: .whitespacesAndNewlines)

                Text(trimmedSymbol.isEmpty ? "No symbol" : trimmedSymbol)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    @Environment(\.editMode) private var editMode

    private var editModeIsActive: Bool {
        editMode?.wrappedValue == .active
    }
}

private struct FoodUnitFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let unit: FoodUnit?

    @State private var name: String
    @State private var symbol: String

    init(unit: FoodUnit? = nil) {
        self.unit = unit
        _name = State(initialValue: unit?.name ?? "")
        _symbol = State(initialValue: unit?.symbol ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSymbol: String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        Form {
            Section("Unit details") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                TextField("Symbol", text: $symbol)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Preview") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trimmedName.isEmpty ? "Name" : trimmedName)
                        .font(.headline)

                    if trimmedSymbol.isEmpty {
                        Text("No symbol")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(trimmedSymbol)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(unit == nil ? "New unit" : "Edit unit")
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
                .accessibilityLabel("Save unit")
            }
        }
    }

    private func save() {
        if let unit {
            unit.name = trimmedName
            unit.symbol = trimmedSymbol
            unit.updatedAt = .now
        } else {
            let nextSortOrder = (try? modelContext.fetch(FetchDescriptor<FoodUnit>()))?.count ?? 0

            let newUnit = FoodUnit(
                name: trimmedName,
                symbol: trimmedSymbol,
                sortOrder: nextSortOrder,
                isSystem: false,
                isArchived: false
            )
            modelContext.insert(newUnit)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save unit: \(error.localizedDescription)")
        }
    }
}

#Preview("Food Units") {
    FoodUnitsView()
        .modelContainer(PreviewData.makeContainer())
}

#Preview("Food Units Dark") {
    FoodUnitsView()
        .modelContainer(PreviewData.makeContainer())
        .preferredColorScheme(.dark)
}
