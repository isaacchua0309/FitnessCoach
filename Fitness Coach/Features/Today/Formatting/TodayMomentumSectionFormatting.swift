//
//  TodayMomentumSectionFormatting.swift
//  Fitness Coach
//
//  Forma — Display formatting for Today's Momentum accountability card.
//

import Foundation

struct TodayMomentumSectionDisplayModel: Equatable {
    var loggingStreakLine: String
    var weekProgressLine: String
    var optionalStreakLines: [String]
    var accessibilitySummary: String
}

enum TodayMomentumSectionFormatting {

    static func displayModel(for momentum: TodayMomentumState) -> TodayMomentumSectionDisplayModel {
        let loggingStreakLine = loggingStreakLine(for: momentum.streaks.loggingStreak)
        let weekProgressLine = FormaProductCopy.Today.Momentum.weekProgressLine(
            loggedDays: momentum.weekLoggedDays,
            totalDays: TodayMomentumState.weekTotalDays
        )
        let optionalStreakLines = optionalStreakLines(for: momentum.streaks)

        var summaryParts = [
            FormaProductCopy.Today.Momentum.sectionTitle,
            loggingStreakLine,
            weekProgressLine
        ]
        summaryParts.append(contentsOf: optionalStreakLines)

        return TodayMomentumSectionDisplayModel(
            loggingStreakLine: loggingStreakLine,
            weekProgressLine: weekProgressLine,
            optionalStreakLines: optionalStreakLines,
            accessibilitySummary: summaryParts.joined(separator: ". ")
        )
    }

    static func loggingStreakLine(for streakDays: Int) -> String {
        guard streakDays > 0 else {
            return FormaProductCopy.Today.Momentum.startStreakToday
        }
        return FormaProductCopy.Today.Momentum.loggingStreakLine(days: streakDays)
    }

    static func optionalStreakLines(for streaks: StreakSummary) -> [String] {
        var lines: [String] = []
        if streaks.proteinStreak > 0 {
            lines.append(
                FormaProductCopy.Today.Momentum.proteinStreakLine(days: streaks.proteinStreak)
            )
        }
        if streaks.hydrationStreak > 0 {
            lines.append(
                FormaProductCopy.Today.Momentum.waterStreakLine(days: streaks.hydrationStreak)
            )
        }
        return lines
    }
}
