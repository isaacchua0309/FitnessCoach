//
//  SettingsPrivacyDataTimestampFormatter.swift
//  Fitness Coach
//
//  Forma — Formats account/sync timestamps for Privacy & Data settings.
//

import Foundation

enum SettingsPrivacyDataTimestampFormatter {

    static let unavailable = FormaProductCopy.Settings.PrivacyData.timestampUnavailable

    static func format(
        _ date: Date?,
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        guard let date else { return unavailable }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = timeZone

        if calendar.isDateInToday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        }

        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
