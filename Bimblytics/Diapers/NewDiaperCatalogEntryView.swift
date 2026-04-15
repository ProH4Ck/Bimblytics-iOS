//
//  NewDiaperCatalogEntryView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 09/04/2026.
//

import SwiftUI
import SwiftData

struct NewDiaperCatalogEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: [SortDescriptor(\DiaperBrand.name)])
    private var brands: [DiaperBrand]
    
    @State private var selectedBrandId: PersistentIdentifier?
    @State private var pendingBrandName: String = ""
    @State private var isShowingBrandPickerSheet: Bool = false
    @State private var selectedModelId: PersistentIdentifier?
    @State private var pendingModelName: String = ""
    @State private var isShowingModelPickerSheet: Bool = false
    @State private var selectedType: DiaperType = .disposable
    @State private var selectedAgeCategory: DiaperAgeCategory = .child
    @State private var sizeDrafts: [NewDiaperSizeDraft] = [NewDiaperSizeDraft()]
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false
    
    var body: some View {
        Form {
            Section("Brand") {
                Button {
                    isShowingBrandPickerSheet = true
                } label: {
                    HStack {
                        Text("Brand")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(selectedBrandDisplayText)
                            .foregroundStyle(selectedBrand == nil ? .secondary : .primary)
                        
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                if brandSelectionMode == .new, !trimmedPendingBrandName.isEmpty {
                    Text("A new brand will be created: \(trimmedPendingBrandName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Model") {
                Button {
                    isShowingModelPickerSheet = true
                } label: {
                    HStack {
                        Text("Model")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(selectedModelDisplayText)
                            .foregroundStyle(selectedExistingModel == nil ? .secondary : .primary)
                        
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(selectedBrand == nil && trimmedPendingBrandName.isEmpty)
                
                if let selectedExistingModel {
                    LabeledContent("Type", value: selectedExistingModel.typeEnum.rawValue)
                    LabeledContent("Age category", value: selectedExistingModel.ageCategoryEnum.rawValue)
                } else if modelSelectionMode == .new, !trimmedPendingModelName.isEmpty {
                    Picker("Type", selection: $selectedType) {
                        ForEach(selectableTypes, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Picker("Age category", selection: $selectedAgeCategory) {
                        ForEach(selectableAgeCategories, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    
                    Text("A new model will be created: \(trimmedPendingModelName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Sizes") {
                ForEach($sizeDrafts) { $draft in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Size")
                                .font(.subheadline.weight(.semibold))
                            
                            Spacer()
                            
                            if sizeDrafts.count > 1 {
                                Button(role: .destructive) {
                                    removeSizeDraft(withId: draft.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        TextField("Size", text: $draft.code, prompt: Text("Size (e.g. 3, Maxi, M)"))
                        TextField("Description", text: $draft.descriptionText, prompt: Text("Description (e.g. Midi, Junior, XL)"))
                        TextField("Range", text: $draft.sizeRange, prompt: Text("Range (e.g. 4 - 9 kg)"))
                    }
                    .padding(.vertical, 4)
                }
                
                Button {
                    sizeDrafts.append(NewDiaperSizeDraft())
                } label: {
                    Label("Add size", systemImage: "plus.circle.fill")
                }
            }
            
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle("New diaper model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveEntry()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
                .disabled(!canSave || isSaving)
            }
        }
        .sheet(isPresented: $isShowingBrandPickerSheet) {
            NavigationStack {
                BrandPickerSheetView(
                    brands: brands,
                    selectedBrandId: $selectedBrandId,
                    pendingBrandName: $pendingBrandName
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingModelPickerSheet) {
            NavigationStack {
                ModelPickerSheetView(
                    models: availableModelsForSelectedBrand,
                    selectedModelId: $selectedModelId,
                    pendingModelName: $pendingModelName
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedBrandId) { _, _ in
            selectedModelId = nil
            pendingModelName = ""
        }
    }
    
    private var selectableTypes: [DiaperType] {
        DiaperType.allCases.filter { $0 != .unknown }
    }
    
    private var selectableAgeCategories: [DiaperAgeCategory] {
        DiaperAgeCategory.allCases.filter { $0 != .unknown }
    }
    
    private var trimmedPendingBrandName: String {
        pendingBrandName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var trimmedPendingModelName: String {
        pendingModelName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var brandSelectionMode: DiaperTextSelectionMode {
        selectedBrand == nil ? .new : .existing
    }
    
    private var selectedBrandDisplayText: String {
        if let selectedBrand {
            return selectedBrand.name
        }
        
        if !trimmedPendingBrandName.isEmpty {
            return trimmedPendingBrandName
        }
        
        return "Select or create"
    }
    
    private var selectedBrand: DiaperBrand? {
        guard let selectedBrandId else {
            return nil
        }
        
        return brands.first(where: { $0.persistentModelID == selectedBrandId })
    }
    
    private var resolvedBrandForModelLookup: DiaperBrand? {
        switch brandSelectionMode {
        case .existing:
            return selectedBrand
        case .new:
            return nil
        }
    }
    
    private var availableModelsForSelectedBrand: [DiaperModel] {
        guard let resolvedBrandForModelLookup else {
            return []
        }
        
        return resolvedBrandForModelLookup.models.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    private var selectedModelDisplayText: String {
        if let selectedExistingModel {
            return selectedExistingModel.name
        }
        
        if !trimmedPendingModelName.isEmpty {
            return trimmedPendingModelName
        }
        
        return "Select or create"
    }
    
    private var selectedExistingModel: DiaperModel? {
        guard let selectedModelId else {
            return nil
        }
        
        return availableModelsForSelectedBrand.first(where: { $0.persistentModelID == selectedModelId })
    }
    
    private var modelSelectionMode: DiaperTextSelectionMode {
        selectedExistingModel == nil ? .new : .existing
    }
    
    private var normalizedSizeDrafts: [NewDiaperSizeDraft] {
        sizeDrafts.map { draft in
            NewDiaperSizeDraft(
                id: draft.id,
                code: draft.code.trimmingCharacters(in: .whitespacesAndNewlines),
                descriptionText: draft.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                sizeRange: draft.sizeRange.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
    
    private var hasAtLeastOneSize: Bool {
        !normalizedSizeDrafts.isEmpty
    }
    
    private var allSizesAreValid: Bool {
        normalizedSizeDrafts.allSatisfy { draft in
            !draft.code.isEmpty && !draft.sizeRange.isEmpty
        }
    }
    
    private var canSave: Bool {
        let hasBrand = brandSelectionMode == .existing ? selectedBrand != nil : !trimmedPendingBrandName.isEmpty
        let hasModel = modelSelectionMode == .existing ? selectedExistingModel != nil : !trimmedPendingModelName.isEmpty
        
        return hasBrand && hasModel && hasAtLeastOneSize && allSizesAreValid
    }
    
    private func saveEntry() {
        errorMessage = nil
        isSaving = true
        
        let sizeDrafts = normalizedSizeDrafts
        
        guard !sizeDrafts.isEmpty else {
            errorMessage = "Add at least one size."
            isSaving = false
            return
        }
        
        guard allSizesAreValid else {
            errorMessage = "Each size must include both code and range."
            isSaving = false
            return
        }
        
        let enteredCodes = sizeDrafts.map { $0.code.localizedLowercase }
        guard Set(enteredCodes).count == enteredCodes.count else {
            errorMessage = "Do not enter duplicate size codes in the same save."
            isSaving = false
            return
        }
        
        do {
            let brand = try resolveBrand()
            let model = try resolveModel(for: brand)
            
            let existingCodes = Set(
                model.sizes.map {
                    $0.code.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
                }
            )
            
            guard existingCodes.isDisjoint(with: enteredCodes) else {
                errorMessage = "One or more size codes already exist for this model."
                isSaving = false
                return
            }
            
            for sizeDraft in sizeDrafts {
                let newSize = DiaperSize(
                    code: sizeDraft.code,
                    descriptionText: sizeDraft.descriptionText.isEmpty ? nil : sizeDraft.descriptionText,
                    sizeRange: sizeDraft.sizeRange,
                    remoteUpdatedAt: nil,
                    source: .userCustom,
                    model: model
                )
                
                modelContext.insert(newSize)
            }
            
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
    
    private func removeSizeDraft(withId id: UUID) {
        guard sizeDrafts.count > 1 else {
            return
        }
        
        sizeDrafts.removeAll { $0.id == id }
    }
    
    private func resolveBrand() throws -> DiaperBrand {
        switch brandSelectionMode {
        case .existing:
            guard let selectedBrand else {
                throw NewDiaperCatalogEntryError.missingBrand
            }
            
            return selectedBrand
            
        case .new:
            let brandName = trimmedPendingBrandName
            
            guard !brandName.isEmpty else {
                throw NewDiaperCatalogEntryError.missingBrand
            }
            
            if let existingBrand = brands.first(where: {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(brandName) == .orderedSame
            }) {
                return existingBrand
            }
            
            let newBrand = DiaperBrand(
                name: brandName,
                countryCode: Locale.current.region?.identifier ?? "IT",
                source: .userCustom
            )
            
            modelContext.insert(newBrand)
            return newBrand
        }
    }
    
    private func resolveModel(for brand: DiaperBrand) throws -> DiaperModel {
        switch modelSelectionMode {
        case .existing:
            guard let selectedExistingModel else {
                throw NewDiaperCatalogEntryError.missingModel
            }
            
            return selectedExistingModel
            
        case .new:
            let modelName = trimmedPendingModelName
            
            guard !modelName.isEmpty else {
                throw NewDiaperCatalogEntryError.missingModel
            }
            
            if let existingModel = brand.models.first(where: {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(modelName) == .orderedSame
            }) {
                return existingModel
            }
            
            let newModel = DiaperModel(
                remoteId: nil,
                name: modelName,
                type: selectedType,
                ageCategory: selectedAgeCategory,
                source: .userCustom,
                isUserEdited: true,
                createdAt: .now,
                updatedAt: .now,
                brand: brand
            )
            
            modelContext.insert(newModel)
            return newModel
        }
    }
    
    private struct ModelPickerSheetView: View {
        @Environment(\.dismiss) private var dismiss
        
        let models: [DiaperModel]
        @Binding var selectedModelId: PersistentIdentifier?
        @Binding var pendingModelName: String
        
        @State private var searchText: String = ""
        
        var body: some View {
            List {
                if !trimmedSearchText.isEmpty {
                    Section {
                        Button {
                            selectedModelId = nil
                            pendingModelName = trimmedSearchText
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Create new model")
                                    .foregroundStyle(.primary)
                                Text(trimmedSearchText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section("Existing models") {
                    ForEach(filteredModels) { model in
                        Button {
                            selectedModelId = model.persistentModelID
                            pendingModelName = model.name
                            dismiss()
                        } label: {
                            let isSelected = (selectedModelId == model.persistentModelID)
                            BrandRow(name: model.name, isSelected: isSelected)
                        }
                    }
                }
            }
            .navigationTitle("Select model")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !pendingModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchText = pendingModelName
                }
            }
        }
        
        private var trimmedSearchText: String {
            searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        private var filteredModels: [DiaperModel] {
            guard !trimmedSearchText.isEmpty else {
                return models
            }
            
            return models.filter { model in
                model.name.localizedCaseInsensitiveContains(trimmedSearchText)
            }
        }
    }
}

private enum NewDiaperCatalogEntryError: LocalizedError {
    case missingBrand
    case missingModel

    var errorDescription: String? {
        switch self {
        case .missingBrand:
            return "Select or create a brand."
        case .missingModel:
            return "Select or create a model."
        }
    }
}

private enum DiaperTextSelectionMode {
    case existing
    case new
}

private struct NewDiaperSizeDraft: Identifiable, Hashable {
    let id: UUID
    var code: String
    var descriptionText: String
    var sizeRange: String

    init(
        id: UUID = UUID(),
        code: String = "",
        descriptionText: String = "",
        sizeRange: String = ""
    ) {
        self.id = id
        self.code = code
        self.descriptionText = descriptionText
        self.sizeRange = sizeRange
    }
}

private struct BrandPickerSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let brands: [DiaperBrand]
    @Binding var selectedBrandId: PersistentIdentifier?
    @Binding var pendingBrandName: String

    @State private var searchText: String = ""

    var body: some View {
        List {
            if !trimmedSearchText.isEmpty {
                Section {
                    Button {
                        selectedBrandId = nil
                        pendingBrandName = trimmedSearchText
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create new brand")
                                .foregroundStyle(.primary)
                            Text(trimmedSearchText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Existing brands") {
                ForEach(filteredBrands) { brand in
                    Button {
                        selectedBrandId = brand.persistentModelID
                        pendingBrandName = brand.name
                        dismiss()
                    } label: {
                        let isSelected = (selectedBrandId == brand.persistentModelID)
                        BrandRow(name: brand.name, isSelected: isSelected)
                    }
                }
            }
        }
        .navigationTitle("Select brand")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search brand")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            if !pendingBrandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchText = pendingBrandName
            }
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredBrands: [DiaperBrand] {
        guard !trimmedSearchText.isEmpty else {
            return brands
        }

        return brands.filter { brand in
            brand.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }
}

private struct BrandRow: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(name)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}

#Preview("New Diaper Catalog Entry") {
    NavigationStack {
        NewDiaperCatalogEntryView()
    }
    .modelContainer(DiaperInventoryPreviewData.makeContainer())
}

#Preview("New Diaper Catalog Entry Dark") {
    NavigationStack {
        NewDiaperCatalogEntryView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(DiaperInventoryPreviewData.makeContainer())
}
