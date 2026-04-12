//
//  BabyDetailView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 12/04/2026.
//

import SwiftUI
import SwiftData

struct BabyDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var baby: Baby

    var body: some View {
        Form {
            Section("Data") {
                TextField("Name", text: $baby.name)
                    .textInputAutocapitalization(.words)
                DatePicker("Birth date", selection: $baby.birthDate, in: ...Date(), displayedComponents: [.date])
                Picker("Gender", selection: $baby.gender) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                }
                .pickerStyle(.segmented)
            }

            Section("Operations") {
                Toggle("Diaper change", isOn: $baby.diaperEnabled)
            }
        }
        .background(AppColors.background)
        .navigationTitle(baby.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .onDisappear {
            try? modelContext.save()
        }
    }
}
