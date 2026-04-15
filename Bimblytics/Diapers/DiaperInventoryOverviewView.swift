//
//  DiaperInventoryOverviewView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import SwiftUI
import SwiftData

struct DiaperInventoryOverviewView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<InventoryLocation> { !$0.isArchived },
        sort: [
            SortDescriptor(\InventoryLocation.sortOrder),
            SortDescriptor(\InventoryLocation.name)
        ]
    )
    private var locations: [InventoryLocation]

    @State private var isShowingNewLocationSheet: Bool = false
    @State private var isShowingAddStockSheet: Bool = false
    @State private var isShowingNewDiaperModelSheet: Bool = false
    @State private var isShowingCatalogManagementSheet: Bool = false
    @State private var locationToEdit: InventoryLocation?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if locations.isEmpty {
                        ContentUnavailableView(
                            "No locations",
                            systemImage: "shippingbox",
                            description: Text("Create your first location to start tracking diaper stock.")
                        )
                    } else {
                        ForEach(locations) { location in
                            InventoryLocationSectionView(location: location) { locationToEdit in
                                self.locationToEdit = locationToEdit
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Diaper stock")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingCatalogManagementSheet = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .accessibilityLabel("Manage catalog")
                    .foregroundStyle(AppColors.primary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isShowingAddStockSheet = true
                        } label: {
                            Label("Add stock", systemImage: "shippingbox")
                        }

                        Button {
                            isShowingNewDiaperModelSheet = true
                        } label: {
                            Label("New diaper model", systemImage: "plus.rectangle.on.folder")
                        }

                        Button {
                            isShowingCatalogManagementSheet = true
                        } label: {
                            Label("Manage catalog", systemImage: "list.bullet.rectangle")
                        }

                        Button {
                            isShowingNewLocationSheet = true
                        } label: {
                            Label("New location", systemImage: "house.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                    .foregroundStyle(AppColors.primary)
                }
            }
            .sheet(isPresented: $isShowingNewLocationSheet) {
                NavigationStack {
                    NewInventoryLocationView()
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingAddStockSheet) {
                NavigationStack {
                    DiaperCatalogSearchView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingNewDiaperModelSheet) {
                NavigationStack {
                    NewDiaperCatalogEntryView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
            .sheet(item: $locationToEdit) { location in
                NavigationStack {
                    NewInventoryLocationView(location: location)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingCatalogManagementSheet) {
                NavigationStack {
                    DiaperCatalogManagementView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview("Overview") {
    DiaperInventoryOverviewView()
        .modelContainer(DiaperInventoryPreviewData.makeContainer())
}

#Preview("Overview - Dark") {
    DiaperInventoryOverviewView()
        .modelContainer(DiaperInventoryPreviewData.makeContainer())
        .preferredColorScheme(.dark)
}
