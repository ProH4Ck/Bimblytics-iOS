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
    private let baby: Baby?
    @State private var name: String
    @State private var birthDate: Date
    @State private var gender: Gender
    @State private var diaperEnabled: Bool

    
    init(baby: Baby?) {
        self.baby = baby
        _name = State(initialValue: baby?.name ?? "")
        _birthDate = State(initialValue: baby?.birthDate ?? Date())
        _gender = State(initialValue: baby?.gender ?? .male)
        _diaperEnabled = State(initialValue: baby?.diaperEnabled ?? true)
    }

    var body: some View {
        Form {
            Section("Data") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                DatePicker("Birth date", selection: $birthDate, in: ...Date(), displayedComponents: [.date])
                Picker("Gender", selection: $gender) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                }
                .pickerStyle(.segmented)
            }

            Section("Operations") {
                Toggle("Diaper change", isOn: $diaperEnabled)
            }
        }
        .background(AppColors.background)
        .navigationTitle(baby == nil ? "New baby" : (name.isEmpty ? "Baby" : name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveBaby()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppColors.primary)
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onDisappear {
            applyChangesIfNeeded()
        }
    }


    private func saveBaby() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        if let baby {
            baby.name = trimmedName
            baby.birthDate = birthDate
            baby.gender = gender
            baby.diaperEnabled = diaperEnabled
        } else {
            let newBaby = Baby(
                name: trimmedName,
                birthDate: birthDate,
                gender: gender,
                diaperEnabled: diaperEnabled
            )
            modelContext.insert(newBaby)
        }

        try? modelContext.save()
        dismiss()
    }

    private func applyChangesIfNeeded() {
        guard let baby else {
            return
        }

        baby.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        baby.birthDate = birthDate
        baby.gender = gender
        baby.diaperEnabled = diaperEnabled

        try? modelContext.save()
    }
}
