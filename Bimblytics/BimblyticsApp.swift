//
//  BimblyticsApp.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 03/04/2026.
//

import SwiftUI
import SwiftData

@main
struct BimblyticsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(AppColors.primary)
        }
        .modelContainer(for: [
            Baby.self,
            DiaperBrand.self,
            DiaperModel.self,
            DiaperSize.self,
            InventoryLocation.self,
            DiaperInventoryItem.self,
            DiaperStockMovement.self,
            FeedingEvent.self,
            FoodCategory.self,
            FoodItem.self,
            FoodUnit.self
        ])
    }
}
