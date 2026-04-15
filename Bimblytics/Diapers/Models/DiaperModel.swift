//
//  DiaperModel.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation
import SwiftData

@Model
final class DiaperModel {
    @Attribute(.unique) var id: UUID

    @Attribute(.unique) var remoteId: String?

    var name: String
    var type: DiaperType.RawValue
    var ageCategory: DiaperAgeCategory.RawValue
    var source: DiaperSource.RawValue

    var isUserEdited: Bool

    var createdAt: Date
    var updatedAt: Date

    var brand: DiaperBrand?

    @Relationship(deleteRule: .cascade, inverse: \DiaperSize.model)
    var sizes: [DiaperSize] = []

    init(
        id: UUID = UUID(),
        remoteId: String? = nil,
        name: String,
        type: DiaperType,
        ageCategory: DiaperAgeCategory,
        source: DiaperSource,
        isUserEdited: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        brand: DiaperBrand? = nil
    ) {
        self.id = id
        self.remoteId = remoteId
        self.name = name
        self.type = type.rawValue
        self.ageCategory = ageCategory.rawValue
        self.source = source.rawValue
        self.isUserEdited = isUserEdited
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.brand = brand
    }

    var typeEnum: DiaperType {
        get { DiaperType(rawValue: type) ?? .unknown }
        set { type = newValue.rawValue }
    }

    var ageCategoryEnum: DiaperAgeCategory {
        get { DiaperAgeCategory(rawValue: ageCategory) ?? .unknown }
        set { ageCategory = newValue.rawValue }
    }

    var sourceEnum: DiaperSource {
        get { DiaperSource(rawValue: source) ?? .userCustom }
        set { source = newValue.rawValue }
    }
}
