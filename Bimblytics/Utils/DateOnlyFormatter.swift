//
//  DateOnlyFormatter.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 10/05/2026.
//

import Foundation

extension Date {
    var formattedAsDateOnly: String {
        DateOnlyFormatter.string(from: self)
    }
}

enum DateOnlyFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from value: String) -> Date? {
        formatter.date(from: value)
    }
}
