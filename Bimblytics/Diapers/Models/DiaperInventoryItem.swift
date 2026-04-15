//
//  DiaperInventoryItem.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation
import SwiftData

@Model
final class DiaperInventoryItem {
    @Attribute(.unique) var id: UUID

    /// Current quantity available in stock for a given diaper size in a given location.
    var quantityOnHand: Int

    /// Optional threshold used to show low stock alerts.
    var lowStockThreshold: Int?

    /// Optional package size reference, useful for purchases.
    var packageQuantity: Int?

    /// Optional user notes.
    var notes: String?

    var createdAt: Date
    var updatedAt: Date

    /// One inventory item refers to one diaper size.
    var diaperSize: DiaperSize?

    /// One inventory item belongs to one physical location.
    var location: InventoryLocation?

    @Relationship(deleteRule: .cascade, inverse: \DiaperStockMovement.inventoryItem)
    var movements: [DiaperStockMovement] = []

    init(
        id: UUID = UUID(),
        quantityOnHand: Int = 0,
        lowStockThreshold: Int? = nil,
        packageQuantity: Int? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        diaperSize: DiaperSize? = nil,
        location: InventoryLocation? = nil
    ) {
        self.id = id
        self.quantityOnHand = max(0, quantityOnHand)
        self.lowStockThreshold = lowStockThreshold
        self.packageQuantity = packageQuantity
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.diaperSize = diaperSize
        self.location = location
    }

    var isLowStock: Bool {
        guard let lowStockThreshold else {
            return false
        }

        return quantityOnHand <= lowStockThreshold
    }

    var displayName: String {
        guard let diaperSize else {
            return "Unknown diaper"
        }

        let brandName = diaperSize.model?.brand?.name ?? ""
        let modelName = diaperSize.model?.name ?? ""
        let sizeName = diaperSize.displayName
        let locationName = location?.name ?? ""

        let productParts = [brandName, modelName, sizeName]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")

        if locationName.isEmpty {
            return productParts
        }

        return "\(productParts) • \(locationName)"
    }
}
