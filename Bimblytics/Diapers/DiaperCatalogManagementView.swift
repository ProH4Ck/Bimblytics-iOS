//
//  DiaperCatalogManagementView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 09/04/2026.
//

import SwiftUI
import SwiftData

struct DiaperCatalogManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\DiaperSize.code)
    ])
    private var diaperSizes: [DiaperSize]

    @State private var isImporting: Bool = false
    @State private var resultMessage: String?
    @State private var isShowingResultAlert: Bool = false
    @State private var expandedBrands: Set<String> = []
    @State private var expandedModels: Set<String> = []

    var body: some View {
        List {
            if groupedCatalogEntries.isEmpty {
                ContentUnavailableView(
                    "No diapers yet",
                    systemImage: "tray",
                    description: Text("Import the JSON catalog or create a new diaper model to populate the archive.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedCatalogEntries) { brandGroup in
                    Section {
                        Group {
                            if expandedBrands.contains(brandGroup.id) {
                                ForEach(brandGroup.models) { modelGroup in
                                    DisclosureGroup(
                                        isExpanded: bindingForModel(modelGroup.id),
                                        content: {
                                            VStack(spacing: 0) {
                                                ForEach(modelGroup.sizes) { diaperSize in
                                                    sizeRow(for: diaperSize)
                                                }
                                            }
                                            .padding(.top, 6)
                                        },
                                        label: {
                                            modelRow(for: modelGroup)
                                        }
                                    )
                                    .tint(AppColors.textSecondary)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .contentTransition(.opacity)
                                }
                            }
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: expandedBrands)
                    } header: {
                        Button {
                            toggleBrandExpansion(brandGroup.id)
                        } label: {
                            HStack(spacing: 8) {
                                Text(brandGroup.brandName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)

                                Spacer()

                                Image(systemName: expandedBrands.contains(brandGroup.id) ? "chevron.up" : "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        }
                        .buttonStyle(.plain)
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Diaper catalog")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    downloadAndImportCatalog()
                } label: {
                    if isImporting {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                }
                .disabled(isImporting)
                .accessibilityLabel("Download and import JSON")

                NavigationLink {
                    NewDiaperCatalogEntryView()
                } label: {
                    Image(systemName: "plus.rectangle.on.folder")
                }
                .accessibilityLabel("Create new diaper model")
            }
        }
        .alert("Catalog import", isPresented: $isShowingResultAlert) {
            Button("OK", role: .cancel) {
            }
        } message: {
            Text(resultMessage ?? "Unknown result")
        }
        .onAppear {
            if expandedBrands.isEmpty {
                expandedBrands = Set(groupedCatalogEntries.map(\.id))
            }
        }
    }

    private var groupedCatalogEntries: [DiaperCatalogBrandGroup] {
        let groupedByBrand = Dictionary(grouping: diaperSizes) { diaperSize in
            diaperSize.model?.brand?.name ?? "Unknown brand"
        }

        return groupedByBrand
            .map { brandName, sizes in
                let groupedByModel = Dictionary(grouping: sizes) { diaperSize in
                    diaperSize.model?.name ?? "Unknown model"
                }

                let models = groupedByModel
                    .map { modelName, modelSizes in
                        DiaperCatalogModelGroup(
                            brandName: brandName,
                            modelName: modelName,
                            sizes: modelSizes.sorted {
                                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                            }
                        )
                    }
                    .sorted { lhs, rhs in
                        lhs.modelName.localizedCaseInsensitiveCompare(rhs.modelName) == .orderedAscending
                    }

                return DiaperCatalogBrandGroup(
                    brandName: brandName,
                    models: models
                )
            }
            .sorted { lhs, rhs in
                lhs.brandName.localizedCaseInsensitiveCompare(rhs.brandName) == .orderedAscending
            }
    }

    private func bindingForModel(_ id: String) -> Binding<Bool> {
        Binding(
            get: {
                expandedModels.contains(id)
            },
            set: { isExpanded in
                if isExpanded {
                    expandedModels.insert(id)
                } else {
                    expandedModels.remove(id)
                }
            }
        )
    }

    private func toggleBrandExpansion(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedBrands.contains(id) {
                expandedBrands.remove(id)
            } else {
                expandedBrands.insert(id)
            }
        }
    }

    @ViewBuilder
    private func modelRow(for modelGroup: DiaperCatalogModelGroup) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(modelGroup.modelName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 8) {
                    Text(modelGroup.sizes.count == 1 ? "1 size" : "\(modelGroup.sizes.count) sizes")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func sizeRow(for diaperSize: DiaperSize) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(diaperSize.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)

                Text(diaperSize.sizeRange)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)

                if diaperSize.sourceEnum == .userCustom {
                    Text("Custom")
                        .font(.caption)
                        .foregroundStyle(AppColors.primary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private struct DiaperCatalogBrandGroup: Identifiable {
        let brandName: String
        let models: [DiaperCatalogModelGroup]

        var id: String {
            brandName
        }
    }

    private struct DiaperCatalogModelGroup: Identifiable {
        let brandName: String
        let modelName: String
        let sizes: [DiaperSize]

        var id: String {
            "\(brandName)|\(modelName)"
        }
    }

    private func downloadAndImportCatalog() {
        isImporting = true

        defer {
            isImporting = false
        }

        // TODO:
        // Replace this placeholder implementation with the real download/import service.
        // For now this is only the management page and action entry point.
        resultMessage = "The catalog import action is ready. The next step is connecting it to the real download and import service."
        isShowingResultAlert = true
    }
}

#Preview("Diaper Catalog Management") {
    NavigationStack {
        DiaperCatalogManagementView()
    }
    .modelContainer(DiaperInventoryPreviewData.makeContainer())
}

#Preview("Diaper Catalog Management Dark") {
    NavigationStack {
        DiaperCatalogManagementView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(DiaperInventoryPreviewData.makeContainer())
}
