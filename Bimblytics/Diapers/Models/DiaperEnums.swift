//
//  DiaperEnums.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation

enum DiaperType: String, Codable, CaseIterable {
    case disposable = "Disposable"
    case swimDisposable = "SwimDisposable"
    case cloth = "Cloth"
    case swimCloth = "SwimCloth"
    case unknown = "Unknown"
}

enum DiaperAgeCategory: String, Codable, CaseIterable {
    case child = "Child"
    case adult = "Adult"
    case unknown = "Unknown"
}

enum DiaperSource: String, Codable, CaseIterable {
    case remoteCatalog
    case userCustom
}
