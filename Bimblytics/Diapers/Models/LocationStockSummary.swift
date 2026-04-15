//
//  LocationStockSummary.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation

struct LocationStockSummary: Identifiable {
    let id: UUID = UUID()
    let locationName: String
    let quantity: Int
}
