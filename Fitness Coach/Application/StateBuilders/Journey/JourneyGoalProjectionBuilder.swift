//
//  JourneyGoalProjectionBuilder.swift
//  Fitness Coach
//
//  Forma — Goal projection card state from weight logs and trend.
//

import Foundation

enum JourneyGoalProjectionBuilder {

    struct Input: Equatable {
        var baseline: JourneyBaseline
        var allWeights: [WeightEntry]
        var asOf: Date
        var calendar: Calendar
    }

    private static let minimumWeightLogCount = 3
    private static let minimumSpanDays = 7
    private static let goalReachedToleranceKg = 0.1
    private static let flatWeeklyRateThresholdKg = 0.05
    private static let maxProjectionWeeks = 104.0

    static func build(_ input: Input) -> JourneyGoalProjectionState {
        let copy = FormaProductCopy.Journey.GoalProjection.self
        let sectionTitle = copy.sectionTitle

        guard let goalWeightKg = input.baseline.goalWeightKg else {
            return hidden(sectionTitle: sectionTitle)
        }

        let validWeights = validWeightEntries(from: input.allWeights)

        guard hasMinimumWeightData(weights: validWeights, calendar: input.calendar) else {
            return state(
                sectionTitle: sectionTitle,
                status: .insufficientData(
                    title: copy.insufficientTitle,
                    detail: copy.insufficientDetail
                )
            )
        }

        guard let currentWeightKg = input.baseline.currentWeightKg else {
            return state(
                sectionTitle: sectionTitle,
                status: .insufficientData(
                    title: copy.insufficientTitle,
                    detail: copy.insufficientDetail
                )
            )
        }

        if isGoalReached(currentWeightKg: currentWeightKg, goalWeightKg: goalWeightKg) {
            return state(
                sectionTitle: sectionTitle,
                status: .goalReached(
                    title: copy.goalReachedTitle,
                    detail: copy.goalReachedDetail
                )
            )
        }

        let projection = ProgressProjectionCalculator.projection(
            weights: validWeights,
            goalWeightKg: goalWeightKg,
            asOf: input.asOf
        )

        if let projectedDate = cappedProjectedDate(projection: projection, asOf: input.asOf),
           isTrendTowardGoal(
               goalDirection: input.baseline.goalDirection,
               weeklyRateKg: projection.weeklyRateKg,
               currentWeightKg: currentWeightKg,
               goalWeightKg: goalWeightKg
           ) {
            let goalLabel = JourneyFormatter.heroWeightKg(goalWeightKg)
            let dateLabel = JourneyFormatter.monthYear(projectedDate)
            return state(
                sectionTitle: sectionTitle,
                status: .towardGoal(
                    title: copy.towardGoalTitle,
                    detail: copy.towardGoalDetail(goalWeight: goalLabel, date: dateLabel)
                )
            )
        }

        if isFlatTrend(
            projection: projection,
            weights: validWeights,
            asOf: input.asOf
        ) {
            return state(
                sectionTitle: sectionTitle,
                status: .flatTrend(
                    title: copy.flatTrendTitle,
                    detail: copy.flatTrendDetail
                )
            )
        }

        return state(
            sectionTitle: sectionTitle,
            status: .awayFromGoal(
                title: copy.awayFromGoalTitle,
                detail: copy.awayFromGoalDetail
            )
        )
    }

    // MARK: - Data gates

    static func validWeightEntries(from weights: [WeightEntry]) -> [WeightEntry] {
        weights
            .filter { $0.weightKg > 0 }
            .sorted { $0.date < $1.date }
    }

    static func hasMinimumWeightData(weights: [WeightEntry], calendar: Calendar) -> Bool {
        guard weights.count >= minimumWeightLogCount,
              let first = weights.first,
              let last = weights.last else {
            return false
        }

        let start = calendar.startOfDay(for: first.date)
        let end = calendar.startOfDay(for: last.date)
        let spanDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return spanDays >= minimumSpanDays
    }

    // MARK: - Trend classification

    static func isGoalReached(currentWeightKg: Double, goalWeightKg: Double) -> Bool {
        abs(currentWeightKg - goalWeightKg) <= goalReachedToleranceKg
    }

    static func isTrendTowardGoal(
        goalDirection: JourneyGoalDirection,
        weeklyRateKg: Double?,
        currentWeightKg: Double,
        goalWeightKg: Double
    ) -> Bool {
        guard let weeklyRateKg else { return false }

        let remaining = goalWeightKg - currentWeightKg
        if abs(remaining) <= goalReachedToleranceKg {
            return true
        }

        switch goalDirection {
        case .lose:
            return weeklyRateKg < -flatWeeklyRateThresholdKg
        case .gain:
            return weeklyRateKg > flatWeeklyRateThresholdKg
        case .maintain:
            return abs(weeklyRateKg) <= flatWeeklyRateThresholdKg
        }
    }

    static func isFlatTrend(
        projection: ProgressProjection,
        weights: [WeightEntry],
        asOf: Date
    ) -> Bool {
        if let rate = projection.weeklyRateKg, abs(rate) <= flatWeeklyRateThresholdKg {
            return true
        }

        let trend = WeightTrendCalculator.trend(from: weights, endingOn: asOf)
        return trend.direction == .stable || trend.direction == .insufficientData
    }

    static func cappedProjectedDate(
        projection: ProgressProjection,
        asOf: Date
    ) -> Date? {
        guard let projectedDate = projection.projectedGoalDate,
              let weeks = projection.estimatedWeeksToGoal,
              weeks > 0,
              weeks <= maxProjectionWeeks,
              projectedDate >= asOf else {
            return nil
        }
        return projectedDate
    }

    // MARK: - Helpers

    private static func hidden(sectionTitle: String) -> JourneyGoalProjectionState {
        JourneyGoalProjectionState(
            sectionTitle: sectionTitle,
            status: .hidden,
            accessibilitySummary: ""
        )
    }

    private static func state(
        sectionTitle: String,
        status: JourneyGoalProjectionStatus
    ) -> JourneyGoalProjectionState {
        let title: String
        let detail: String
        switch status {
        case .hidden:
            return hidden(sectionTitle: sectionTitle)
        case .insufficientData(let resolvedTitle, let resolvedDetail),
             .towardGoal(let resolvedTitle, let resolvedDetail),
             .flatTrend(let resolvedTitle, let resolvedDetail),
             .awayFromGoal(let resolvedTitle, let resolvedDetail),
             .goalReached(let resolvedTitle, let resolvedDetail):
            title = resolvedTitle
            detail = resolvedDetail
        }

        return JourneyGoalProjectionState(
            sectionTitle: sectionTitle,
            status: status,
            accessibilitySummary: FormaProductCopy.Journey.GoalProjection.accessibilitySummary(
                title: title,
                detail: detail
            )
        )
    }
}
