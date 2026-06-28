//
//  TodayActivitySectionFormatting.swift
//  Fitness Coach
//
//  Forma — Display formatting for the Today activity section.
//

import Foundation

enum TodayActivitySectionPresentation: Equatable {
    case disconnected(TodayActivityDisconnectedDisplayModel)
    case connected(TodayActivityConnectedDisplayModel)
}

struct TodayActivityDisconnectedDisplayModel: Equatable {
    var title: String
    var message: String
    var actionTitle: String
    var showsLockedIcon: Bool
    var accessibilitySummary: String
}

struct TodayActivityConnectedDisplayModel: Equatable {
    var stepsLine: String?
    var stepAssumptionLine: String?
    var workoutStatusLine: String
    var weeklyProgressLine: String?
    var showsEmptyState: Bool
    var emptyStateTitle: String?
    var emptyStateLine: String?
    var accessibilitySummary: String
}

enum TodayActivitySectionFormatting {

    private static let stepFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func displayModel(for activity: ActivityTodayState) -> TodayActivitySectionPresentation {
        if isDisconnected(activity) {
            return .disconnected(disconnectedModel(for: activity))
        }
        return .connected(connectedModel(for: activity))
    }

    static func isDisconnected(_ activity: ActivityTodayState) -> Bool {
        activity.trainingDataSource == .appleHealth && activity.showsConnectCTA
    }

    static func disconnectedModel(for activity: ActivityTodayState) -> TodayActivityDisconnectedDisplayModel {
        let copy = TodayEmptyStateFormatting.copy(for: .appleHealthUnavailable)
        let message: String
        let actionTitle: String
        let showsLockedIcon = false

        switch activity.trainingIntegration {
        case .denied, .failed:
            message = FormaProductCopy.Today.Activity.disconnectedDeniedMessage
            actionTitle = FormaProductCopy.Today.actionManageHealthAccess
        case .notConnected, .unavailable, .requestingPermission, .connected:
            message = copy.body
            actionTitle = copy.actionTitle ?? FormaProductCopy.Training.Integration.connectAppleHealth
        }

        return TodayActivityDisconnectedDisplayModel(
            title: copy.title,
            message: message,
            actionTitle: actionTitle,
            showsLockedIcon: showsLockedIcon,
            accessibilitySummary: [
                FormaProductCopy.Today.Activity.sectionTitle,
                copy.title,
                message,
                actionTitle
            ].joined(separator: ". ")
        )
    }

    static func connectedModel(for activity: ActivityTodayState) -> TodayActivityConnectedDisplayModel {
        let stepsLine = activity.stepsToday.map { FormaProductCopy.Today.Activity.stepsToday($0) }
        let stepAssumptionLine = activity.stepGoalAssumption.map {
            FormaProductCopy.Today.Activity.typicalStepsAssumption($0)
        }
        let workoutStatusLine = workoutStatus(for: activity)
        let weeklyProgressLine = weeklyProgressLine(for: activity)
        let showsEmptyState = hasNoActivityData(activity)
        let emptyCopy = TodayEmptyStateFormatting.copy(for: .noActivityData)

        return TodayActivityConnectedDisplayModel(
            stepsLine: stepsLine,
            stepAssumptionLine: stepAssumptionLine,
            workoutStatusLine: workoutStatusLine,
            weeklyProgressLine: weeklyProgressLine,
            showsEmptyState: showsEmptyState,
            emptyStateTitle: showsEmptyState ? emptyCopy.title : nil,
            emptyStateLine: showsEmptyState ? emptyCopy.body : nil,
            accessibilitySummary: accessibilitySummary(
                stepsLine: stepsLine,
                stepAssumptionLine: stepAssumptionLine,
                workoutStatusLine: workoutStatusLine,
                weeklyProgressLine: weeklyProgressLine,
                showsEmptyState: showsEmptyState
            )
        )
    }

    static func hasNoActivityData(_ activity: ActivityTodayState) -> Bool {
        activity.stepsToday == nil
            && (activity.appleHealthWorkoutCount ?? 0) == 0
            && (activity.weeklyWorkoutCount ?? 0) == 0
    }

    static func workoutStatus(for activity: ActivityTodayState) -> String {
        switch activity.trainingDataSource {
        case .appleHealth:
            if let count = activity.appleHealthWorkoutCount, count > 0 {
                return FormaProductCopy.Today.workoutsToday(count)
            }
            return FormaProductCopy.Today.statusNoAppleHealthWorkoutToday
        case .unavailable:
            if activity.legacyWorkoutSummary.hasWorkout {
                return FormaProductCopy.Today.statusWorkoutRecorded
            }
            return FormaProductCopy.Today.statusNoWorkoutToday
        }
    }

    static func weeklyProgressLine(for activity: ActivityTodayState) -> String? {
        guard let targetSessions = activity.trainingFrequencyPerWeek, targetSessions > 0 else {
            return nil
        }

        let completedSessions = activity.weeklyWorkoutCount ?? 0
        return FormaProductCopy.Today.Activity.sessionsThisWeek(
            completed: completedSessions,
            target: targetSessions
        )
    }

    static func formatSteps(_ value: Int) -> String {
        stepFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func accessibilitySummary(
        stepsLine: String?,
        stepAssumptionLine: String?,
        workoutStatusLine: String,
        weeklyProgressLine: String?,
        showsEmptyState: Bool
    ) -> String {
        if showsEmptyState {
            return [
                FormaProductCopy.Today.Activity.sectionTitle,
                FormaProductCopy.Today.EmptyState.noActivityTitle,
                FormaProductCopy.Today.EmptyState.noActivityBody
            ].joined(separator: ". ")
        }

        var parts = [FormaProductCopy.Today.Activity.sectionTitle]
        if let stepsLine { parts.append(stepsLine) }
        if let stepAssumptionLine { parts.append(stepAssumptionLine) }
        parts.append(workoutStatusLine)
        if let weeklyProgressLine { parts.append(weeklyProgressLine) }
        return parts.joined(separator: ". ")
    }
}
