//
//  SyncedFamilyLocalStore.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 12/05/2026.
//

import Foundation
import SwiftData

@MainActor
final class SyncedFamilyLocalStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func saveFamilies(_ families: [BimblyticsFamily]) throws {
        for family in families {
            try upsertFamily(family)
        }

        try modelContext.save()
    }

    func saveFamily(_ family: BimblyticsFamily, linkedBabyIds: Set<UUID>) throws {
        try upsertFamily(family)

        for babyId in linkedBabyIds {
            try upsertBabyLink(familyId: family.id, babyId: babyId)
        }

        try modelContext.save()
    }

    private func upsertFamily(_ family: BimblyticsFamily) throws {
        let familyId = family.id

        let descriptor = FetchDescriptor<SyncedFamily>(
            predicate: #Predicate { $0.familyId == familyId }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = family.name
            existing.syncedAt = .now
        } else {
            modelContext.insert(SyncedFamily(
                familyId: family.id,
                name: family.name
            ))
        }
    }

    private func upsertBabyLink(familyId: String, babyId: UUID) throws {
        let linkId = "\(familyId)-\(babyId.uuidString)"

        let descriptor = FetchDescriptor<SyncedFamilyBabyLink>(
            predicate: #Predicate { $0.id == linkId }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.syncedAt = .now
        } else {
            modelContext.insert(SyncedFamilyBabyLink(
                familyId: familyId,
                babyId: babyId
            ))
        }
    }
}
