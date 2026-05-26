//
//  SyncOutboxChange.swift
//  Bimblytics
//
//  Created by Codex on 26/05/2026.
//

import Foundation
import SwiftData

@Model
final class SyncOutboxChange {
    @Attribute(.unique) var key: String
    var familyId: String
    var entityType: String
    var entityId: UUID
    var operationRawValue: Int
    var changedAt: Date
    var payloadJson: String

    init(
        familyId: String,
        entityType: SyncEntityType,
        entityId: UUID,
        operation: SyncOperation,
        changedAt: Date,
        payloadJson: String
    ) {
        self.key = Self.key(familyId: familyId, entityType: entityType, entityId: entityId)
        self.familyId = familyId
        self.entityType = entityType.rawValue
        self.entityId = entityId
        self.operationRawValue = operation.rawValue
        self.changedAt = changedAt
        self.payloadJson = payloadJson
    }

    var operation: SyncOperation? {
        SyncOperation(rawValue: operationRawValue)
    }

    static func key(familyId: String, entityType: SyncEntityType, entityId: UUID) -> String {
        "\(familyId.lowercased())|\(entityType.rawValue)|\(entityId.uuidString.lowercased())"
    }
}

enum SyncEntityType: String {
    case foodCategory = "FoodCategory"
    case foodUnit = "FoodUnit"
    case foodItem = "FoodItem"
    case diaperChangeEvent = "DiaperChangeEvent"
    case feedingEvent = "FeedingEvent"

    var sendPriority: Int {
        switch self {
        case .foodCategory:
            return 0
        case .foodUnit:
            return 1
        case .foodItem:
            return 2
        case .diaperChangeEvent, .feedingEvent:
            return 3
        }
    }
}

struct SentOutboxSnapshot {
    let key: String
    let changedAt: Date
    let operationRawValue: Int
    let payloadJson: String
}

@MainActor
enum SyncOutboxStore {
    static func enqueue(
        _ change: ClientSyncChangeRequest,
        familyId: String,
        modelContext: ModelContext
    ) throws {
        guard let entityType = SyncEntityType(rawValue: change.entityType) else {
            return
        }

        let key = SyncOutboxChange.key(
            familyId: familyId,
            entityType: entityType,
            entityId: change.entityId
        )
        let descriptor = FetchDescriptor<SyncOutboxChange>(
            predicate: #Predicate<SyncOutboxChange> { entry in
                entry.key == key
            }
        )

        if let entry = try modelContext.fetch(descriptor).first {
            entry.familyId = familyId
            entry.entityType = entityType.rawValue
            entry.entityId = change.entityId
            entry.operationRawValue = change.operation.rawValue
            entry.changedAt = change.changedAt
            entry.payloadJson = change.payloadJson
        } else {
            modelContext.insert(SyncOutboxChange(
                familyId: familyId,
                entityType: entityType,
                entityId: change.entityId,
                operation: change.operation,
                changedAt: change.changedAt,
                payloadJson: change.payloadJson
            ))
        }

        try modelContext.save()
    }

    static func pending(
        familyId: String,
        modelContext: ModelContext
    ) throws -> [SyncOutboxChange] {
        try modelContext.fetch(FetchDescriptor<SyncOutboxChange>()).filter { entry in
            entry.familyId.caseInsensitiveCompare(familyId) == .orderedSame
        }
    }

    static func hasPending(
        familyId: String,
        entityType: SyncEntityType,
        entityId: UUID,
        modelContext: ModelContext
    ) throws -> Bool {
        let key = SyncOutboxChange.key(
            familyId: familyId,
            entityType: entityType,
            entityId: entityId
        )
        let descriptor = FetchDescriptor<SyncOutboxChange>(
            predicate: #Predicate<SyncOutboxChange> { entry in
                entry.key == key
            }
        )
        return try modelContext.fetch(descriptor).first != nil
    }

    static func removeAccepted(
        _ snapshots: [SentOutboxSnapshot],
        modelContext: ModelContext
    ) throws {
        for snapshot in snapshots {
            let key = snapshot.key
            let descriptor = FetchDescriptor<SyncOutboxChange>(
                predicate: #Predicate<SyncOutboxChange> { entry in
                    entry.key == key
                }
            )

            guard let entry = try modelContext.fetch(descriptor).first,
                  entry.changedAt == snapshot.changedAt,
                  entry.operationRawValue == snapshot.operationRawValue,
                  entry.payloadJson == snapshot.payloadJson else {
                continue
            }

            modelContext.delete(entry)
        }

        try modelContext.save()
    }
}
