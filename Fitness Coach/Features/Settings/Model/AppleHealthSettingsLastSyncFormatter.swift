//
//  AppleHealthSettingsLastSyncFormatter.swift
//  Fitness Coach
//
//  Forma — Formats Apple Health last-sync timestamps for Settings.
//

import Foundation

enum AppleHealthSettingsLastSyncFormatter {

    static func format(
        _ date: Date,
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
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
