//
//  NewInventoryLocationView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 08/04/2026.
//

import SwiftUI
import SwiftData

private enum InventoryLocationEditorMode {
    case create
    case edit(InventoryLocation)
}

struct NewInventoryLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<InventoryLocation> { !$0.isArchived },
        sort: [
            SortDescriptor(\InventoryLocation.sortOrder),
            SortDescriptor(\InventoryLocation.name)
        ]
    )
    private var existingLocations: [InventoryLocation]

    private let mode: InventoryLocationEditorMode

    @State private var name: String
    @State private var notes: String
    @State private var makeDefault: Bool
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false

    init() {
        self.mode = .create
        self._name = State(initialValue: "")
        self._notes = State(initialValue: "")
        self._makeDefault = State(initialValue: false)
    }

    init(location: InventoryLocation) {
        self.mode = .edit(location)
        self._name = State(initialValue: location.name)
        self._notes = State(initialValue: location.notes ?? "")
        self._makeDefault = State(initialValue: location.isDefault)
    }

    private var editingLocation: InventoryLocation? {
        switch mode {
        case .create:
            return nil
        case let .edit(location):
            return location
        }
    }

    private var isEditMode: Bool {
        editingLocation != nil
    }

    private var canDelete: Bool {
        guard let editingLocation else {
            return false
        }

        return editingLocation.inventoryItems.isEmpty
    }

    var body: some View {
        Form {
            Section(isEditMode ? "Edit location" : "New location") {
                TextField("Name", text: $name)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                Toggle("Set as default location", isOn: $makeDefault)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(AppTextStyle.bodySecondary.font)
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if isEditMode {
                Section {
                    Button(role: .destructive) {
                        deleteLocation()
                    } label: {
                        Text("Delete location")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canDelete || isSaving)
                }
                if !canDelete {
                    Text("You can delete this location only when it no longer contains diaper stock.")
                        .font(AppTextStyle.bodySecondary.font)
                        .foregroundStyle(AppColors.textSecondary)
                    
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(isEditMode ? "Edit location" : "New location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveLocation()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
                .disabled(!canSave || isSaving)
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    private func saveLocation() {
        let locationName = trimmedName

        guard !locationName.isEmpty else {
            errorMessage = "Enter a location name."
            return
        }

        let editingLocationId = editingLocation?.persistentModelID

        let duplicateExists = existingLocations.contains { location in
            if let editingLocationId, location.persistentModelID == editingLocationId {
                return false
            }

            return location.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(locationName) == .orderedSame
        }

        guard !duplicateExists else {
            errorMessage = "A location with the same name already exists."
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            if makeDefault {
                for location in existingLocations where location.isDefault {
                    location.isDefault = false
                    location.updatedAt = .now
                }
            }

            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let storedNotes = trimmedNotes.isEmpty ? nil : trimmedNotes

            if let editingLocation {
                editingLocation.name = locationName
                editingLocation.notes = storedNotes
                editingLocation.isDefault = makeDefault
                editingLocation.updatedAt = .now
            } else {
                let nextSortOrder = (existingLocations.map(\.sortOrder).max() ?? -1) + 1

                let newLocation = InventoryLocation(
                    name: locationName,
                    notes: storedNotes,
                    sortOrder: nextSortOrder,
                    isDefault: makeDefault || existingLocations.isEmpty,
                    isArchived: false,
                    createdAt: .now,
                    updatedAt: .now
                )

                modelContext.insert(newLocation)
            }

            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func deleteLocation() {
        guard let editingLocation else {
            return
        }

        guard canDelete else {
            errorMessage = "This location still contains diaper stock and cannot be deleted."
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            modelContext.delete(editingLocation)
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

#Preview("New Inventory Location") {
    NavigationStack {
        NewInventoryLocationView()
            .background(AppColors.background)
    }
    .modelContainer(DiaperInventoryPreviewData.makeContainer())
}

#Preview("New Inventory Location - Dark") {
    NavigationStack {
        NewInventoryLocationView()
            .background(AppColors.background)
    }
    .modelContainer(DiaperInventoryPreviewData.makeContainer())
    .preferredColorScheme(.dark)
}

#Preview("Edit Inventory Location") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext
    let descriptor = FetchDescriptor<InventoryLocation>(
        sortBy: [
            SortDescriptor(\InventoryLocation.sortOrder),
            SortDescriptor(\InventoryLocation.name)
        ]
    )
    let location = (try? context.fetch(descriptor).first) ?? InventoryLocation(name: "Home")

    return NavigationStack {
        NewInventoryLocationView(location: location)
            .background(AppColors.background)
    }
    .modelContainer(container)
}

#Preview("Edit Inventory Location - Dark") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext
    let descriptor = FetchDescriptor<InventoryLocation>(
        sortBy: [
            SortDescriptor(\InventoryLocation.sortOrder),
            SortDescriptor(\InventoryLocation.name)
        ]
    )
    let location = (try? context.fetch(descriptor).first) ?? InventoryLocation(name: "Home")

    return NavigationStack {
        NewInventoryLocationView(location: location)
            .background(AppColors.background)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
