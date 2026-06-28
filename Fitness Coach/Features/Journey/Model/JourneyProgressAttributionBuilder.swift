//
//  JourneyProgressAttributionBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic "why you progressed" attribution for Journey.
//

import Foundation

enum JourneyProgressAttributionBuilder {

    struct Input: Equatable {
        var currentPeriodLogs: [DailyLog]
        var previousPeriodLogs: [DailyLog]
        var weekLogs: [DailyLog]
        var previousWeekLogs: [DailyLog]
        var weightSummary: ProgressWeightSummary
        var goalDirection: JourneyGoalDirection
        var weeklyTrainingDays: Int
        var previousWeekTrainingDays: Int
        var isAppleHealthConnected: Bool
        var asOf: Date
        var calendar: Calendar
    }

    private struct Candidate: Equatable {
        var priority: Int
        var title: String
        var detail: String
    }

    private static let minimumFoodLogDaysToUnlock = 3
    private static let maximumSupportingReasons = 3

    static func build(_ input: Input) -> JourneyProgressAttributionState {
        let copy = FormaProductCopy.Journey.WhyProgress.self
        let foodLogDays = uniqueFoodLogDays(in: input.currentPeriodLogs, calendar: input.calendar)

        guard foodLogDays >= minimumFoodLogDaysToUnlock else {
            return .insufficientData
        }

        let candidates = rankedCandidates(input: input, copy: copy)
        guard let primary = candidates.first else {
            return .insufficientData
        }

        let supporting = Array(
            candidates
                .dropFirst()
                .filter { !isDuplicate($0, comparedTo: primary) }
                .prefix(maximumSupportingReasons)
                .map(\.detail)
        )

        return JourneyProgressAttributionState(
            primaryReasonTitle: primary.title,
            primaryReasonDetail: primary.detail,
            supportingReasons: supporting,
            confidence: confidence(for: input, foodLogDays: foodLogDays)
        )
    }

    // MARK: - Candidates

    private static func rankedCandidates(
        input: Input,
        copy: FormaProductCopy.Journey.WhyProgress.Type
    ) -> [Candidate] {
        var candidates: [Candidate] = []

        let calorieEligible = input.currentPeriodLogs.filter { $0.targets.calorieTarget > 0 }
        let calorieAchieved = JourneyLogMetrics.calorieAdherenceDays(in: input.currentPeriodLogs)
        let calorieRate = adherenceRate(achieved: calorieAchieved, eligible: calorieEligible.count)

        let thisWeekProtein = JourneyLogMetrics.proteinGoalDays(in: input.weekLogs)
        let lastWeekProtein = JourneyLogMetrics.proteinGoalDays(in: input.previousWeekLogs)
        let proteinChangePercent = percentChange(
            current: thisWeekProtein,
            previous: lastWeekProtein
        )

        let thisWeekFood = JourneyLogMetrics.foodLoggedDays(in: input.weekLogs)
        let lastWeekFood = JourneyLogMetrics.foodLoggedDays(in: input.previousWeekLogs)
        let foodChange = thisWeekFood - lastWeekFood

        let thisWeekWater = JourneyLogMetrics.waterGoalDays(in: input.weekLogs)
        let lastWeekWater = JourneyLogMetrics.waterGoalDays(in: input.previousWeekLogs)
        let waterChangePercent = percentChange(current: thisWeekWater, previous: lastWeekWater)

        let weightAligned = weightTrendAlignsWithGoal(
            goalDirection: input.goalDirection,
            weightDirection: input.weightSummary.direction
        )
        let hasMeaningfulWeightProgress = hasWeightProgress(
            summary: input.weightSummary,
            goalDirection: input.goalDirection
        )

        if calorieRate >= 0.6, weightAligned, calorieEligible.count >= 5 {
            candidates.append(
                Candidate(
                    priority: 100,
                    title: copy.calorieLikelyHelpedTitle,
                    detail: copy.stayedWithinCalories(
                        achieved: calorieAchieved,
                        eligible: calorieEligible.count
                    )
                )
            )
        } else if calorieRate >= 0.7, calorieEligible.count >= 5 {
            candidates.append(
                Candidate(
                    priority: 90,
                    title: copy.calorieLikelyHelpedTitle,
                    detail: copy.stayedWithinCalories(
                        achieved: calorieAchieved,
                        eligible: calorieEligible.count
                    )
                )
            )
        } else if calorieAchieved > 0, calorieEligible.count > 0 {
            candidates.append(
                Candidate(
                    priority: 60,
                    title: copy.biggestReasonTitle,
                    detail: copy.stayedWithinCalories(
                        achieved: calorieAchieved,
                        eligible: calorieEligible.count
                    )
                )
            )
        }

        if proteinChangePercent >= 5 {
            candidates.append(
                Candidate(
                    priority: 85,
                    title: copy.proteinAnchorTitle,
                    detail: copy.increasedProteinConsistency(percent: proteinChangePercent)
                )
            )
        }

        if thisWeekFood >= 6 || foodChange >= 2 {
            candidates.append(
                Candidate(
                    priority: 80,
                    title: copy.loggingControlTitle,
                    detail: copy.loggedFoodDaysThisWeek(thisWeekFood)
                )
            )
        } else if thisWeekFood > 0 {
            candidates.append(
                Candidate(
                    priority: 55,
                    title: copy.biggestReasonTitle,
                    detail: copy.loggedFoodDaysThisWeek(thisWeekFood)
                )
            )
        }

        if input.isAppleHealthConnected,
           input.weeklyTrainingDays > input.previousWeekTrainingDays,
           input.weeklyTrainingDays >= 2 {
            candidates.append(
                Candidate(
                    priority: 75,
                    title: copy.trainingRhythmTitle,
                    detail: copy.trainingDaysThisWeek(input.weeklyTrainingDays)
                )
            )
        }

        if waterChangePercent >= 10 {
            candidates.append(
                Candidate(
                    priority: 70,
                    title: copy.waterSupportTitle,
                    detail: copy.improvedWaterConsistency(percent: waterChangePercent)
                )
            )
        }

        if !hasMeaningfulWeightProgress,
           thisWeekFood >= 4,
           calorieRate >= 0.4 || thisWeekProtein >= 3 {
            candidates.append(
                Candidate(
                    priority: 65,
                    title: copy.habitsBeforeScaleTitle,
                    detail: copy.loggedFoodDaysThisWeek(thisWeekFood)
                )
            )
        }

        if weightAligned, hasMeaningfulWeightProgress {
            candidates.append(
                Candidate(
                    priority: 50,
                    title: copy.biggestReasonTitle,
                    detail: copy.weightTrendTowardGoal(direction: input.goalDirection)
                )
            )
        }

        if candidates.isEmpty {
            candidates.append(
                Candidate(
                    priority: 0,
                    title: copy.insufficientTitle,
                    detail: copy.insufficientDetail
                )
            )
        }

        return candidates.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.title < rhs.title
        }
    }

    // MARK: - Confidence

    private static func confidence(
        for input: Input,
        foodLogDays: Int
    ) -> JourneyProgressAttributionConfidence {
        if foodLogDays < minimumFoodLogDaysToUnlock {
            return .low
        }

        let metricCount = [
            JourneyLogMetrics.calorieAdherenceDays(in: input.currentPeriodLogs) > 0,
            JourneyLogMetrics.proteinGoalDays(in: input.weekLogs) > 0,
            JourneyLogMetrics.foodLoggedDays(in: input.weekLogs) > 0,
            input.weightSummary.direction != .insufficientData
        ].filter { $0 }.count

        if foodLogDays >= 7, metricCount >= 3 {
            return .high
        }
        if foodLogDays >= 5, metricCount >= 2 {
            return .medium
        }
        return .low
    }

    // MARK: - Helpers

    private static func uniqueFoodLogDays(in logs: [DailyLog], calendar: Calendar) -> Int {
        Set(
            logs.filter { $0.totals.calories > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    private static func adherenceRate(achieved: Int, eligible: Int) -> Double {
        guard eligible > 0 else { return 0 }
        return Double(achieved) / Double(eligible)
    }

    private static func percentChange(current: Int, previous: Int) -> Int {
        guard previous > 0 else {
            return current > 0 ? 100 : 0
        }
        return Int((Double(current - previous) / Double(previous) * 100).rounded())
    }

    private static func weightTrendAlignsWithGoal(
        goalDirection: JourneyGoalDirection,
        weightDirection: WeightTrendDirection
    ) -> Bool {
        switch goalDirection {
        case .lose:
            return weightDirection == .decreasing
        case .gain:
            return weightDirection == .increasing
        case .maintain:
            return weightDirection == .stable
        }
    }

    private static func hasWeightProgress(
        summary: ProgressWeightSummary,
        goalDirection: JourneyGoalDirection
    ) -> Bool {
        guard let change = summary.changeKg else { return false }
        switch goalDirection {
        case .lose:
            return change < -0.1
        case .gain:
            return change > 0.1
        case .maintain:
            return abs(change) <= 0.5
        }
    }

    private static func isDuplicate(_ candidate: Candidate, comparedTo primary: Candidate) -> Bool {
        candidate.detail == primary.detail || candidate.title == primary.title
    }
}
