//
//  DiaperStockMovementType.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation

enum DiaperStockMovementType: String, Codable, CaseIterable {
    case purchase
    case manualLoad
    case consumption
    case correction
    case discard
    case transferIn
    case transferOut
}
