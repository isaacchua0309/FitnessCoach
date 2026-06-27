//
//  ProgressProjectionCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic goal-weight projection.
//

import Foundation

struct ProgressProjectionCalculator {

    private static let secondsPerWeek = 7.0 * 24.0 * 60.0 * 60.0

    // MARK: Weekly Rate

    /// Average weekly weight change (negative means losing weight) derived from
    /// the first and last entries across the observed span.
    static func weeklyRateKg(from weights: [WeightEntry]) -> Double? {
        guard weights.count >= 2 else { return nil }
        let sorted = weights.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }

        let totalChange = last.weightKg - first.weightKg
        let seconds = last.date.timeIntervalSince(first.date)
        guard seconds > 0 else { return nil }

        let weeks = seconds / secondsPerWeek
        guard weeks > 0 else { return nil }
        return totalChange / weeks
    }

    // MARK: Projection Date

    static func projectGoalDate(
        currentWeightKg: Double,
        goalWeightKg: Double,
        weeklyRateKg: Double,
        from startDate: Date
    ) -> Date? {
        let remaining = goalWeightKg - currentWeightKg

        // Already at or past goal.
        if abs(remaining) < 0.0001 { return startDate }

        // The rate must move in the same direction as the remaining distance.
        guard weeklyRateKg != 0, (remaining < 0) == (weeklyRateKg < 0) else {
            return nil
        }

        let weeks = remaining / weeklyRateKg
        guard weeks > 0 else { return nil }

        return startDate.addingTimeInterval(weeks * secondsPerWeek)
    }

    // MARK: Combined

    static func projection(
        weights: [WeightEntry],
        goalWeightKg: Double,
        asOf date: Date
    ) -> ProgressProjection {
        let current = WeightTrendCalculator.latestWeight(from: weights)?.weightKg
        let rate = weeklyRateKg(from: weights)
        let remaining = current.map { goalWeightKg - $0 }

        guard let current, let rate else {
            return ProgressProjection(
                currentWeightKg: current,
                goalWeightKg: goalWeightKg,
                remainingKg: remaining,
                weeklyRateKg: rate,
                estimatedWeeksToGoal: nil,
                projectedGoalDate: nil,
                confidence: .low
            )
        }

        let projectedDate = projectGoalDate(
            currentWeightKg: current,
            goalWeightKg: goalWeightKg,
            weeklyRateKg: rate,
            from: date
        )

        let weeksToGoal: Double?
        if rate != 0 {
            let weeks = (goalWeightKg - current) / rate
            weeksToGoal = weeks > 0 ? weeks : nil
        } else {
            weeksToGoal = nil
        }

        return ProgressProjection(
            currentWeightKg: current,
            goalWeightKg: goalWeightKg,
            remainingKg: remaining,
            weeklyRateKg: rate,
            estimatedWeeksToGoal: weeksToGoal,
            projectedGoalDate: projectedDate,
            confidence: confidence(forSampleCount: weights.count)
        )
    }

    // MARK: Helpers

    private static func confidence(forSampleCount count: Int) -> ConfidenceLevel {
        switch count {
        case ..<3:
            return .low
        case 3..<7:
            return .medium
        default:
            return .high
        }
    }
}
