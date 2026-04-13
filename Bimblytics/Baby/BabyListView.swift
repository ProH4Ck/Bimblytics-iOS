//
//  BabyListView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 12/04/2026.
//

import SwiftUI
import SwiftData

struct BabyListView: View {
    @Query(sort: \Baby.name, order: .forward) private var babies: [Baby]
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddBaby = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(babies) { baby in
                    NavigationLink {
                        BabyDetailView(baby: baby)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(baby.gender == .male ? AppColors.colorMale : AppColors.colorFemale)
                                Image(systemName: "person.fill")
                            }
                            .frame(width: 36, height: 36)
                            
                            VStack(alignment: .leading) {
                                Text(baby.name)
                                Text(baby.ageText())
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .background(AppColors.background)
            .navigationTitle("Babies")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingAddBaby) {
                BabyDetailView(baby: nil)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAddBaby = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("Add baby")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("BabyListView") {
    return BabyListView()
        .modelContainer(PreviewData.makeContainer())
}

#Preview("BabyListView - Dark") {
    return BabyListView()
        .modelContainer(PreviewData.makeContainer())
        .preferredColorScheme(.dark)
}
