//
//  DiaperInventoryPreviewData.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation
import SwiftData

enum DiaperInventoryPreviewData {
    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            DiaperBrand.self,
            DiaperModel.self,
            DiaperSize.self,
            InventoryLocation.self,
            DiaperInventoryItem.self,
            DiaperStockMovement.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )

            seed(container.mainContext)

            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }

    @MainActor
    static func seed(_ context: ModelContext) {
        let home = InventoryLocation(
            name: "Home",
            notes: "Main nursery closet",
            sortOrder: 0,
            isDefault: true,
            isArchived: false
        )

        let bag = InventoryLocation(
            name: "Outing bag",
            notes: "Diaper bag for quick trips",
            sortOrder: 1,
            isDefault: false,
            isArchived: false
        )

        let secondHome = InventoryLocation(
            name: "Second home",
            notes: "Weekend house",
            sortOrder: 2,
            isDefault: false,
            isArchived: false
        )

        context.insert(home)
        context.insert(bag)
        context.insert(secondHome)

        let pampers = DiaperBrand(
            remoteId: "8c2b50b6-a032-4756-bfa8-d562aed99fe7",
            name: "Pampers",
            countryCode: "IT",
            source: .remoteCatalog
        )

        let huggies = DiaperBrand(
            remoteId: "80449d28-c230-40d7-8e36-41222c171148",
            name: "Huggies",
            countryCode: "IT",
            source: .remoteCatalog
        )

        context.insert(pampers)
        context.insert(huggies)

        let progressi = DiaperModel(
            remoteId: "16295ea0-b86c-4f54-b69b-bf89c0348ed5",
            name: "Progressi",
            type: .disposable,
            ageCategory: .child,
            source: .remoteCatalog,
            brand: pampers
        )

        let babyDry = DiaperModel(
            remoteId: "90000fc0-de6d-4cda-a04e-6fa6b61619c7",
            name: "Baby Dry",
            type: .disposable,
            ageCategory: .child,
            source: .remoteCatalog,
            brand: pampers
        )

        let littleSwimmers = DiaperModel(
            remoteId: "02773107-c39a-4b4a-8e53-7e28b3cf6d35",
            name: "Little Swimmers",
            type: .swimDisposable,
            ageCategory: .child,
            source: .remoteCatalog,
            brand: huggies
        )

        context.insert(progressi)
        context.insert(babyDry)
        context.insert(littleSwimmers)

        let progressiSize3 = DiaperSize(
            remoteId: "30f8cd36-ae52-440c-be38-fea7b8cbcc93",
            code: "3",
            descriptionText: "Midi",
            sizeRange: "4 - 9 kg",
            remoteUpdatedAt: ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+00:00"),
            source: .remoteCatalog,
            model: progressi
        )

        let progressiSize4 = DiaperSize(
            remoteId: "95ea325e-8067-4218-90a5-2476e9b3db6b",
            code: "4",
            descriptionText: "Maxi",
            sizeRange: "7 - 18 kg",
            remoteUpdatedAt: ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+00:00"),
            source: .remoteCatalog,
            model: progressi
        )

        let progressiSize5 = DiaperSize(
            remoteId: "7840ba79-4d5e-41e8-b746-fe105ce9aaa7",
            code: "5",
            descriptionText: "Junior",
            sizeRange: "11 - 25 kg",
            remoteUpdatedAt: ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+00:00"),
            source: .remoteCatalog,
            model: progressi
        )

        let progressiSize6 = DiaperSize(
            remoteId: "bee32e18-2b86-4719-871f-a857318290a8",
            code: "6",
            descriptionText: "Large",
            sizeRange: "16+ kg",
            remoteUpdatedAt: ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+00:00"),
            source: .remoteCatalog,
            model: progressi
        )

        let babyDrySize4 = DiaperSize(
            remoteId: "77ed58bf-746e-4c57-867b-0872ed57ba2c",
            code: "4",
            descriptionText: "Maxi",
            sizeRange: "7 - 18 kg",
            remoteUpdatedAt: ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+00:00"),
            source: .remoteCatalog,
            model: babyDry
        )

        let swimmersSize2 = DiaperSize(
            remoteId: "3cb54865-c141-453f-95d0-ba530b68059b",
            code: "2",
            descriptionText: nil,
            sizeRange: "3 - 6 kg",
            remoteUpdatedAt: ISO8601DateFormatter().date(from: "2026-04-01T00:00:00+00:00"),
            source: .remoteCatalog,
            model: littleSwimmers
        )

        context.insert(progressiSize3)
        context.insert(progressiSize4)
        context.insert(progressiSize5)
        context.insert(progressiSize6)
        context.insert(babyDrySize4)
        context.insert(swimmersSize2)

        let homeProgressi = DiaperInventoryItem(
            quantityOnHand: 42,
            lowStockThreshold: 10,
            packageQuantity: 24,
            notes: "Main stock",
            diaperSize: progressiSize3,
            location: home
        )

        let homeBabyDry = DiaperInventoryItem(
            quantityOnHand: 7,
            lowStockThreshold: 8,
            packageQuantity: 20,
            notes: "Reserve pack",
            diaperSize: babyDrySize4,
            location: home
        )

        let bagProgressi = DiaperInventoryItem(
            quantityOnHand: 5,
            lowStockThreshold: 4,
            packageQuantity: nil,
            notes: "Keep ready for quick outings",
            diaperSize: progressiSize3,
            location: bag
        )

        let secondHomeSwimmers = DiaperInventoryItem(
            quantityOnHand: 0,
            lowStockThreshold: 2,
            packageQuantity: 12,
            notes: "Summer stock",
            diaperSize: swimmersSize2,
            location: secondHome
        )

        context.insert(homeProgressi)
        context.insert(homeBabyDry)
        context.insert(bagProgressi)
        context.insert(secondHomeSwimmers)

        let movements: [DiaperStockMovement] = [
            DiaperStockMovement(
                type: .purchase,
                quantityDelta: 24,
                resultingQuantity: 24,
                note: "Bought a new pack",
                reference: "Preview-001",
                inventoryItem: homeProgressi
            ),
            DiaperStockMovement(
                type: .manualLoad,
                quantityDelta: 18,
                resultingQuantity: 42,
                note: "Merged remaining stock",
                reference: "Preview-002",
                inventoryItem: homeProgressi
            ),
            DiaperStockMovement(
                type: .consumption,
                quantityDelta: -1,
                resultingQuantity: 7,
                note: "Recent diaper change",
                reference: "Preview-003",
                inventoryItem: homeBabyDry
            ),
            DiaperStockMovement(
                type: .transferIn,
                quantityDelta: 5,
                resultingQuantity: 5,
                note: "Prepared the outing bag",
                reference: "Preview-004",
                inventoryItem: bagProgressi
            ),
            DiaperStockMovement(
                type: .consumption,
                quantityDelta: -2,
                resultingQuantity: 0,
                note: "Used during last trip",
                reference: "Preview-005",
                inventoryItem: secondHomeSwimmers
            )
        ]

        for movement in movements {
            context.insert(movement)
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed preview data: \(error)")
        }
    }
}
