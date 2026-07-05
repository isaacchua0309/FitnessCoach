//
//  TodayDashboardHeaderFormatting.swift
//  Fitness Coach
//
//  Forma — Header date formatting for Today.
//

import Foundation

enum TodayDashboardHeaderFormatting {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return formatter
    }()

    static func dateLine(for date: Date, calendar: Calendar = .current) -> String {
        dateFormatter.calendar = calendar
        return dateFormatter.string(from: date)
    }

    static func planStatusChip(for status: TodayMissionStatus) -> String? {
        switch status {
        case .onTrack:
            return nil
        case .needsFocus:
            return FormaProductCopy.Today.Header.planStatusNeedsFocus
        case .overBudget:
            return FormaProductCopy.Today.Header.planStatusOverTarget
        }
    }
}
