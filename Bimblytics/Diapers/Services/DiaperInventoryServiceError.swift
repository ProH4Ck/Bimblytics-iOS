//
//  DiaperInventoryServiceError.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation

enum DiaperInventoryServiceError: LocalizedError {
    case invalidQuantity
    case insufficientStock(available: Int, requested: Int)
    case negativeStockNotAllowed
    case sameSourceAndDestinationLocation
    case noChangeRequired

    var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            return "The quantity must be greater than zero."

        case let .insufficientStock(available, requested):
            return "Insufficient stock. Available: \(available), requested: \(requested)."

        case .negativeStockNotAllowed:
            return "Stock cannot become negative."

        case .sameSourceAndDestinationLocation:
            return "Source and destination locations must be different."

        case .noChangeRequired:
            return "The new quantity is the same as the current quantity."
        }
    }
}
