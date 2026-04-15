//
//  DiaperInventoryService.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation
import SwiftData

@MainActor
final class DiaperInventoryService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    func getOrCreateInventoryItem(
        for diaperSize: DiaperSize,
        in location: InventoryLocation,
        lowStockThreshold: Int? = nil,
        packageQuantity: Int? = nil,
        notes: String? = nil
    ) throws -> DiaperInventoryItem {
        if let existingItem = try findInventoryItem(for: diaperSize, in: location) {
            var didChange = false

            if let lowStockThreshold, existingItem.lowStockThreshold != lowStockThreshold {
                existingItem.lowStockThreshold = lowStockThreshold
                didChange = true
            }

            if let packageQuantity, existingItem.packageQuantity != packageQuantity {
                existingItem.packageQuantity = packageQuantity
                didChange = true
            }

            if let notes, existingItem.notes != notes {
                existingItem.notes = notes
                didChange = true
            }

            if didChange {
                existingItem.updatedAt = .now
                try save()
            }

            return existingItem
        }

        let inventoryItem = DiaperInventoryItem(
            quantityOnHand: 0,
            lowStockThreshold: lowStockThreshold,
            packageQuantity: packageQuantity,
            notes: notes,
            diaperSize: diaperSize,
            location: location
        )

        modelContext.insert(inventoryItem)
        try save()

        return inventoryItem
    }

    @discardableResult
    func addStock(
        for diaperSize: DiaperSize,
        in location: InventoryLocation,
        quantity: Int,
        type: DiaperStockMovementType = .manualLoad,
        note: String? = nil,
        reference: String? = nil,
        createdAt: Date = .now,
        totalPrice: Decimal? = nil,
        currencyCode: String? = nil
    ) throws -> DiaperStockMovement {
        guard quantity > 0 else {
            throw DiaperInventoryServiceError.invalidQuantity
        }

        let inventoryItem = try getOrCreateInventoryItem(for: diaperSize, in: location)

        return try applyMovement(
            to: inventoryItem,
            type: type,
            quantityDelta: quantity,
            note: note,
            reference: reference,
            createdAt: createdAt,
            totalPrice: totalPrice,
            currencyCode: currencyCode
        )
    }

    @discardableResult
    func adjustStock(
        for diaperSize: DiaperSize,
        in location: InventoryLocation,
        quantityDelta: Int,
        note: String? = nil,
        reference: String? = nil,
        createdAt: Date = .now
    ) throws -> DiaperStockMovement {
        guard quantityDelta != 0 else {
            throw DiaperInventoryServiceError.invalidQuantity
        }

        let inventoryItem = try getOrCreateInventoryItem(for: diaperSize, in: location)
        let resultingQuantity = inventoryItem.quantityOnHand + quantityDelta

        guard resultingQuantity >= 0 else {
            throw DiaperInventoryServiceError.insufficientStock(
                available: inventoryItem.quantityOnHand,
                requested: abs(quantityDelta)
            )
        }

        return try applyMovement(
            to: inventoryItem,
            type: .correction,
            quantityDelta: quantityDelta,
            note: note,
            reference: reference,
            createdAt: createdAt
        )
    }

    @discardableResult
    func consumeStock(
        for diaperSize: DiaperSize,
        in location: InventoryLocation,
        quantity: Int = 1,
        note: String? = nil,
        reference: String? = nil
    ) throws -> DiaperStockMovement {
        guard quantity > 0 else {
            throw DiaperInventoryServiceError.invalidQuantity
        }

        let inventoryItem = try getOrCreateInventoryItem(for: diaperSize, in: location)

        guard inventoryItem.quantityOnHand >= quantity else {
            throw DiaperInventoryServiceError.insufficientStock(
                available: inventoryItem.quantityOnHand,
                requested: quantity
            )
        }

        return try applyMovement(
            to: inventoryItem,
            type: .consumption,
            quantityDelta: -quantity,
            note: note,
            reference: reference
        )
    }

    @discardableResult
    func discardStock(
        for diaperSize: DiaperSize,
        in location: InventoryLocation,
        quantity: Int,
        note: String? = nil,
        reference: String? = nil
    ) throws -> DiaperStockMovement {
        guard quantity > 0 else {
            throw DiaperInventoryServiceError.invalidQuantity
        }

        let inventoryItem = try getOrCreateInventoryItem(for: diaperSize, in: location)

        guard inventoryItem.quantityOnHand >= quantity else {
            throw DiaperInventoryServiceError.insufficientStock(
                available: inventoryItem.quantityOnHand,
                requested: quantity
            )
        }

        return try applyMovement(
            to: inventoryItem,
            type: .discard,
            quantityDelta: -quantity,
            note: note,
            reference: reference
        )
    }

    @discardableResult
    func correctStock(
        for diaperSize: DiaperSize,
        in location: InventoryLocation,
        newQuantity: Int,
        note: String? = nil,
        reference: String? = nil
    ) throws -> DiaperStockMovement {
        guard newQuantity >= 0 else {
            throw DiaperInventoryServiceError.invalidQuantity
        }

        let inventoryItem = try getOrCreateInventoryItem(for: diaperSize, in: location)
        let delta = newQuantity - inventoryItem.quantityOnHand

        guard delta != 0 else {
            throw DiaperInventoryServiceError.noChangeRequired
        }

        return try applyMovement(
            to: inventoryItem,
            type: .correction,
            quantityDelta: delta,
            note: note,
            reference: reference
        )
    }

    func transferStock(
        for diaperSize: DiaperSize,
        quantity: Int,
        from sourceLocation: InventoryLocation,
        to destinationLocation: InventoryLocation,
        note: String? = nil,
        reference: String? = nil
    ) throws -> DiaperStockTransferResult {
        guard quantity > 0 else {
            throw DiaperInventoryServiceError.invalidQuantity
        }

        guard sourceLocation.persistentModelID != destinationLocation.persistentModelID else {
            throw DiaperInventoryServiceError.sameSourceAndDestinationLocation
        }

        let sourceInventoryItem = try getOrCreateInventoryItem(for: diaperSize, in: sourceLocation)

        guard sourceInventoryItem.quantityOnHand >= quantity else {
            throw DiaperInventoryServiceError.insufficientStock(
                available: sourceInventoryItem.quantityOnHand,
                requested: quantity
            )
        }

        let destinationInventoryItem = try getOrCreateInventoryItem(for: diaperSize, in: destinationLocation)

        let transferReference = reference ?? UUID().uuidString
        let effectiveNote = note ?? "Stock transfer"

        let outgoingMovement = try applyMovement(
            to: sourceInventoryItem,
            type: .transferOut,
            quantityDelta: -quantity,
            note: effectiveNote,
            reference: transferReference,
            saveChanges: false
        )

        let incomingMovement = try applyMovement(
            to: destinationInventoryItem,
            type: .transferIn,
            quantityDelta: quantity,
            note: effectiveNote,
            reference: transferReference,
            saveChanges: false
        )

        try save()

        return DiaperStockTransferResult(
            outgoingMovement: outgoingMovement,
            incomingMovement: incomingMovement
        )
    }

    func getCurrentQuantity(
        for diaperSize: DiaperSize,
        in location: InventoryLocation
    ) throws -> Int {
        let inventoryItem = try findInventoryItem(for: diaperSize, in: location)
        return inventoryItem?.quantityOnHand ?? 0
    }

    func getTotalQuantity(for diaperSize: DiaperSize) throws -> Int {
        let inventoryItems = try fetchInventoryItems(for: diaperSize)
        return inventoryItems.reduce(0) { $0 + $1.quantityOnHand }
    }

    func getLowStockItems() throws -> [DiaperInventoryItem] {
        let descriptor = FetchDescriptor<DiaperInventoryItem>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse)
            ]
        )

        let items = try modelContext.fetch(descriptor)

        return items.filter { $0.isLowStock }
    }

    // MARK: - Private helpers

    private func findInventoryItem(
        for diaperSize: DiaperSize,
        in location: InventoryLocation
    ) throws -> DiaperInventoryItem? {
        let diaperSizeId = diaperSize.persistentModelID
        let locationId = location.persistentModelID

        let predicate = #Predicate<DiaperInventoryItem> { item in
            item.diaperSize?.persistentModelID == diaperSizeId &&
            item.location?.persistentModelID == locationId
        }

        var descriptor = FetchDescriptor<DiaperInventoryItem>(predicate: predicate)
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    private func fetchInventoryItems(for diaperSize: DiaperSize) throws -> [DiaperInventoryItem] {
        let diaperSizeId = diaperSize.persistentModelID

        let predicate = #Predicate<DiaperInventoryItem> { item in
            item.diaperSize?.persistentModelID == diaperSizeId
        }

        let descriptor = FetchDescriptor<DiaperInventoryItem>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    private func applyMovement(
        to inventoryItem: DiaperInventoryItem,
        type: DiaperStockMovementType,
        quantityDelta: Int,
        note: String?,
        reference: String?,
        createdAt: Date = .now,
        totalPrice: Decimal? = nil,
        currencyCode: String? = nil,
        saveChanges: Bool = true
    ) throws -> DiaperStockMovement {
        let newQuantity = inventoryItem.quantityOnHand + quantityDelta

        guard newQuantity >= 0 else {
            throw DiaperInventoryServiceError.negativeStockNotAllowed
        }

        inventoryItem.quantityOnHand = newQuantity
        inventoryItem.updatedAt = .now

        let movement = DiaperStockMovement(
            type: type,
            quantityDelta: quantityDelta,
            resultingQuantity: newQuantity,
            note: note,
            reference: reference,
            totalPrice: totalPrice,
            currencyCode: currencyCode,
            createdAt: createdAt,
            inventoryItem: inventoryItem
        )

        modelContext.insert(movement)

        if saveChanges {
            try save()
        }

        return movement
    }

    private func save() throws {
        try modelContext.save()
    }
}
