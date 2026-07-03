//
//  TodayActivitySectionFormatting.swift
//  Fitness Coach
//
//  Forma — Compact display formatting for the Today activity section.
//

import Foundation

enum TodayActivityWorkoutStatus: Equatable {
    case completed
    case planned
    case notLogged
}

struct TodayActivityCompactDisplayModel: Equatable {
    var stepsLine: String
    var workoutLine: String
    var healthNote: String?
    var healthActionTitle: String?
    var accessibilitySummary: String
}

enum TodayActivitySectionFormatting {

    private static let stepFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func displayModel(for activity: ActivityTodayState) -> TodayActivityCompactDisplayModel {
        let stepsLine = stepsLine(
            stepsToday: activity.stepsToday,
            stepGoalAssumption: activity.stepGoalAssumption
        )
        let workoutStatus = workoutStatus(for: activity)
        let workoutLine = workoutLine(for: workoutStatus)
        let health = healthConnection(for: activity)

        return TodayActivityCompactDisplayModel(
            stepsLine: stepsLine,
            workoutLine: workoutLine,
            healthNote: health?.note,
            healthActionTitle: health?.actionTitle,
            accessibilitySummary: [
                FormaProductCopy.Today.Activity.sectionTitle,
                stepsLine,
                workoutLine,
                health?.note
            ].compactMap { $0 }.joined(separator: ". ")
        )
    }

    static func stepsLine(stepsToday: Int?, stepGoalAssumption: Int?) -> String {
        guard let stepsToday else {
            return FormaProductCopy.Today.Activity.stepsUnavailable
        }

        if let goal = stepGoalAssumption, goal > 0 {
            return FormaProductCopy.Today.Activity.stepsProgress(
                current: stepsToday,
                goal: goal
            )
        }

        return FormaProductCopy.Today.Activity.stepsToday(stepsToday)
    }

    static func workoutStatus(for activity: ActivityTodayState) -> TodayActivityWorkoutStatus {
        if activity.hasWorkout {
            return .completed
        }

        if shouldShowPlannedWorkout(for: activity) {
            return .planned
        }

        return .notLogged
    }

    static func workoutLine(for status: TodayActivityWorkoutStatus) -> String {
        switch status {
        case .completed:
            return FormaProductCopy.Today.Activity.workoutCompletedLine
        case .planned:
            return FormaProductCopy.Today.Activity.workoutPlannedLine
        case .notLogged:
            return FormaProductCopy.Today.Activity.workoutNotLoggedLine
        }
    }

    static func shouldShowPlannedWorkout(for activity: ActivityTodayState) -> Bool {
        guard activity.trainingFrequencyPerWeek > 0 else { return false }
        guard !isDisconnected(activity) else { return false }

        switch activity.trainingDataSource {
        case .appleHealth:
            return NextBestActionEngine.isLikelyTrainingDay(
                frequency: activity.trainingFrequencyPerWeek,
                date: activity.date,
                calendar: .current
            )
        case .unavailable:
            return false
        }
    }

    static func isDisconnected(_ activity: ActivityTodayState) -> Bool {
        activity.trainingDataSource == .appleHealth && activity.showsConnectCTA
    }

    static func formatSteps(_ value: Int) -> String {
        stepFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func healthConnection(
        for activity: ActivityTodayState
    ) -> (note: String, actionTitle: String?)? {
        switch activity.trainingDataSource {
        case .unavailable:
            return (FormaProductCopy.Today.Activity.healthUnavailableNote, nil)
        case .appleHealth:
            guard isDisconnected(activity) else { return nil }

            switch activity.trainingIntegration {
            case .denied, .failed:
                return (
                    FormaProductCopy.Today.Activity.healthDeniedNote,
                    FormaProductCopy.Today.actionManageHealthAccess
                )
            case .notConnected, .unavailable, .requestingPermission, .connected:
                return (
                    FormaProductCopy.Today.Activity.healthConnectNote,
                    FormaProductCopy.Training.Integration.connectAppleHealth
                )
            }
        }
    }
}

// MARK: - Legacy presentation aliases

enum TodayActivitySectionPresentation: Equatable {
    case compact(TodayActivityCompactDisplayModel)
}

typealias TodayActivityConnectedDisplayModel = TodayActivityCompactDisplayModel
typealias TodayActivityDisconnectedDisplayModel = TodayActivityCompactDisplayModel
