//
//  Baby.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 10/04/2026.
//

import Foundation
import SwiftData
import SwiftUI

enum Gender: String, CaseIterable, Identifiable, Codable {
    case male = "Male"
    case female = "Female"
    var id: String { rawValue }
}

@Model
final class Baby: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID
    var name: String
    var birthDate: Date

    private var genderCode: String

    var diaperEnabled: Bool

    // Typed accessor
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

    static func == (lhs: Baby, rhs: Baby) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Baby {
    static var sample: [Baby] {
        let now = Date()
        return [
            Baby(
                name: "Sophie",
                birthDate: Calendar.current.date(byAdding: .month, value: -6, to: now)!,
                gender: .female,
                diaperEnabled: true
            ),
            Baby(
                name: "Alan",
                birthDate: Calendar.current.date(byAdding: .year, value: -1, to: now)!,
                gender: .male,
                diaperEnabled: true
            )
        ]
    }
}
