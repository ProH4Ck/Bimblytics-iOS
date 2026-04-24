//
//  FoodUnit.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 23/04/2026.
//

import Foundation
import SwiftData

@Model
final class FoodUnit {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbol: String
    var sortOrder: Int
    var isSystem: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \FoodItem.defaultUnit)
    var foodItems: [FoodItem]

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        sortOrder: Int = 0,
        isSystem: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.foodItems = []
    }

    var displayName: String {
        if symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }

        return "\(name) (\(symbol))"
    }
}
