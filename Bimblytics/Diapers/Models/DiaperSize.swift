//
//  DiaperSize.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation
import SwiftData

@Model
final class DiaperSize {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var remoteId: String?

    var code: String
    var descriptionText: String?
    var sizeRange: String
    var remoteUpdatedAt: Date?
    var source: DiaperSource.RawValue

    var model: DiaperModel?

    @Relationship(deleteRule: .nullify, inverse: \DiaperInventoryItem.diaperSize)
    var inventoryItems: [DiaperInventoryItem] = []

    init(
        id: UUID = UUID(),
        remoteId: String? = nil,
        code: String,
        descriptionText: String? = nil,
        sizeRange: String,
        remoteUpdatedAt: Date? = nil,
        source: DiaperSource,
        model: DiaperModel? = nil
    ) {
        self.id = id
        self.remoteId = remoteId
        self.code = code
        self.descriptionText = descriptionText
        self.sizeRange = sizeRange
        self.remoteUpdatedAt = remoteUpdatedAt
        self.source = source.rawValue
        self.model = model
    }

    var sourceEnum: DiaperSource {
        get { DiaperSource(rawValue: source) ?? .userCustom }
        set { source = newValue.rawValue }
    }

    var displayName: String {
        if let descriptionText, !descriptionText.isEmpty {
            return "\(code) - \(descriptionText)"
        }

        return code
    }
}
