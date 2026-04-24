//
//  FoodCategory.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 23/04/2026.
//

import Foundation
import SwiftData

@Model
final class FoodCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    var isSystem: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \FoodItem.category)
    var foodItems: [FoodItem]

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        isSystem: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.foodItems = []
    }
}
