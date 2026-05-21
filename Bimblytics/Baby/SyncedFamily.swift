//
//  SyncedFamily.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 12/05/2026.
//

import Foundation
import SwiftData

@Model
final class SyncedFamily {
    @Attribute(.unique) var familyId: String
    var name: String
    var syncedAt: Date

    @Relationship(deleteRule: .cascade)
    var babyLinks: [SyncedFamilyBabyLink] = []

    init(familyId: String, name: String, syncedAt: Date = .now) {
        self.familyId = familyId
        self.name = name
        self.syncedAt = syncedAt
    }
}

@Model
final class SyncedFamilyBabyLink {
    @Attribute(.unique) var id: String
    var familyId: String
    var babyId: UUID
    var syncedAt: Date

    init(familyId: String, babyId: UUID, syncedAt: Date = .now) {
        self.id = "\(familyId)-\(babyId.uuidString)"
        self.familyId = familyId
        self.babyId = babyId
        self.syncedAt = syncedAt
    }
}
