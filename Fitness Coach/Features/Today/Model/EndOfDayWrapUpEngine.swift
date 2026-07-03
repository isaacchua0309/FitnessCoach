//
//  EndOfDayWrapUpEngine.swift
//  Fitness Coach
//
//  Deterministic end-of-day wrap-up for Today (no AI).
//

import Foundation

enum TodayEndOfDayOverallTone: Equatable, Sendable {
    case greatWork
    case goodStart
    case stillTime
}

enum TodayEndOfDayRowStatus: Equatable, Sendable {
    case complete
    case partial
    case notLogged
    case overTarget
}

struct TodayEndOfDayRowState: Equatable {
    var label: String
    var valueText: String
    var status: TodayEndOfDayRowStatus
}

struct EndOfDayWrapUpInput: Equatable {
    var date: Date
    var calendar: Calendar
    var foodEntries: [FoodEntry]
    var calorieSummary: CalorieSummary
    var proteinProgress: MacroProgress
    var waterSummary: WaterSummary
    var workoutSummary: TodayWorkoutSummary
    var activityContext: TodayActivityContext
    var weightLoggedToday: Bool
}

enum EndOfDayWrapUpEngine {

    static let eveningStartHour = TodayPresentationBuilder.endOfDayStartHour
    static let goodStartCalorieProgressThreshold = 0.45

    static func resolve(_ input: EndOfDayWrapUpInput) -> TodayEndOfDayState {
        guard isEvening(input) else {
            return .hidden
        }

        let hasAnyLog = hasAnyLog(input)
        let rows = hasAnyLog ? EndOfDayWrapUpFormatting.rows(for: input) : []
        let overallTone = hasAnyLog ? overallTone(for: input) : nil

        return TodayEndOfDayState(
            isVisible: true,
            sectionTitle: FormaProductCopy.Today.EndOfDay.sectionTitle,
            overallMessage: overallTone.map(overallMessage(for:)),
            noLogsMessage: hasAnyLog ? nil : FormaProductCopy.Today.EndOfDay.noLogsMessage,
            rows: rows,
            journeyActionTitle: FormaProductCopy.Today.EndOfDay.seeJourneyAction,
            journeyActionHint: FormaProductCopy.Today.EndOfDay.seeJourneyHint,
            accessibilityLabel: accessibilityLabel(
                hasAnyLog: hasAnyLog,
                overallMessage: overallTone.map(overallMessage(for:)),
                noLogsMessage: hasAnyLog ? nil : FormaProductCopy.Today.EndOfDay.noLogsMessage,
                rows: rows
            )
        )
    }

    static func isEvening(_ input: EndOfDayWrapUpInput) -> Bool {
        input.calendar.component(.hour, from: input.date) >= eveningStartHour
    }

    static func hasAnyLog(_ input: EndOfDayWrapUpInput) -> Bool {
        !input.foodEntries.isEmpty
            || input.waterSummary.consumedMl > 0
            || hasWorkoutToday(input)
            || input.weightLoggedToday
    }

    static func overallTone(for input: EndOfDayWrapUpInput) -> TodayEndOfDayOverallTone {
        if isGreatWorkDay(input) {
            return .greatWork
        }
        if isGoodStartDay(input) {
            return .goodStart
        }
        return .stillTime
    }

    static func isGreatWorkDay(_ input: EndOfDayWrapUpInput) -> Bool {
        guard !input.foodEntries.isEmpty else { return false }
        guard !input.calorieSummary.isOverTarget else { return false }

        let proteinOnTrack = input.proteinProgress.progress >= TodayFocusBuilder.proteinOnTrackThreshold
        let waterOnTrack = input.waterSummary.progress >= TodayFocusBuilder.waterOnTrackThreshold

        return proteinOnTrack && waterOnTrack
    }

    static func isGoodStartDay(_ input: EndOfDayWrapUpInput) -> Bool {
        let earlyCalories = input.calorieSummary.target > 0
            && input.calorieSummary.progress < goodStartCalorieProgressThreshold
        let firstLog = input.foodEntries.count == 1

        return earlyCalories || firstLog
    }

    static func hasWorkoutToday(_ input: EndOfDayWrapUpInput) -> Bool {
        input.workoutSummary.hasWorkout || (input.activityContext.appleHealthWorkoutCount ?? 0) > 0
    }

    private static func overallMessage(for tone: TodayEndOfDayOverallTone) -> String {
        switch tone {
        case .greatWork:
            return FormaProductCopy.Today.EndOfDay.overallGreatWork
        case .goodStart:
            return FormaProductCopy.Today.EndOfDay.overallGoodStart
        case .stillTime:
            return FormaProductCopy.Today.EndOfDay.overallStillTime
        }
    }

    private static func accessibilityLabel(
        hasAnyLog: Bool,
        overallMessage: String?,
        noLogsMessage: String?,
        rows: [TodayEndOfDayRowState]
    ) -> String {
        var parts = [FormaProductCopy.Today.EndOfDay.sectionTitle]
        if let noLogsMessage {
            parts.append(noLogsMessage)
        } else if let overallMessage {
            parts.append(overallMessage)
        }
        parts.append(contentsOf: rows.map { "\($0.label). \($0.valueText)" })
        parts.append(FormaProductCopy.Today.EndOfDay.seeJourneyAction)
        return parts.joined(separator: ". ")
    }
}
