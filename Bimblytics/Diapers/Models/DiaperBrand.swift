//
//  DiaperBrand.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import Foundation
import SwiftData

@Model
final class DiaperBrand {
    @Attribute(.unique) var id: UUID

    /// Backend identifier
    @Attribute(.unique) var remoteId: String?

    var name: String
    var countryCode: String
    var source: DiaperSource.RawValue

    @Relationship(deleteRule: .cascade, inverse: \DiaperModel.brand)
    var models: [DiaperModel] = []

    init(
        id: UUID = UUID(),
        remoteId: String? = nil,
        name: String,
        countryCode: String,
        source: DiaperSource
    ) {
        self.id = id
        self.remoteId = remoteId
        self.name = name
        self.countryCode = countryCode
        self.source = source.rawValue
    }

    var sourceEnum: DiaperSource {
        get { DiaperSource(rawValue: source) ?? .userCustom }
        set { source = newValue.rawValue }
    }
}
