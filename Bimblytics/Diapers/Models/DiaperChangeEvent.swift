//
//  DiaperBrand.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 16/04/2026.
//

import Foundation
import SwiftData

@Model
final class DiaperChangeEvent {
    @Attribute(.unique)
    var id: UUID

    var babyId: UUID
    var date: Date

    // Relations
    var diaperSize: DiaperSize?
    var location: InventoryLocation?

    // Linked stock movement
    var stockMovementId: PersistentIdentifier?

    // Levels (0–4)
    var peeLevelRaw: Int
    var poopLevelRaw: Int

    var notes: String?

    var createdAt: Date

    init(
        babyId: UUID,
        date: Date,
        diaperSize: DiaperSize?,
        location: InventoryLocation?,
        stockMovementId: PersistentIdentifier? = nil,
        peeLevel: DiaperLevel,
        poopLevel: DiaperLevel,
        notes: String?
    ) {
        self.id = UUID()
        self.babyId = babyId
        self.date = date
        self.diaperSize = diaperSize
        self.location = location
        self.stockMovementId = stockMovementId
        self.peeLevelRaw = peeLevel.rawValue
        self.poopLevelRaw = poopLevel.rawValue
        self.notes = notes
        self.createdAt = .now
    }
}

enum DiaperLevel: Int, CaseIterable, Identifiable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case veryHigh = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: return "0"
        case .low: return "1"
        case .medium: return "2"
        case .high: return "3"
        case .veryHigh: return "4"
        }
    }

    var description: String {
        switch self {
        case .none: return "None"
        case .low: return "Light"
        case .medium: return "Medium"
        case .high: return "Heavy"
        case .veryHigh: return "Very heavy"
        }
    }
}
