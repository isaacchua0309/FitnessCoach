//
//  TodayGoalConnectionFormatting.swift
//  Fitness Coach
//
//  Forma — Short copy linking Today to the long-term weight goal.
//

import Foundation

enum TodayGoalConnectionDestination: Equatable, Sendable {
    case journey
    case plan
}

struct TodayGoalConnectionState: Equatable, Sendable {
    var message: String
    var destination: TodayGoalConnectionDestination
    var accessibilityLabel: String
    var accessibilityHint: String
}

struct TodayGoalConnectionInput: Equatable, Sendable {
    var latestWeightKg: Double?
    var profileWeightKg: Double?
    var goalWeightKg: Double?
}

enum TodayGoalConnectionFormatting {

    /// Weights within this band of the goal count as maintain.
    static let maintainToleranceKg = 0.1

    /// Prefer distance copy when this many kg or more remain.
    static let distanceCopyThresholdKg = 2.0

    static func displayModel(for input: TodayGoalConnectionInput) -> TodayGoalConnectionState? {
        guard let goalWeightKg = input.goalWeightKg, goalWeightKg > 0 else { return nil }

        guard let currentWeightKg = resolvedCurrentWeight(
            latestWeightKg: input.latestWeightKg,
            profileWeightKg: input.profileWeightKg
        ) else {
            return nil
        }

        let direction = JourneyGoalDirection.resolve(
            startWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg
        )
        let kgToGo = abs(currentWeightKg - goalWeightKg)

        switch direction {
        case .maintain:
            return TodayGoalConnectionState(
                message: FormaProductCopy.Today.GoalConnection.maintainProgress,
                destination: .journey,
                accessibilityLabel: [
                    FormaProductCopy.Today.GoalConnection.accessibilityTitle,
                    FormaProductCopy.Today.GoalConnection.maintainProgress
                ].joined(separator: ". "),
                accessibilityHint: FormaProductCopy.Today.GoalConnection.openJourneyHint
            )
        case .lose, .gain:
            guard kgToGo > maintainToleranceKg else { return nil }

            let message: String
            if kgToGo >= distanceCopyThresholdKg {
                message = FormaProductCopy.Today.GoalConnection.kgToGoal(
                    formatKgCompact(kgToGo)
                )
            } else {
                message = FormaProductCopy.Today.GoalConnection.closerToGoal(
                    formatKgCompact(goalWeightKg)
                )
            }

            return TodayGoalConnectionState(
                message: message,
                destination: .journey,
                accessibilityLabel: [
                    FormaProductCopy.Today.GoalConnection.accessibilityTitle,
                    message
                ].joined(separator: ". "),
                accessibilityHint: FormaProductCopy.Today.GoalConnection.openJourneyHint
            )
        }
    }

    static func resolvedCurrentWeight(
        latestWeightKg: Double?,
        profileWeightKg: Double?
    ) -> Double? {
        if let latestWeightKg, latestWeightKg > 0 {
            return latestWeightKg
        }
        if let profileWeightKg, profileWeightKg > 0 {
            return profileWeightKg
        }
        return nil
    }

    static func formatKgCompact(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}
