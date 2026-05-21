//
//  BimblyticsDeviceIdentifier.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 10/05/2026.
//

import Foundation

enum BimblyticsDeviceIdentifier {
    private static let userDefaultsKey = "bimblytics.deviceId"

    static var current: UUID {
        if let value = UserDefaults.standard.string(forKey: userDefaultsKey),
           let uuid = UUID(uuidString: value) {
            return uuid
        }

        let uuid = UUID()
        UserDefaults.standard.set(uuid.uuidString, forKey: userDefaultsKey)
        return uuid
    }
}
