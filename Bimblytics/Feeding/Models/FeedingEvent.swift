//
//  FeedingEvent.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 23/04/2026.
//

import Foundation
import SwiftData

@Model
final class FeedingEvent {
    @Attribute(.unique) var id: UUID
    var babyId: UUID
    var eventDate: Date

    var foodName: String
    var foodCategoryName: String?
    var quantity: Double
    var unitName: String
    var unitSymbol: String?

    var notes: String?
    var createdAt: Date

    var foodItem: FoodItem?

    init(
        id: UUID = UUID(),
        babyId: UUID,
        eventDate: Date = .now,
        foodName: String,
        foodCategoryName: String? = nil,
        quantity: Double,
        unitName: String,
        unitSymbol: String? = nil,
        notes: String? = nil,
        foodItem: FoodItem? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.babyId = babyId
        self.eventDate = eventDate
        self.foodName = foodName
        self.foodCategoryName = foodCategoryName
        self.quantity = quantity
        self.unitName = unitName
        self.unitSymbol = unitSymbol
        self.notes = notes
        self.foodItem = foodItem
        self.createdAt = createdAt
    }

    var quantityDisplayText: String {
        let formattedQuantity: String

        if quantity == floor(quantity) {
            formattedQuantity = String(Int(quantity))
        } else {
            formattedQuantity = String(format: "%.1f", quantity)
        }

        let effectiveUnit = (unitSymbol?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? unitSymbol!
            : unitName

        return "\(formattedQuantity) \(effectiveUnit)"
    }
}

extension FeedingEvent {
    convenience init(
        babyId: UUID,
        eventDate: Date = .now,
        foodItem: FoodItem,
        quantity: Double,
        notes: String? = nil
    ) {
        self.init(
            babyId: babyId,
            eventDate: eventDate,
            foodName: foodItem.name,
            foodCategoryName: foodItem.category?.name,
            quantity: quantity,
            unitName: foodItem.defaultUnit?.name ?? "",
            unitSymbol: foodItem.defaultUnit?.symbol,
            notes: notes,
            foodItem: foodItem
        )
    }
}
