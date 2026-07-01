//
//  JourneyWeeklyReviewBuilder.swift
//  Fitness Coach
//
//  Forma — Weekly review rows and copy for the Journey "This Week" card.
//

import Foundation

enum JourneyWeeklyReviewBuilder {

    private static let trainingDefaultsResolver = ActivityTrainingDefaultsResolver()

    // MARK: - Expected training

    static func expectedTrainingDays(profile: UserProfile?) -> Int {
        guard let profile else { return 0 }
        if profile.trainingFrequencyPerWeek > 0 {
            return profile.trainingFrequencyPerWeek
        }
        return trainingDefaultsResolver.defaults(for: profile.activityLevel).trainingDaysPerWeek
    }

    // MARK: - Display assembly

    static func enrich(
        review: JourneyWeeklyReviewState,
        previousWeek: JourneyWeeklyReviewPreviousWeek?,
        goalDirection: JourneyGoalDirection,
        streaks: JourneyStreakState
    ) -> JourneyWeeklyReviewState {
        var enriched = review
        enriched.rows = rows(for: review, goalDirection: goalDirection)
        enriched.weekOverWeekDetail = weekOverWeekDetail(
            review: review,
            previousWeek: previousWeek
        )
        enriched.consistencyHeadline = streaks.weeklyConsistencyHeadline
        enriched.consistencyDetail = streaks.weeklyConsistencyDetail
            ?? streaks.keepStreakAliveCopy
        return enriched
    }

    static func rows(
        for review: JourneyWeeklyReviewState,
        goalDirection: JourneyGoalDirection
    ) -> [JourneyWeeklyReviewRow] {
        let copy = FormaProductCopy.Journey.WeeklyReview.self
        var rows: [JourneyWeeklyReviewRow] = [
            foodRow(review: review, copy: copy),
            proteinRow(review: review, copy: copy),
            waterRow(review: review, copy: copy)
        ]

        if let trainingRow = trainingRow(review: review, copy: copy) {
            rows.append(trainingRow)
        }

        rows.append(calorieRow(review: review, copy: copy))
        rows.append(weightRow(review: review, goalDirection: goalDirection, copy: copy))

        return rows.sorted {
            if $0.winScore != $1.winScore {
                return $0.winScore > $1.winScore
            }
            return rowOrder($0.id) < rowOrder($1.id)
        }
    }

    static func weekSummaryCopy(
        foodDays: Int,
        proteinDays: Int,
        trainingDays: Int,
        goalDirection: JourneyGoalDirection,
        weightDelta: Double?
    ) -> String {
        let copy = FormaProductCopy.Journey.WeeklyReview.self
        guard foodDays > 0 else { return copy.noFoodLogsSummary }

        var highlights: [String] = []
        if proteinDays >= foodDays {
            highlights.append("protein")
        }
        if let weightDelta,
           abs(weightDelta) >= 0.1,
           weightDeltaMovedTowardGoal(weightDelta, direction: goalDirection) {
            highlights.append("weight trend")
        }
        if trainingDays > 0 {
            highlights.append("training")
        }

        if highlights.isEmpty {
            return copy.foodLoggedDaysSummary(foodDays)
        }
        return copy.strongWeekSummary(highlights: englishList(highlights))
    }

    static func weekOverWeekDetail(
        review: JourneyWeeklyReviewState,
        previousWeek: JourneyWeeklyReviewPreviousWeek?
    ) -> String? {
        guard let previousWeek, previousWeek.hasComparableData else { return nil }

        let copy = FormaProductCopy.Journey.WeeklyReview.self
        var comparisons: [String] = []

        if previousWeek.foodLoggedDays > 0 || review.foodLoggedDays > 0 {
            comparisons.append(
                copy.weekOverWeekFood(
                    achieved: review.foodLoggedDays,
                    total: review.foodLoggedDaysTotal,
                    previousAchieved: previousWeek.foodLoggedDays
                )
            )
        }

        if previousWeek.proteinGoalDays > 0 || review.proteinGoalDays > 0 {
            comparisons.append(
                copy.weekOverWeekProtein(
                    achieved: review.proteinGoalDays,
                    total: review.proteinGoalDaysTotal,
                    previousAchieved: previousWeek.proteinGoalDays
                )
            )
        }

        if previousWeek.waterGoalDays > 0 || review.waterGoalDays > 0 {
            comparisons.append(
                copy.weekOverWeekWater(
                    achieved: review.waterGoalDays,
                    total: review.waterGoalDaysTotal,
                    previousAchieved: previousWeek.waterGoalDays
                )
            )
        }

        if previousWeek.trainingDays > 0 || review.trainingDays > 0 {
            comparisons.append(
                copy.weekOverWeekTraining(
                    achieved: review.trainingDays,
                    previousAchieved: previousWeek.trainingDays
                )
            )
        }

        guard !comparisons.isEmpty else { return nil }
        return comparisons.joined(separator: " · ")
    }

    static func trainingValue(for training: JourneyWeeklyTrainingStatus) -> String? {
        trainingValue(
            for: JourneyWeeklyReviewState(
                foodLoggedDays: 0,
                foodLoggedDaysTotal: 7,
                proteinGoalDays: 0,
                proteinGoalDaysTotal: 7,
                waterGoalDays: 0,
                waterGoalDaysTotal: 7,
                trainingDays: training.workoutDays ?? 0,
                expectedTrainingDays: 0,
                training: training,
                weightDeltaThisWeekKg: nil,
                calorieAdherenceDays: 0,
                calorieAdherenceDaysTotal: 7,
                weekSummaryCopy: "",
                rows: [],
                weekOverWeekDetail: nil
            )
        )
    }

    static func trainingValue(for review: JourneyWeeklyReviewState) -> String? {
        trainingRow(review: review, copy: FormaProductCopy.Journey.WeeklyReview.self)?.value
    }

    // MARK: - Rows

    private static func foodRow(
        review: JourneyWeeklyReviewState,
        copy: FormaProductCopy.Journey.WeeklyReview.Type
    ) -> JourneyWeeklyReviewRow {
        JourneyWeeklyReviewRow(
            id: "food",
            icon: "✅",
            title: copy.foodTitle,
            value: copy.dayFraction(
                achieved: review.foodLoggedDays,
                total: review.foodLoggedDaysTotal
            ),
            detail: nil,
            winScore: winScore(achieved: review.foodLoggedDays, total: review.foodLoggedDaysTotal)
        )
    }

    private static func proteinRow(
        review: JourneyWeeklyReviewState,
        copy: FormaProductCopy.Journey.WeeklyReview.Type
    ) -> JourneyWeeklyReviewRow {
        JourneyWeeklyReviewRow(
            id: "protein",
            icon: "🔥",
            title: copy.proteinTitle,
            value: copy.dayFraction(
                achieved: review.proteinGoalDays,
                total: review.proteinGoalDaysTotal
            ),
            detail: nil,
            winScore: winScore(achieved: review.proteinGoalDays, total: review.proteinGoalDaysTotal)
        )
    }

    private static func waterRow(
        review: JourneyWeeklyReviewState,
        copy: FormaProductCopy.Journey.WeeklyReview.Type
    ) -> JourneyWeeklyReviewRow {
        JourneyWeeklyReviewRow(
            id: "water",
            icon: "💧",
            title: copy.waterTitle,
            value: copy.dayFraction(
                achieved: review.waterGoalDays,
                total: review.waterGoalDaysTotal
            ),
            detail: nil,
            winScore: winScore(achieved: review.waterGoalDays, total: review.waterGoalDaysTotal)
        )
    }

    private static func trainingRow(
        review: JourneyWeeklyReviewState,
        copy: FormaProductCopy.Journey.WeeklyReview.Type
    ) -> JourneyWeeklyReviewRow? {
        switch review.training {
        case .hidden:
            return nil
        case .locked:
            return JourneyWeeklyReviewRow(
                id: "training",
                icon: "🏋",
                title: copy.trainingTitle,
                value: copy.trainingConnectAppleHealth,
                detail: nil,
                winScore: 0
            )
        case .connectedEmpty, .connected:
            let expected = review.expectedTrainingDays
            let value: String
            let score: Double
            if expected > 0 {
                value = copy.gymFraction(achieved: review.trainingDays, expected: expected)
                score = winScore(achieved: review.trainingDays, total: expected)
            } else {
                value = copy.trainingDays(review.trainingDays)
                score = review.trainingDays > 0 ? 1 : 0
            }
            return JourneyWeeklyReviewRow(
                id: "training",
                icon: "🏋",
                title: copy.trainingTitle,
                value: value,
                detail: nil,
                winScore: score
            )
        }
    }

    private static func calorieRow(
        review: JourneyWeeklyReviewState,
        copy: FormaProductCopy.Journey.WeeklyReview.Type
    ) -> JourneyWeeklyReviewRow {
        JourneyWeeklyReviewRow(
            id: "calories",
            icon: "🎯",
            title: copy.calorieTitle,
            value: copy.dayFraction(
                achieved: review.calorieAdherenceDays,
                total: review.calorieAdherenceDaysTotal
            ),
            detail: nil,
            winScore: winScore(
                achieved: review.calorieAdherenceDays,
                total: review.calorieAdherenceDaysTotal
            )
        )
    }

    private static func weightRow(
        review: JourneyWeeklyReviewState,
        goalDirection: JourneyGoalDirection,
        copy: FormaProductCopy.Journey.WeeklyReview.Type
    ) -> JourneyWeeklyReviewRow {
        let value = formattedWeightDelta(
            review.weightDeltaThisWeekKg,
            goalDirection: goalDirection,
            unavailableCopy: copy.weightUnavailable
        )
        let score: Double
        if let delta = review.weightDeltaThisWeekKg {
            score = weightDeltaMovedTowardGoal(delta, direction: goalDirection) ? 1 : 0.25
        } else {
            score = 0
        }

        return JourneyWeeklyReviewRow(
            id: "weight",
            icon: "⚖",
            title: copy.weightTitle,
            value: value,
            detail: nil,
            winScore: score
        )
    }

    // MARK: - Formatting

    static func formattedWeightDelta(
        _ delta: Double?,
        goalDirection: JourneyGoalDirection,
        unavailableCopy: String = FormaProductCopy.Journey.WeeklyReview.weightUnavailable
    ) -> String {
        guard let delta else { return unavailableCopy }

        let magnitude = abs(delta)
        let formatted: String
        if magnitude.truncatingRemainder(dividingBy: 1) == 0 {
            formatted = "\(Int(magnitude))kg"
        } else {
            formatted = String(format: "%.1fkg", magnitude)
        }

        switch goalDirection {
        case .lose:
            return delta < 0 ? "-\(formatted)" : "+\(formatted)"
        case .gain:
            return delta > 0 ? "+\(formatted)" : "-\(formatted)"
        case .maintain:
            return delta >= 0 ? "+\(formatted)" : "-\(formatted)"
        }
    }

    static func previousWeekMetrics(
        logs: [DailyLog],
        weekWeights: [WeightEntry],
        trainingDays: Int
    ) -> JourneyWeeklyReviewPreviousWeek {
        JourneyWeeklyReviewPreviousWeek(
            foodLoggedDays: JourneyLogMetrics.foodLoggedDays(in: logs),
            proteinGoalDays: JourneyLogMetrics.proteinGoalDays(in: logs),
            waterGoalDays: JourneyLogMetrics.waterGoalDays(in: logs),
            calorieAdherenceDays: JourneyLogMetrics.calorieAdherenceDays(in: logs),
            trainingDays: trainingDays,
            weightDeltaKg: JourneyLogMetrics.weightDelta(in: weekWeights)
        )
    }

    private static func winScore(achieved: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(achieved) / Double(total)
    }

    private static func rowOrder(_ id: String) -> Int {
        switch id {
        case "food": return 0
        case "protein": return 1
        case "water": return 2
        case "training": return 3
        case "calories": return 4
        case "weight": return 5
        default: return 99
        }
    }

    private static func englishList(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head), and \(items.last!)"
        }
    }

    private static func weightDeltaMovedTowardGoal(
        _ delta: Double,
        direction: JourneyGoalDirection
    ) -> Bool {
        switch direction {
        case .lose:
            return delta < -0.05
        case .gain:
            return delta > 0.05
        case .maintain:
            return abs(delta) < 0.5
        }
    }
}
