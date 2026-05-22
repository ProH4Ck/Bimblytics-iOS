//
//  FoodItem.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 23/04/2026.
//

import Foundation
import SwiftData

@Model
final class FoodItem {
    @Attribute(.unique) var id: UUID
    var familyId: String?
    var name: String
    var createdAt: Date
    var updatedAt: Date

    var category: FoodCategory?
    var defaultUnit: FoodUnit?

    @Relationship(deleteRule: .nullify, inverse: \FeedingEvent.foodItem)
    var feedingEvents: [FeedingEvent]

    init(
        id: UUID = UUID(),
        familyId: String? = nil,
        name: String,
        category: FoodCategory? = nil,
        defaultUnit: FoodUnit? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.category = category
        self.defaultUnit = defaultUnit
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.feedingEvents = []
    }
}
