//
//  DiaperStockMovement.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation
import SwiftData

@Model
final class DiaperStockMovement {
    @Attribute(.unique) var id: UUID

    var type: DiaperStockMovementType.RawValue

    /// Positive for loads, negative for consumptions/discards.
    var quantityDelta: Int

    /// Inventory quantity immediately after applying this movement.
    var resultingQuantity: Int?

    /// Optional free text note.
    var note: String?

    /// Optional external reference, for example receipt id or order code.
    var reference: String?

    /// Optional total price for load or purchase movements.
    var totalPrice: Decimal?

    /// Optional ISO currency code for price statistics.
    var currencyCode: String?

    var createdAt: Date

    var inventoryItem: DiaperInventoryItem?

    init(
        id: UUID = UUID(),
        type: DiaperStockMovementType,
        quantityDelta: Int,
        resultingQuantity: Int? = nil,
        note: String? = nil,
        reference: String? = nil,
        totalPrice: Decimal? = nil,
        currencyCode: String? = nil,
        createdAt: Date = .now,
        inventoryItem: DiaperInventoryItem? = nil
    ) {
        self.id = id
        self.type = type.rawValue
        self.quantityDelta = quantityDelta
        self.resultingQuantity = resultingQuantity
        self.note = note
        self.reference = reference
        self.totalPrice = totalPrice
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.inventoryItem = inventoryItem
    }

    var typeEnum: DiaperStockMovementType {
        get { DiaperStockMovementType(rawValue: type) ?? .correction }
        set { type = newValue.rawValue }
    }

    var isLoad: Bool {
        quantityDelta > 0
    }

    var isUnload: Bool {
        quantityDelta < 0
    }
}
