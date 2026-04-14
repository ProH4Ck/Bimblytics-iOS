//
//  PreviewData.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 11/04/2026.
//

import Foundation
import SwiftData

enum PreviewData {
    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Baby.self
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
        let baby1 = Baby(
            name: "Adele",
            birthDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            gender: .female,
            diaperEnabled: true
        )

        let baby2 = Baby(
            name: "Emanuele",
            birthDate: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(),
            gender: .male,
            diaperEnabled: true
        )

        context.insert(baby1)
        context.insert(baby2)

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed preview data: \(error)")
        }
    }
}
