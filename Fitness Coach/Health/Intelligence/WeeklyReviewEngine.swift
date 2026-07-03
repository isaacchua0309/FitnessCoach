//
//  WeeklyReviewEngine.swift
//  Fitness Coach
//
//  Forma — Weekly health and training review synthesis.
//
//  Pure deterministic engine: no HealthKit, no UI dependencies, no AI backend.
//

import Foundation

// MARK: - Input models

struct WeeklyNutritionDailySummary: Equatable, Sendable {
    var date: Date
    var caloriesConsumed: Int
    var calorieTarget: Int
    var proteinConsumedGrams: Double
    var proteinTargetGrams: Double
    var waterConsumedMl: Int
    var waterTargetMl: Int
    var didLogFood: Bool
}

struct DailyRecoverySummary: Equatable, Sendable {
    var date: Date
    var summary: RecoverySummary
}

struct WeeklyReviewUserPlan: Equatable, Sendable {
    var goal: PlanGoalType
    var calorieTarget: Int
    var proteinTargetGrams: Double
    var waterTargetMl: Int

    static let unavailable = WeeklyReviewUserPlan(
        goal: .maintain,
        calorieTarget: 0,
        proteinTargetGrams: 0,
        waterTargetMl: 0
    )
}

struct WeeklyReviewEngineInput: Equatable, Sendable {
    let weekStartDate: Date
    let weekEndDate: Date
    let dailyMetrics: [DailyHealthMetrics]
    let workouts: [NormalizedWorkout]
    let recoverySummaries: [DailyRecoverySummary]
    let nutritionDailySummaries: [WeeklyNutritionDailySummary]
    let weightRecords: [NormalizedBodyMass]
    let userPlan: WeeklyReviewUserPlan
    let calendar: Calendar
    let generatedAt: Date
}

// MARK: - Policy

enum WeeklyReviewPolicy {
    static let proteinHitProgress = 0.95
    static let calorieHitLowerBound = 0.90
    static let calorieHitUpperBound = 1.10
    static let waterHitProgress = 0.90
    static let strongWorkoutDays = 3
    static let strongProteinDays = 5
    static let strongCalorieDays = 5
    static let lowProteinDaysThreshold = 2
    static let lowCalorieDaysThreshold = 3
    static let repeatedLowRecoveryDays = 3
    static let targetDailySteps = 7_000
    static let stepConsistencyRatio = 0.85
    static let lowStepsRatio = 0.70
    static let minWeightRecords = 2
    static let maxFocusItems = 3
    static let meaningfulWeightChangeKg = 0.15
    static let maintainWeightBandKg = 0.5
    static let stableRecoveryScoreThreshold = 65.0
    static let stableLowRecoveryDaysMax = 1
    static let minHealthDaysForModerateConfidence = 4
    static let minNutritionDaysForModerateConfidence = 4
    static let minRecoveryDaysForHighConfidence = 3
}

private enum WeeklyReviewWinKind: Int, Comparable {
    case workouts = 0
    case steps = 1
    case protein = 2
    case calories = 3
    case weight = 4
    case recovery = 5

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private enum WeeklyReviewRiskKind: Int, Comparable {
    case recovery = 0
    case workouts = 1
    case protein = 2
    case calories = 3
    case steps = 4
    case weight = 5

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private struct RankedWeeklyReviewCopy: Comparable {
    let kind: Int
    let message: String

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.kind < rhs.kind
    }
}

// MARK: - Engine

struct WeeklyReviewEngine: WeeklyReviewProviding {

    func evaluate(_ input: WeeklyReviewEngineInput) throws -> WeeklyHealthReview? {
        let weekMetrics = metricsInWeek(input)
        guard hasAnySignal(weekMetrics: weekMetrics, input: input) else {
            return nil
        }

        let weekWorkouts = workoutsInWeek(input)
        let stats = buildStats(
            weekMetrics: weekMetrics,
            weekWorkouts: weekWorkouts,
            input: input
        )
        let missingSignals = buildMissingSignals(
            weekMetrics: weekMetrics,
            weekWorkouts: weekWorkouts,
            input: input
        )
        let wins = buildWins(stats: stats, input: input)
        let risks = buildRisks(stats: stats, input: input, missingSignals: missingSignals)
        let nextWeekFocus = buildNextWeekFocus(risks: risks, missingSignals: missingSignals)
        let confidence = buildConfidence(weekMetrics: weekMetrics, input: input)
        let title = buildTitle(wins: wins, risks: risks, confidence: confidence)
        let summary = buildSummary(
            wins: wins,
            risks: risks,
            stats: stats,
            confidence: confidence
        )

        return WeeklyHealthReview(
            weekStartDate: input.weekStartDate,
            weekEndDate: input.weekEndDate,
            title: title,
            summary: summary,
            stats: stats,
            wins: wins,
            risks: risks,
            nextWeekFocus: nextWeekFocus,
            confidence: confidence,
            missingSignals: missingSignals,
            generatedAt: input.generatedAt
        )
    }

    // MARK: - Stats

    private func buildStats(
        weekMetrics: [DailyHealthMetrics],
        weekWorkouts: [NormalizedWorkout],
        input: WeeklyReviewEngineInput
    ) -> WeeklyStats {
        let totalWorkoutMinutes = weekWorkouts.reduce(0) { $0 + $1.durationMinutes }
        let activeCalories = weekWorkouts.reduce(0.0) { $0 + $1.activeEnergyKcal }
        let totalActiveCalories = activeCalories > 0 ? Int(activeCalories.rounded()) : nil

        let stepValues = weekMetrics.map(\.steps).filter { $0 > 0 }
        let totalSteps = stepValues.isEmpty ? nil : stepValues.reduce(0, +)
        let averageSteps = stepValues.isEmpty
            ? nil
            : stepValues.reduce(0, +) / stepValues.count

        let nutritionByDay = nutritionByDay(input)
        let proteinHitDays = nutritionByDay.values.filter(isProteinHit).count
        let calorieTargetHitDays = nutritionByDay.values.filter(isCalorieHit).count
        let waterHitDays = nutritionByDay.values.filter(isWaterHit).count
        let loggingConsistencyDays = nutritionByDay.values.filter(\.didLogFood).count

        let recoveryScores = input.recoverySummaries.compactMap(\.summary.score).map(Double.init)
        let averageRecoveryScore = recoveryScores.isEmpty
            ? nil
            : Self.roundedAverage(recoveryScores)
        let lowRecoveryDays = input.recoverySummaries.filter { $0.summary.status == .low }.count

        let sortedWeights = input.weightRecords.sorted { $0.date < $1.date }
        let weightChangeKg: Double?
        if sortedWeights.count >= WeeklyReviewPolicy.minWeightRecords {
            weightChangeKg = sortedWeights.last!.valueKg - sortedWeights.first!.valueKg
        } else {
            weightChangeKg = nil
        }

        return WeeklyStats(
            totalWorkouts: weekWorkouts.count,
            totalWorkoutMinutes: totalWorkoutMinutes,
            totalActiveCalories: totalActiveCalories,
            averageSteps: averageSteps,
            totalSteps: totalSteps,
            proteinHitDays: proteinHitDays,
            calorieTargetHitDays: calorieTargetHitDays,
            waterHitDays: waterHitDays,
            averageRecoveryScore: averageRecoveryScore,
            lowRecoveryDays: lowRecoveryDays,
            weightChangeKg: weightChangeKg,
            loggingConsistencyDays: loggingConsistencyDays
        )
    }

    // MARK: - Wins

    private func buildWins(stats: WeeklyStats, input: WeeklyReviewEngineInput) -> [String] {
        var ranked: [RankedWeeklyReviewCopy] = []

        let workoutDays = uniqueWorkoutDays(in: workoutsInWeek(input), calendar: input.calendar)
        if workoutDays >= WeeklyReviewPolicy.strongWorkoutDays {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewWinKind.workouts.rawValue,
                    message: "You trained on \(workoutDays) days this week."
                )
            )
        }

        if let averageSteps = stats.averageSteps {
            let target = Int(Double(WeeklyReviewPolicy.targetDailySteps) * WeeklyReviewPolicy.stepConsistencyRatio)
            if averageSteps >= target {
                ranked.append(
                    RankedWeeklyReviewCopy(
                        kind: WeeklyReviewWinKind.steps.rawValue,
                        message: "Daily movement stayed steady at about \(formatSteps(averageSteps)) steps."
                    )
                )
            }
        }

        if stats.proteinHitDays >= WeeklyReviewPolicy.strongProteinDays {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewWinKind.protein.rawValue,
                    message: "Protein targets were hit on \(stats.proteinHitDays) days."
                )
            )
        }

        if stats.calorieTargetHitDays >= WeeklyReviewPolicy.strongCalorieDays {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewWinKind.calories.rawValue,
                    message: "Calorie intake stayed close to plan on \(stats.calorieTargetHitDays) days."
                )
            )
        }

        if let change = stats.weightChangeKg, isWeightTrendAligned(change, goal: input.userPlan.goal) {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewWinKind.weight.rawValue,
                    message: weightTrendWin(change: change, goal: input.userPlan.goal)
                )
            )
        }

        if let averageRecovery = stats.averageRecoveryScore,
           stats.lowRecoveryDays <= WeeklyReviewPolicy.stableLowRecoveryDaysMax,
           averageRecovery >= WeeklyReviewPolicy.stableRecoveryScoreThreshold {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewWinKind.recovery.rawValue,
                    message: "Recovery stayed stable through the week."
                )
            )
        }

        return ranked.sorted().map(\.message)
    }

    // MARK: - Risks

    private func buildRisks(
        stats: WeeklyStats,
        input: WeeklyReviewEngineInput,
        missingSignals: Set<WeeklyReviewMissingSignal>
    ) -> [String] {
        var ranked: [RankedWeeklyReviewCopy] = []

        if stats.lowRecoveryDays >= WeeklyReviewPolicy.repeatedLowRecoveryDays {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewRiskKind.recovery.rawValue,
                    message: "Recovery was low on \(stats.lowRecoveryDays) days."
                )
            )
        }

        if !missingSignals.contains(.nutrition), stats.proteinHitDays <= WeeklyReviewPolicy.lowProteinDaysThreshold {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewRiskKind.protein.rawValue,
                    message: "Protein was below target on most days."
                )
            )
        }

        if !missingSignals.contains(.nutrition),
           stats.calorieTargetHitDays <= WeeklyReviewPolicy.lowCalorieDaysThreshold {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewRiskKind.calories.rawValue,
                    message: "Calorie intake varied widely from your plan."
                )
            )
        }

        if stats.totalWorkouts == 0 {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewRiskKind.workouts.rawValue,
                    message: "No workouts were logged this week."
                )
            )
        }

        if let averageSteps = stats.averageSteps {
            let threshold = Int(Double(WeeklyReviewPolicy.targetDailySteps) * WeeklyReviewPolicy.lowStepsRatio)
            if averageSteps < threshold {
                ranked.append(
                    RankedWeeklyReviewCopy(
                        kind: WeeklyReviewRiskKind.steps.rawValue,
                        message: "Average steps were below your usual movement baseline."
                    )
                )
            }
        }

        if missingSignals.contains(.weight) {
            ranked.append(
                RankedWeeklyReviewCopy(
                    kind: WeeklyReviewRiskKind.weight.rawValue,
                    message: "Not enough weigh-ins to track progress confidently."
                )
            )
        }

        return ranked.sorted().map(\.message)
    }

    // MARK: - Focus

    private func buildNextWeekFocus(
        risks: [String],
        missingSignals: Set<WeeklyReviewMissingSignal>
    ) -> [String] {
        var focus: [String] = []

        if risks.contains(where: { $0.contains("No workouts") }) {
            focus.append("Schedule 2–3 training sessions.")
        }
        if risks.contains(where: { $0.contains("Protein was below target") }) {
            focus.append("Anchor protein at breakfast and lunch.")
        }
        if risks.contains(where: { $0.contains("Recovery was low") }) {
            focus.append("Prioritize sleep and lighter training when needed.")
        }
        if risks.contains(where: { $0.contains("steps were below") }) {
            focus.append("Add a short walk on lower-activity days.")
        }
        if risks.contains(where: { $0.contains("Calorie intake varied") }) {
            focus.append("Log meals earlier to keep fueling steadier.")
        }
        if missingSignals.contains(.weight) {
            focus.append("Weigh in 2–3 times next week.")
        }

        if focus.isEmpty {
            focus.append("Keep your current rhythm and stay consistent.")
        }

        return Array(focus.prefix(WeeklyReviewPolicy.maxFocusItems))
    }

    // MARK: - Summary / title / confidence

    private func buildTitle(
        wins: [String],
        risks: [String],
        confidence: WeeklyReviewConfidence
    ) -> String {
        if confidence == .low {
            return "Getting started"
        }
        if wins.count >= 3 {
            return "Strong week"
        }
        if wins.count >= 1 {
            return "Steady progress"
        }
        if !risks.isEmpty {
            return "Room to build"
        }
        return "Weekly check-in"
    }

    private func buildSummary(
        wins: [String],
        risks: [String],
        stats: WeeklyStats,
        confidence: WeeklyReviewConfidence
    ) -> String {
        if confidence == .low {
            return "A few signals came through this week. As more health and nutrition data arrives, your review will get sharper."
        }

        if wins.count >= 3 {
            return "You built solid momentum with consistent training and fueling. Keep building on what is already working."
        }

        if let firstWin = wins.first, let firstRisk = risks.first {
            return "\(firstWin) \(firstRisk) A small adjustment next week can help you stay on track."
        }

        if let firstWin = wins.first {
            return "\(firstWin) Stay with the habits that supported you this week."
        }

        if let firstRisk = risks.first {
            return "\(firstRisk) Pick one focus for next week and keep the rest simple."
        }

        if stats.totalWorkouts > 0 {
            return "You logged \(stats.totalWorkouts) workouts this week. Keep following your plan at a steady pace."
        }

        return "This week gave you a baseline to build from. Small consistent steps will compound."
    }

    private func buildConfidence(
        weekMetrics: [DailyHealthMetrics],
        input: WeeklyReviewEngineInput
    ) -> WeeklyReviewConfidence {
        let healthDays = weekMetrics.filter {
            $0.steps > 0 || $0.exerciseMinutes > 0 || $0.activeEnergyKcal > 0
        }.count
        let hasHealth = healthDays >= WeeklyReviewPolicy.minHealthDaysForModerateConfidence

        let nutritionDays = input.nutritionDailySummaries.filter(\.didLogFood).count
        let hasNutrition = nutritionDays >= WeeklyReviewPolicy.minNutritionDaysForModerateConfidence

        let hasWeight = input.weightRecords.count >= WeeklyReviewPolicy.minWeightRecords
        let recoveryDays = input.recoverySummaries.filter { $0.summary.status != .unknown }.count
        let hasRecovery = recoveryDays >= WeeklyReviewPolicy.minRecoveryDaysForHighConfidence

        if hasHealth, hasNutrition, hasWeight, hasRecovery {
            return .high
        }
        if hasHealth, hasNutrition {
            return .moderate
        }
        return .low
    }

    private func buildMissingSignals(
        weekMetrics: [DailyHealthMetrics],
        weekWorkouts: [NormalizedWorkout],
        input: WeeklyReviewEngineInput
    ) -> Set<WeeklyReviewMissingSignal> {
        var missing: Set<WeeklyReviewMissingSignal> = []

        let healthDays = weekMetrics.filter { $0.steps > 0 || $0.exerciseMinutes > 0 }.count
        if healthDays < WeeklyReviewPolicy.minHealthDaysForModerateConfidence {
            missing.insert(.activity)
        }

        if weekWorkouts.isEmpty {
            missing.insert(.workouts)
        }

        let nutritionDays = input.nutritionDailySummaries.filter(\.didLogFood).count
        if input.nutritionDailySummaries.isEmpty
            || nutritionDays < WeeklyReviewPolicy.minNutritionDaysForModerateConfidence {
            missing.insert(.nutrition)
        }

        if input.weightRecords.count < WeeklyReviewPolicy.minWeightRecords {
            missing.insert(.weight)
        }

        if input.recoverySummaries.isEmpty {
            missing.insert(.recovery)
        } else {
            if input.recoverySummaries.allSatisfy({ $0.summary.missingSignals.contains(.sleep) }) {
                missing.insert(.sleep)
            }
            if input.recoverySummaries.allSatisfy({ $0.summary.missingSignals.contains(.hrv) }) {
                missing.insert(.hrv)
            }
        }

        return missing
    }

    // MARK: - Helpers

    private func hasAnySignal(
        weekMetrics: [DailyHealthMetrics],
        input: WeeklyReviewEngineInput
    ) -> Bool {
        weekMetrics.contains { $0.steps > 0 || $0.exerciseMinutes > 0 || $0.activeEnergyKcal > 0 }
            || !workoutsInWeek(input).isEmpty
            || input.nutritionDailySummaries.contains(where: \.didLogFood)
            || !input.weightRecords.isEmpty
            || !input.recoverySummaries.isEmpty
    }

    private func metricsInWeek(_ input: WeeklyReviewEngineInput) -> [DailyHealthMetrics] {
        let start = input.calendar.startOfDay(for: input.weekStartDate)
        let end = input.calendar.startOfDay(for: input.weekEndDate)
        return input.dailyMetrics.filter {
            let day = input.calendar.startOfDay(for: $0.date)
            return day >= start && day <= end
        }
    }

    private func workoutsInWeek(_ input: WeeklyReviewEngineInput) -> [NormalizedWorkout] {
        let start = input.calendar.startOfDay(for: input.weekStartDate)
        let end = input.calendar.startOfDay(for: input.weekEndDate)
        return input.workouts.filter {
            let day = input.calendar.startOfDay(for: $0.startDate)
            return day >= start && day <= end
        }
    }

    private func nutritionByDay(
        _ input: WeeklyReviewEngineInput
    ) -> [Date: WeeklyNutritionDailySummary] {
        var byDay: [Date: WeeklyNutritionDailySummary] = [:]
        for summary in input.nutritionDailySummaries {
            let day = input.calendar.startOfDay(for: summary.date)
            byDay[day] = summary
        }
        return byDay
    }

    private func uniqueWorkoutDays(
        in workouts: [NormalizedWorkout],
        calendar: Calendar
    ) -> Int {
        Set(workouts.map { calendar.startOfDay(for: $0.startDate) }).count
    }

    private func isProteinHit(_ summary: WeeklyNutritionDailySummary) -> Bool {
        guard summary.didLogFood, summary.proteinTargetGrams > 0 else { return false }
        return summary.proteinConsumedGrams / summary.proteinTargetGrams >= WeeklyReviewPolicy.proteinHitProgress
    }

    private func isCalorieHit(_ summary: WeeklyNutritionDailySummary) -> Bool {
        guard summary.didLogFood, summary.calorieTarget > 0 else { return false }
        let ratio = Double(summary.caloriesConsumed) / Double(summary.calorieTarget)
        return ratio >= WeeklyReviewPolicy.calorieHitLowerBound
            && ratio <= WeeklyReviewPolicy.calorieHitUpperBound
    }

    private func isWaterHit(_ summary: WeeklyNutritionDailySummary) -> Bool {
        guard summary.didLogFood, summary.waterTargetMl > 0 else { return false }
        return Double(summary.waterConsumedMl) / Double(summary.waterTargetMl) >= WeeklyReviewPolicy.waterHitProgress
    }

    private func isWeightTrendAligned(_ changeKg: Double, goal: PlanGoalType) -> Bool {
        switch goal {
        case .loseFat:
            return changeKg <= -WeeklyReviewPolicy.meaningfulWeightChangeKg
        case .gainMuscle:
            return changeKg >= WeeklyReviewPolicy.meaningfulWeightChangeKg
        case .maintain:
            return abs(changeKg) <= WeeklyReviewPolicy.maintainWeightBandKg
        }
    }

    private func weightTrendWin(changeKg: Double, goal: PlanGoalType) -> String {
        switch goal {
        case .loseFat:
            return "Weight trend moved in line with your fat-loss goal."
        case .gainMuscle:
            return "Weight trend moved in line with your muscle-gain goal."
        case .maintain:
            return "Weight stayed steady within your maintenance range."
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private static func roundedAverage(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let average = values.reduce(0, +) / Double(values.count)
        return average.rounded()
    }
}
