//
//  InventoryLocation.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation
import SwiftData

@Model
final class InventoryLocation {
    @Attribute(.unique) var id: UUID

    /// Display name shown to the user.
    var name: String

    /// Optional notes, for example "Main nursery closet".
    var notes: String?

    /// Used to sort favorite/default locations first.
    var sortOrder: Int

    /// Marks the default location suggested by the app.
    var isDefault: Bool

    /// Soft delete flag in case you want to hide a location without losing history.
    var isArchived: Bool

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \DiaperInventoryItem.location)
    var inventoryItems: [DiaperInventoryItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        sortOrder: Int = 0,
        isDefault: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
