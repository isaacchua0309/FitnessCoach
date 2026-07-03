//
//  CoachTodaySyncDebugLogger.swift
//  Fitness Coach
//
//  OSLog tracing for Coach meal save → Today dashboard refresh (release-safe).
//

import Foundation
import OSLog

enum CoachTodaySyncDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "CoachTodaySync")

    nonisolated static func coachMealSaved(
        entryId: UUID,
        name: String,
        calories: Int,
        protein: Double,
        mealType: String,
        refreshToken: Int
    ) {
        emit(
            message: "coach_meal_saved",
            fields: [
                "entryId": entryId.uuidString,
                "name": name,
                "calories": String(calories),
                "protein": String(format: "%.1f", protein),
                "mealType": mealType,
                "refreshToken": String(refreshToken)
            ]
        )
    }

    nonisolated static func todayRefreshTriggered(source: String, refreshToken: Int) {
        emit(
            message: "today_refresh_triggered",
            fields: [
                "source": source,
                "refreshToken": String(refreshToken)
            ]
        )
    }

    nonisolated static func todayRefreshApplied(
        source: String,
        refreshToken: Int,
        consumedCalories: Int,
        remainingCalories: Int,
        proteinRemaining: Double,
        mealCount: Int,
        nextBestActionReason: String
    ) {
        emit(
            message: "today_refresh_applied",
            fields: [
                "source": source,
                "refreshToken": String(refreshToken),
                "consumedCalories": String(consumedCalories),
                "remainingCalories": String(remainingCalories),
                "proteinRemaining": String(format: "%.1f", proteinRemaining),
                "mealCount": String(mealCount),
                "nextBestActionReason": nextBestActionReason
            ]
        )
    }

    nonisolated static func todayRefreshApplied(
        source: String,
        refreshToken: Int,
        state: TodayDashboardState
    ) {
        todayRefreshApplied(
            source: source,
            refreshToken: refreshToken,
            consumedCalories: state.mission.calorieSummary.consumed,
            remainingCalories: state.mission.calorieSummary.remaining,
            proteinRemaining: state.macroHydration.macroSummary.protein.remaining,
            mealCount: state.meals.entryCount,
            nextBestActionReason: String(describing: state.nextBestAction.reason)
        )
    }

    #if DEBUG
    nonisolated static var isVerboseEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_COACH_TODAY_SYNC_TRACE"] != "0"
    }
    #else
    nonisolated static var isVerboseEnabled: Bool { true }
    #endif

    nonisolated private static func emit(message: String, fields: [String: String]) {
        guard isVerboseEnabled else { return }

        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[CoachTodaySync] \(message)"
            : "[CoachTodaySync] \(message) \(fieldLine)"

        logger.log(level: .info, "\(line, privacy: .public)")
    }
}
