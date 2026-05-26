//
//  BimblyticsEventSyncCoordinator.swift
//  Bimblytics
//
//  Created by Codex on 25/05/2026.
//

import Foundation
import SwiftData

@MainActor
final class BimblyticsEventSyncCoordinator {
    private static let placeholderActorId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private let authenticationService: any BimblyticsAuthServicing
    private let deviceService: any BimblyticsDeviceServicing
    private let syncService: any BimblyticsSyncServicing

    convenience init() {
        self.init(
            authenticationService: BimblyticsAuthService(),
            deviceService: BimblyticsDeviceService(),
            syncService: BimblyticsSyncService()
        )
    }

    init(
        authenticationService: any BimblyticsAuthServicing,
        deviceService: any BimblyticsDeviceServicing,
        syncService: any BimblyticsSyncServicing
    ) {
        self.authenticationService = authenticationService
        self.deviceService = deviceService
        self.syncService = syncService
    }

    func synchronize(
        diaperChangeEvent event: DiaperChangeEvent,
        familyId: String,
        modelContext: ModelContext
    ) async throws {
        guard let familyUuid = UUID(uuidString: familyId) else { return }
        let payloadActorId = self.payloadActorId
        let change = try ClientSyncChangeRequest.upsert(
            familyId: familyUuid,
            entityType: SyncEntityType.diaperChangeEvent.rawValue,
            entityId: event.id,
            changedAt: event.createdAt,
            payload: DiaperChangeEventPushPayload(
                id: event.id, familyId: familyUuid, babyId: event.babyId, eventDate: event.date,
                diaperInventoryItemId: nil, inventoryLocationId: event.location?.id,
                stockMovementId: event.stockMovementId.flatMap(UUID.init(uuidString:)),
                peeLevel: event.peeLevelRaw, poopLevel: event.poopLevelRaw, notes: event.notes,
                createdAt: event.createdAt, updatedAt: event.createdAt, deletedAt: nil,
                createdByUserId: payloadActorId, createdByDeviceId: payloadActorId,
                lastModifiedByUserId: payloadActorId, lastModifiedByDeviceId: payloadActorId, version: 1
            )
        )
        try SyncOutboxStore.enqueue(change, familyId: familyId, modelContext: modelContext)
        try await flush(familyId: familyId, babyId: event.babyId, modelContext: modelContext)
    }

    func synchronize(
        feedingEvent event: FeedingEvent,
        familyId: String,
        modelContext: ModelContext
    ) async throws {
        guard let familyUuid = UUID(uuidString: familyId) else { return }
        let payloadActorId = self.payloadActorId
        let change = try ClientSyncChangeRequest.upsert(
            familyId: familyUuid,
            entityType: SyncEntityType.feedingEvent.rawValue,
            entityId: event.id,
            changedAt: event.createdAt,
            payload: FeedingEventPushPayload(
                id: event.id, familyId: familyUuid, babyId: event.babyId, eventDate: event.eventDate,
                foodId: event.foodItem?.id, quantity: event.quantity, unit: event.unitSymbol ?? event.unitName,
                notes: event.notes, createdAt: event.createdAt, updatedAt: event.createdAt, deletedAt: nil,
                createdByUserId: payloadActorId, createdByDeviceId: payloadActorId,
                lastModifiedByUserId: payloadActorId, lastModifiedByDeviceId: payloadActorId, version: 1
            )
        )
        try SyncOutboxStore.enqueue(change, familyId: familyId, modelContext: modelContext)
        try await flush(familyId: familyId, babyId: event.babyId, modelContext: modelContext)
    }

    func synchronize(
        foodCategory category: FoodCategory,
        familyId: String,
        modelContext: ModelContext
    ) async throws {
        guard let familyUuid = UUID(uuidString: familyId) else { return }
        let payloadActorId = self.payloadActorId
        let change = try ClientSyncChangeRequest.upsert(
            familyId: familyUuid,
            entityType: SyncEntityType.foodCategory.rawValue,
            entityId: category.id,
            changedAt: category.updatedAt,
            payload: FoodCategoryPushPayload(
                id: category.id, familyId: familyUuid, name: category.name, sortOrder: category.sortOrder,
                isSystem: category.isSystem, isArchived: category.isArchived,
                createdAt: category.createdAt, updatedAt: category.updatedAt, deletedAt: nil,
                createdByUserId: payloadActorId, createdByDeviceId: payloadActorId,
                lastModifiedByUserId: payloadActorId, lastModifiedByDeviceId: payloadActorId, version: 1
            )
        )
        try SyncOutboxStore.enqueue(change, familyId: familyId, modelContext: modelContext)
        try await flush(familyId: familyId, babyId: nil, modelContext: modelContext)
    }

    func synchronize(
        foodUnit unit: FoodUnit,
        familyId: String,
        modelContext: ModelContext
    ) async throws {
        guard let familyUuid = UUID(uuidString: familyId) else { return }
        let payloadActorId = self.payloadActorId
        let change = try ClientSyncChangeRequest.upsert(
            familyId: familyUuid,
            entityType: SyncEntityType.foodUnit.rawValue,
            entityId: unit.id,
            changedAt: unit.updatedAt,
            payload: FoodUnitPushPayload(
                id: unit.id, familyId: familyUuid, name: unit.name, symbol: unit.symbol,
                sortOrder: unit.sortOrder, isSystem: unit.isSystem, isArchived: unit.isArchived,
                createdAt: unit.createdAt, updatedAt: unit.updatedAt, deletedAt: nil,
                createdByUserId: payloadActorId, createdByDeviceId: payloadActorId,
                lastModifiedByUserId: payloadActorId, lastModifiedByDeviceId: payloadActorId, version: 1
            )
        )
        try SyncOutboxStore.enqueue(change, familyId: familyId, modelContext: modelContext)
        try await flush(familyId: familyId, babyId: nil, modelContext: modelContext)
    }

    func synchronize(
        foodItem item: FoodItem,
        familyId: String,
        modelContext: ModelContext
    ) async throws {
        guard let familyUuid = UUID(uuidString: familyId) else { return }
        let payloadActorId = self.payloadActorId
        let change = try ClientSyncChangeRequest.upsert(
            familyId: familyUuid,
            entityType: SyncEntityType.foodItem.rawValue,
            entityId: item.id,
            changedAt: item.updatedAt,
            payload: FoodItemPushPayload(
                id: item.id, familyId: familyUuid, name: item.name,
                categoryId: item.category?.id, defaultUnitId: item.defaultUnit?.id,
                createdAt: item.createdAt, updatedAt: item.updatedAt, deletedAt: nil,
                createdByUserId: payloadActorId, createdByDeviceId: payloadActorId,
                lastModifiedByUserId: payloadActorId, lastModifiedByDeviceId: payloadActorId, version: 1
            )
        )
        try SyncOutboxStore.enqueue(change, familyId: familyId, modelContext: modelContext)
        try await flush(familyId: familyId, babyId: nil, modelContext: modelContext)
    }

    func enqueueDeletion(
        entityType: SyncEntityType,
        entityId: UUID,
        familyId: String,
        modelContext: ModelContext
    ) throws {
        guard let familyUuid = UUID(uuidString: familyId) else { return }
        let change = ClientSyncChangeRequest.delete(
            familyId: familyUuid,
            entityType: entityType.rawValue,
            entityId: entityId
        )
        try SyncOutboxStore.enqueue(change, familyId: familyId, modelContext: modelContext)
    }

    func synchronizeDeletion(
        familyId: String,
        babyId: UUID?,
        modelContext: ModelContext
    ) async throws {
        try await flush(familyId: familyId, babyId: babyId, modelContext: modelContext)
    }

    func synchronize(activatedBaby baby: Baby, modelContext: ModelContext) async throws {
        guard let familyId = baby.familyId else { return }
        try await flush(familyId: familyId, babyId: baby.id, modelContext: modelContext)
    }

    private var payloadActorId: UUID {
        // The server replaces audit identities with the authenticated user and registered device.
        deviceService.deviceId ?? Self.placeholderActorId
    }

    private func flush(
        familyId: String,
        babyId: UUID?,
        modelContext: ModelContext
    ) async throws {
        guard let familyUuid = UUID(uuidString: familyId) else { return }

        let accessToken = try await authenticationService.validAccessToken()
        let deviceId = try await deviceService.registerDevice(accessToken: accessToken)
        let pending = try SyncOutboxStore.pending(familyId: familyId, modelContext: modelContext)
            .sorted(by: outboxOrder)

        var localChanges: [ClientSyncChangeRequest] = []
        var sentByRequestId: [UUID: SentOutboxSnapshot] = [:]

        for entry in pending {
            guard let operation = entry.operation else { continue }
            let request = ClientSyncChangeRequest(
                clientChangeId: UUID(),
                familyId: familyUuid,
                entityType: entry.entityType,
                entityId: entry.entityId,
                operation: operation,
                changedAt: entry.changedAt,
                baseVersion: nil,
                payloadJson: entry.payloadJson
            )
            localChanges.append(request)
            sentByRequestId[request.clientChangeId] = SentOutboxSnapshot(
                key: entry.key,
                changedAt: entry.changedAt,
                operationRawValue: entry.operationRawValue,
                payloadJson: entry.payloadJson
            )
        }

        var lastKnownServerSequence: Int64 = 0
        var outgoingChanges = localChanges
        var hasMore: Bool

        repeat {
            let response = try await syncService.sync(
                deviceId: deviceId,
                lastKnownServerSequence: lastKnownServerSequence,
                localChanges: outgoingChanges,
                accessToken: accessToken
            )
            let acceptedSnapshots = response.acceptedLocalChanges.compactMap { accepted in
                sentByRequestId[accepted.clientChangeId]
            }
            try SyncOutboxStore.removeAccepted(acceptedSnapshots, modelContext: modelContext)
            try apply(
                response.remoteChanges,
                for: babyId,
                in: familyUuid,
                localFamilyId: familyId,
                modelContext: modelContext
            )
            try modelContext.save()

            outgoingChanges = []
            lastKnownServerSequence = response.currentSequence
            hasMore = response.hasMore
        } while hasMore
    }

    private func outboxOrder(_ lhs: SyncOutboxChange, _ rhs: SyncOutboxChange) -> Bool {
        let lhsPriority = SyncEntityType(rawValue: lhs.entityType)?.sendPriority ?? 99
        let rhsPriority = SyncEntityType(rawValue: rhs.entityType)?.sendPriority ?? 99
        return lhsPriority == rhsPriority ? lhs.changedAt < rhs.changedAt : lhsPriority < rhsPriority
    }

    private func apply(
        _ changes: [ServerSyncChangeResponse],
        for babyId: UUID?,
        in familyId: UUID,
        localFamilyId: String,
        modelContext: ModelContext
    ) throws {
        for change in changes.sorted(by: remoteOrder) where change.familyId == familyId {
            guard let entityType = SyncEntityType(rawValue: change.entityType) else {
                continue
            }
            let hasPendingChange = try SyncOutboxStore.hasPending(
                    familyId: localFamilyId,
                    entityType: entityType,
                    entityId: change.entityId,
                    modelContext: modelContext
                )
            guard !hasPendingChange else {
                continue
            }

            switch (entityType, change.operation) {
            case (.foodCategory, .upsert):
                try upsert(try decode(FoodCategorySyncPayload.self, from: change.payloadJson), localFamilyId: localFamilyId, modelContext: modelContext)
            case (.foodCategory, .delete):
                try deleteFoodCategory(id: change.entityId, localFamilyId: localFamilyId, modelContext: modelContext)
            case (.foodUnit, .upsert):
                try upsert(try decode(FoodUnitSyncPayload.self, from: change.payloadJson), localFamilyId: localFamilyId, modelContext: modelContext)
            case (.foodUnit, .delete):
                try deleteFoodUnit(id: change.entityId, localFamilyId: localFamilyId, modelContext: modelContext)
            case (.foodItem, .upsert):
                try upsert(try decode(FoodItemSyncPayload.self, from: change.payloadJson), localFamilyId: localFamilyId, modelContext: modelContext)
            case (.foodItem, .delete):
                try deleteFoodItem(id: change.entityId, localFamilyId: localFamilyId, modelContext: modelContext)
            case (.diaperChangeEvent, .upsert):
                let payload = try decode(DiaperChangeEventSyncPayload.self, from: change.payloadJson)
                if babyId == nil || payload.babyId == babyId { try upsert(payload, modelContext: modelContext) }
            case (.diaperChangeEvent, .delete):
                try deleteDiaperChangeEvent(id: change.entityId, babyId: babyId, modelContext: modelContext)
            case (.feedingEvent, .upsert):
                let payload = try decode(FeedingEventSyncPayload.self, from: change.payloadJson)
                if babyId == nil || payload.babyId == babyId { try upsert(payload, modelContext: modelContext) }
            case (.feedingEvent, .delete):
                try deleteFeedingEvent(id: change.entityId, babyId: babyId, modelContext: modelContext)
            }
        }
    }

    private func upsert(_ payload: FoodCategorySyncPayload, localFamilyId: String, modelContext: ModelContext) throws {
        let id = payload.id
        let existing = try fetchFoodCategory(id: id, modelContext: modelContext)
        if let existing {
            existing.familyId = localFamilyId
            existing.name = payload.name
            existing.sortOrder = payload.sortOrder
            existing.isSystem = payload.isSystem
            existing.isArchived = payload.isArchived
            existing.createdAt = payload.createdAt
            existing.updatedAt = payload.updatedAt
        } else {
            modelContext.insert(FoodCategory(
                id: payload.id, familyId: localFamilyId, name: payload.name,
                sortOrder: payload.sortOrder, isSystem: payload.isSystem,
                isArchived: payload.isArchived, createdAt: payload.createdAt, updatedAt: payload.updatedAt
            ))
        }
    }

    private func upsert(_ payload: FoodUnitSyncPayload, localFamilyId: String, modelContext: ModelContext) throws {
        let id = payload.id
        let existing = try fetchFoodUnit(id: id, modelContext: modelContext)
        if let existing {
            existing.familyId = localFamilyId
            existing.name = payload.name
            existing.symbol = payload.symbol
            existing.sortOrder = payload.sortOrder
            existing.isSystem = payload.isSystem
            existing.isArchived = payload.isArchived
            existing.createdAt = payload.createdAt
            existing.updatedAt = payload.updatedAt
        } else {
            modelContext.insert(FoodUnit(
                id: payload.id, familyId: localFamilyId, name: payload.name, symbol: payload.symbol,
                sortOrder: payload.sortOrder, isSystem: payload.isSystem, isArchived: payload.isArchived,
                createdAt: payload.createdAt, updatedAt: payload.updatedAt
            ))
        }
    }

    private func upsert(_ payload: FoodItemSyncPayload, localFamilyId: String, modelContext: ModelContext) throws {
        let id = payload.id
        let existing = try fetchFoodItem(id: id, modelContext: modelContext)
        let category = try fetchFoodCategory(id: payload.categoryId, modelContext: modelContext)
        let unit = try fetchFoodUnit(id: payload.defaultUnitId, modelContext: modelContext)
        if let existing {
            existing.familyId = localFamilyId
            existing.name = payload.name
            existing.category = category
            existing.defaultUnit = unit
            existing.createdAt = payload.createdAt
            existing.updatedAt = payload.updatedAt
        } else {
            modelContext.insert(FoodItem(
                id: payload.id, familyId: localFamilyId, name: payload.name,
                category: category, defaultUnit: unit, createdAt: payload.createdAt, updatedAt: payload.updatedAt
            ))
        }
    }

    private func upsert(_ payload: DiaperChangeEventSyncPayload, modelContext: ModelContext) throws {
        let id = payload.id
        let existing = try fetchDiaperChangeEvent(id: id, modelContext: modelContext)
        let location = try fetchInventoryLocation(id: payload.inventoryLocationId, modelContext: modelContext)
        if let existing {
            existing.babyId = payload.babyId
            existing.date = payload.eventDate
            existing.location = location ?? existing.location
            existing.stockMovementId = payload.stockMovementId?.uuidString
            existing.peeLevelRaw = payload.peeLevel
            existing.poopLevelRaw = payload.poopLevel
            existing.notes = payload.notes
            existing.createdAt = payload.createdAt
        } else {
            modelContext.insert(DiaperChangeEvent(
                id: payload.id, babyId: payload.babyId, date: payload.eventDate, diaperSize: nil,
                location: location, stockMovementId: payload.stockMovementId?.uuidString,
                peeLevel: DiaperLevel(rawValue: payload.peeLevel) ?? .none,
                poopLevel: DiaperLevel(rawValue: payload.poopLevel) ?? .none,
                notes: payload.notes, createdAt: payload.createdAt
            ))
        }
    }

    private func upsert(_ payload: FeedingEventSyncPayload, modelContext: ModelContext) throws {
        let id = payload.id
        let existing = try fetchFeedingEvent(id: id, modelContext: modelContext)
        let item = try fetchFoodItem(id: payload.foodId, modelContext: modelContext)
        let quantity = NSDecimalNumber(decimal: payload.quantity).doubleValue
        if let existing {
            existing.babyId = payload.babyId
            existing.eventDate = payload.eventDate
            existing.foodName = item?.name ?? existing.foodName
            existing.foodCategoryName = item?.category?.name ?? existing.foodCategoryName
            existing.quantity = quantity
            existing.unitName = payload.unit
            existing.unitSymbol = payload.unit
            existing.notes = payload.notes
            existing.foodItem = item ?? existing.foodItem
            existing.createdAt = payload.createdAt
        } else {
            modelContext.insert(FeedingEvent(
                id: payload.id, babyId: payload.babyId, eventDate: payload.eventDate,
                foodName: item?.name ?? "Synced feeding", foodCategoryName: item?.category?.name,
                quantity: quantity, unitName: payload.unit, unitSymbol: payload.unit,
                notes: payload.notes, foodItem: item, createdAt: payload.createdAt
            ))
        }
    }

    private func deleteFoodCategory(id: UUID, localFamilyId: String, modelContext: ModelContext) throws {
        if let local = try fetchFoodCategory(id: id, modelContext: modelContext),
           local.familyId?.caseInsensitiveCompare(localFamilyId) == .orderedSame {
            modelContext.delete(local)
        }
    }

    private func deleteFoodUnit(id: UUID, localFamilyId: String, modelContext: ModelContext) throws {
        if let local = try fetchFoodUnit(id: id, modelContext: modelContext),
           local.familyId?.caseInsensitiveCompare(localFamilyId) == .orderedSame {
            modelContext.delete(local)
        }
    }

    private func deleteFoodItem(id: UUID, localFamilyId: String, modelContext: ModelContext) throws {
        if let local = try fetchFoodItem(id: id, modelContext: modelContext),
           local.familyId?.caseInsensitiveCompare(localFamilyId) == .orderedSame {
            modelContext.delete(local)
        }
    }

    private func deleteDiaperChangeEvent(id: UUID, babyId: UUID?, modelContext: ModelContext) throws {
        if let local = try fetchDiaperChangeEvent(id: id, modelContext: modelContext),
           babyId == nil || local.babyId == babyId {
            modelContext.delete(local)
        }
    }

    private func deleteFeedingEvent(id: UUID, babyId: UUID?, modelContext: ModelContext) throws {
        if let local = try fetchFeedingEvent(id: id, modelContext: modelContext),
           babyId == nil || local.babyId == babyId {
            modelContext.delete(local)
        }
    }

    private func fetchFoodCategory(id: UUID?, modelContext: ModelContext) throws -> FoodCategory? {
        guard let id else { return nil }
        return try modelContext.fetch(FetchDescriptor<FoodCategory>(
            predicate: #Predicate<FoodCategory> { entity in entity.id == id }
        )).first
    }

    private func fetchFoodUnit(id: UUID?, modelContext: ModelContext) throws -> FoodUnit? {
        guard let id else { return nil }
        return try modelContext.fetch(FetchDescriptor<FoodUnit>(
            predicate: #Predicate<FoodUnit> { entity in entity.id == id }
        )).first
    }

    private func fetchFoodItem(id: UUID?, modelContext: ModelContext) throws -> FoodItem? {
        guard let id else { return nil }
        return try modelContext.fetch(FetchDescriptor<FoodItem>(
            predicate: #Predicate<FoodItem> { entity in entity.id == id }
        )).first
    }

    private func fetchDiaperChangeEvent(id: UUID, modelContext: ModelContext) throws -> DiaperChangeEvent? {
        try modelContext.fetch(FetchDescriptor<DiaperChangeEvent>(
            predicate: #Predicate<DiaperChangeEvent> { entity in entity.id == id }
        )).first
    }

    private func fetchFeedingEvent(id: UUID, modelContext: ModelContext) throws -> FeedingEvent? {
        try modelContext.fetch(FetchDescriptor<FeedingEvent>(
            predicate: #Predicate<FeedingEvent> { entity in entity.id == id }
        )).first
    }

    private func fetchInventoryLocation(id: UUID?, modelContext: ModelContext) throws -> InventoryLocation? {
        guard let id else { return nil }
        return try modelContext.fetch(FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { entity in entity.id == id }
        )).first
    }

    private func decode<Payload: Decodable>(_ type: Payload.Type, from payloadJson: String) throws -> Payload {
        guard let data = payloadJson.data(using: .utf8) else { throw BimblyticsEventSyncError.invalidPayload }
        return try JSONDecoder.bimblyticsSync.decode(type, from: data)
    }

    private func remoteOrder(_ lhs: ServerSyncChangeResponse, _ rhs: ServerSyncChangeResponse) -> Bool {
        let lhsPriority = SyncEntityType(rawValue: lhs.entityType)?.sendPriority ?? 99
        let rhsPriority = SyncEntityType(rawValue: rhs.entityType)?.sendPriority ?? 99
        return lhsPriority < rhsPriority
    }
}

private struct DiaperChangeEventPushPayload: Encodable {
    let id: UUID; let familyId: UUID; let babyId: UUID; let eventDate: Date
    let diaperInventoryItemId: UUID?; let inventoryLocationId: UUID?; let stockMovementId: UUID?
    let peeLevel: Int; let poopLevel: Int; let notes: String?
    let createdAt: Date; let updatedAt: Date; let deletedAt: Date?
    let createdByUserId: UUID; let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID; let lastModifiedByDeviceId: UUID; let version: Int64
}

private struct FeedingEventPushPayload: Encodable {
    let id: UUID; let familyId: UUID; let babyId: UUID; let eventDate: Date
    let foodId: UUID?; let quantity: Double; let unit: String; let notes: String?
    let createdAt: Date; let updatedAt: Date; let deletedAt: Date?
    let createdByUserId: UUID; let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID; let lastModifiedByDeviceId: UUID; let version: Int64
}

private struct FoodCategoryPushPayload: Encodable {
    let id: UUID; let familyId: UUID; let name: String; let sortOrder: Int
    let isSystem: Bool; let isArchived: Bool; let createdAt: Date; let updatedAt: Date; let deletedAt: Date?
    let createdByUserId: UUID; let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID; let lastModifiedByDeviceId: UUID; let version: Int64
}

private struct FoodUnitPushPayload: Encodable {
    let id: UUID; let familyId: UUID; let name: String; let symbol: String; let sortOrder: Int
    let isSystem: Bool; let isArchived: Bool; let createdAt: Date; let updatedAt: Date; let deletedAt: Date?
    let createdByUserId: UUID; let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID; let lastModifiedByDeviceId: UUID; let version: Int64
}

private struct FoodItemPushPayload: Encodable {
    let id: UUID; let familyId: UUID; let name: String; let categoryId: UUID?; let defaultUnitId: UUID?
    let createdAt: Date; let updatedAt: Date; let deletedAt: Date?
    let createdByUserId: UUID; let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID; let lastModifiedByDeviceId: UUID; let version: Int64
}

private enum BimblyticsEventSyncError: Error {
    case invalidPayload
}
