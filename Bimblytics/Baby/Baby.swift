//
//  Baby.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 10/04/2026.
//

import SwiftData
import SwiftUI

enum Gender: String, CaseIterable, Identifiable, Codable {
    case male = "Male"
    case female = "Female"
    var id: String { rawValue }
}

@Model
final class Baby: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var birthDate: Date

    private var genderCode: String

    var diaperEnabled: Bool

    var gender: Gender {
        get {
            Gender(rawValue: genderCode) ?? .male
        }
        set {
            genderCode = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date,
        gender: Gender,
        diaperEnabled: Bool
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.genderCode = gender.rawValue
        self.diaperEnabled = diaperEnabled
    }

    var backgroundColor: Color {
        get {
            if gender == .male {
                AppColors.colorMale
            } else {
                AppColors.colorFemale
            }
        }
    }

    public func ageText() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.year, .month, .day]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .full
        return formatter.string(from: birthDate, to: Date()) ?? ""
    }
}
