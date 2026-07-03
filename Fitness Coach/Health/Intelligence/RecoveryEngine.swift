//
//  RecoveryEngine.swift
//  Fitness Coach
//
//  Forma — Recovery readiness scoring from normalized health signals.
//
//  Pure deterministic engine: no repository, no HealthKit, no diagnosis language.
//

import Foundation

// MARK: - Input

struct RecoveryEngineInput: Equatable, Sendable {
    let targetDate: Date
    let todayMetrics: DailyHealthMetrics
    let yesterdayMetrics: DailyHealthMetrics
    let sleepRecordsRecent: [NormalizedSleepRecord]
    let heartMetricsRecent: [NormalizedHeartMetric]
    let workoutsLast7Days: [NormalizedWorkout]
    let workoutsLast28Days: [NormalizedWorkout]
    let trainingLoadSummary: TrainingLoadSummary
    let baselineContext: HealthBaselineContext
    let calendar: Calendar
}

// MARK: - Policy

enum RecoveryPolicy {
    static let baseScore = 70
    static let readyScoreThreshold = 75
    static let moderateScoreThreshold = 55

    static let defaultHealthySleepMinutes = 450.0
    static let shortSleepMinutes = 360.0
    static let longSleepMinutes = 540.0

    static let restingHRElevatedDelta = 8.0
    static let restingHRDepressedDelta = 3.0
    static let hrvLowRatio = 0.85
    static let hrvHighRatio = 1.10

    static let highActivityStepsMultiplier = 1.35
    static let highActivityEnergyMultiplier = 1.30
}

// MARK: - Engine

struct RecoveryEngine: RecoveryEngineProviding {

    func evaluate(_ input: RecoveryEngineInput) throws -> RecoverySummary {
        let calendar = input.calendar
        let targetDay = calendar.startOfDay(for: input.targetDate)

        var score = RecoveryPolicy.baseScore
        var factors: [RecoveryContributingFactor] = []
        var missingSignals = Set<RecoveryMissingSignal>()
        var reliableSignalCount = 0
        var meaningfulSignalCount = 0
        var limitedEstimate = false

        if let sleepMinutes = Self.lastNightSleepMinutes(
            records: input.sleepRecordsRecent,
            targetDay: targetDay,
            calendar: calendar
        ) {
            meaningfulSignalCount += 1
            reliableSignalCount += 1
            let adjustment = sleepAdjustment(
                sleepMinutes: sleepMinutes,
                baseline: input.baselineContext.averageSleepDuration28d
            )
            score += adjustment.delta
            factors.append(
                RecoveryContributingFactor(
                    signal: .sleep,
                    impact: adjustment.impact,
                    detail: adjustment.detail
                )
            )
        } else {
            missingSignals.insert(.sleep)
        }

        if let restingHR = Self.latestHeartMetric(
            in: input.heartMetricsRecent,
            kind: .restingHeartRate,
            onOrBefore: targetDay,
            calendar: calendar
        ) {
            meaningfulSignalCount += 1
            reliableSignalCount += 1
            let adjustment = restingHRAdjustment(
                value: restingHR,
                baseline: input.baselineContext.averageRestingHeartRate28d
            )
            score += adjustment.delta
            factors.append(
                RecoveryContributingFactor(
                    signal: .restingHeartRate,
                    impact: adjustment.impact,
                    detail: adjustment.detail
                )
            )
        } else {
            missingSignals.insert(.restingHeartRate)
        }

        if let hrv = Self.latestHeartMetric(
            in: input.heartMetricsRecent,
            kind: .heartRateVariabilitySDNN,
            onOrBefore: targetDay,
            calendar: calendar
        ) {
            meaningfulSignalCount += 1
            reliableSignalCount += 1
            let adjustment = hrvAdjustment(
                value: hrv,
                baseline: input.baselineContext.averageHRV28d
            )
            score += adjustment.delta
            factors.append(
                RecoveryContributingFactor(
                    signal: .hrv,
                    impact: adjustment.impact,
                    detail: adjustment.detail
                )
            )
        } else {
            missingSignals.insert(.hrv)
        }

        if input.trainingLoadSummary.status != .unknown {
            meaningfulSignalCount += 1
            if input.trainingLoadSummary.confidence != .low {
                reliableSignalCount += 1
            }
            let adjustment = trainingLoadAdjustment(summary: input.trainingLoadSummary)
            score += adjustment.delta
            factors.append(
                RecoveryContributingFactor(
                    signal: .trainingLoad,
                    impact: adjustment.impact,
                    detail: adjustment.detail
                )
            )
        } else {
            missingSignals.insert(.trainingLoad)
        }

        let consecutiveDays = Self.consecutiveWorkoutDays(
            endingBefore: targetDay,
            workouts: input.workoutsLast7Days,
            calendar: calendar
        )
        if !input.workoutsLast7Days.isEmpty {
            meaningfulSignalCount += 1
            if consecutiveDays > 0 {
                reliableSignalCount += 1
            }
            let adjustment = consecutiveWorkoutAdjustment(days: consecutiveDays)
            if adjustment.delta != 0 {
                score += adjustment.delta
                factors.append(
                    RecoveryContributingFactor(
                        signal: .consecutiveWorkouts,
                        impact: adjustment.impact,
                        detail: adjustment.detail
                    )
                )
            }
        } else {
            missingSignals.insert(.workouts)
        }

        if input.yesterdayMetrics.steps > 0 || input.yesterdayMetrics.activeEnergyKcal > 0 {
            meaningfulSignalCount += 1
            let adjustment = yesterdayActivityAdjustment(
                metrics: input.yesterdayMetrics,
                baseline: input.baselineContext
            )
            if adjustment.delta != 0 {
                score += adjustment.delta
                factors.append(
                    RecoveryContributingFactor(
                        signal: .yesterdayActivity,
                        impact: adjustment.impact,
                        detail: adjustment.detail
                    )
                )
            }
            if input.baselineContext.averageSteps7d != nil
                || input.baselineContext.averageActiveEnergy7d != nil {
                reliableSignalCount += 1
            }
        } else if input.todayMetrics.steps > 0 {
            meaningfulSignalCount += 1
            limitedEstimate = true
            factors.append(
                RecoveryContributingFactor(
                    signal: .limitedActivity,
                    impact: .limited,
                    detail: "Only light activity signals are available so far today."
                )
            )
        } else {
            missingSignals.insert(.activity)
        }

        guard meaningfulSignalCount > 0 else {
            return .unknown
        }

        let hasRecoverySignals = !missingSignals.contains(.sleep)
            || !missingSignals.contains(.restingHeartRate)
            || !missingSignals.contains(.hrv)

        if !hasRecoverySignals {
            limitedEstimate = true
        }

        score = max(0, min(100, score))

        let status = resolveStatus(score: score, limitedEstimate: limitedEstimate)
        let confidence = resolveConfidence(
            reliableSignalCount: reliableSignalCount,
            meaningfulSignalCount: meaningfulSignalCount,
            limitedEstimate: limitedEstimate
        )

        let copy = recoveryCopy(
            status: status,
            limitedEstimate: limitedEstimate,
            confidence: confidence
        )

        return RecoverySummary(
            score: score,
            status: status,
            title: copy.title,
            explanation: copy.explanation,
            recommendedTraining: copy.training,
            recommendedNutrition: copy.nutrition,
            confidence: confidence,
            contributingFactors: factors,
            missingSignals: missingSignals
        )
    }

    // MARK: - Signal extraction

    static func lastNightSleepMinutes(
        records: [NormalizedSleepRecord],
        targetDay: Date,
        calendar: Calendar
    ) -> Double? {
        let wakeDay = calendar.startOfDay(for: targetDay)
        let matching = records.filter { calendar.startOfDay(for: $0.endDate) == wakeDay }
        guard !matching.isEmpty else { return nil }
        let total = matching.reduce(0) { $0 + $1.asleepMinutes }
        return total > 0 ? total : nil
    }

    static func latestHeartMetric(
        in metrics: [NormalizedHeartMetric],
        kind: HealthHeartMetricKind,
        onOrBefore day: Date,
        calendar: Calendar
    ) -> Double? {
        let cutoff = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cutoff) else {
            return nil
        }

        return metrics
            .filter { $0.kind == kind && $0.date >= cutoff && $0.date < nextDay }
            .max(by: { $0.date < $1.date })?
            .value
    }

    static func consecutiveWorkoutDays(
        endingBefore targetDay: Date,
        workouts: [NormalizedWorkout],
        calendar: Calendar
    ) -> Int {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: targetDay) else {
            return 0
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: yesterday)
        while true {
            let hasWorkout = workouts.contains { workout in
                calendar.isDate(workout.startDate, inSameDayAs: cursor)
            }
            guard hasWorkout else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return streak
    }

    // MARK: - Adjustments

    private struct Adjustment {
        let delta: Int
        let impact: RecoveryFactorImpact
        let detail: String
    }

    private func sleepAdjustment(sleepMinutes: Double, baseline: Double?) -> Adjustment {
        if let baseline, baseline > 0 {
            let ratio = sleepMinutes / baseline
            if ratio < 0.85 {
                return Adjustment(
                    delta: -13,
                    impact: .negative,
                    detail: "Sleep was below your recent average."
                )
            }
            if ratio > 1.10 {
                return Adjustment(
                    delta: 4,
                    impact: .positive,
                    detail: "Sleep was above your recent average."
                )
            }
            return Adjustment(
                delta: 2,
                impact: .neutral,
                detail: "Sleep was close to your recent average."
            )
        }

        if sleepMinutes < RecoveryPolicy.shortSleepMinutes {
            return Adjustment(
                delta: -12,
                impact: .negative,
                detail: "Sleep looked shorter than a typical restful night."
            )
        }
        if sleepMinutes < RecoveryPolicy.defaultHealthySleepMinutes {
            return Adjustment(
                delta: -5,
                impact: .negative,
                detail: "Sleep was a little short."
            )
        }
        if sleepMinutes <= RecoveryPolicy.longSleepMinutes {
            return Adjustment(
                delta: 3,
                impact: .positive,
                detail: "Sleep duration looked solid."
            )
        }
        return Adjustment(
            delta: 0,
            impact: .neutral,
            detail: "Sleep duration was on the longer side."
        )
    }

    private func restingHRAdjustment(value: Double, baseline: Double?) -> Adjustment {
        guard let baseline, baseline > 0 else {
            return Adjustment(
                delta: 0,
                impact: .neutral,
                detail: "Resting heart rate was logged."
            )
        }

        if value > baseline + RecoveryPolicy.restingHRElevatedDelta {
            return Adjustment(
                delta: -13,
                impact: .negative,
                detail: "Resting heart rate ran higher than your recent baseline."
            )
        }
        if value < baseline - RecoveryPolicy.restingHRDepressedDelta {
            return Adjustment(
                delta: 4,
                impact: .positive,
                detail: "Resting heart rate was lower than your recent baseline."
            )
        }
        return Adjustment(
            delta: 0,
            impact: .neutral,
            detail: "Resting heart rate was near your recent baseline."
        )
    }

    private func hrvAdjustment(value: Double, baseline: Double?) -> Adjustment {
        guard let baseline, baseline > 0 else {
            return Adjustment(
                delta: 0,
                impact: .neutral,
                detail: "HRV was logged."
            )
        }

        if value < baseline * RecoveryPolicy.hrvLowRatio {
            return Adjustment(
                delta: -12,
                impact: .negative,
                detail: "HRV was below your recent baseline."
            )
        }
        if value > baseline * RecoveryPolicy.hrvHighRatio {
            return Adjustment(
                delta: 5,
                impact: .positive,
                detail: "HRV was above your recent baseline."
            )
        }
        return Adjustment(
            delta: 0,
            impact: .neutral,
            detail: "HRV was near your recent baseline."
        )
    }

    private func trainingLoadAdjustment(summary: TrainingLoadSummary) -> Adjustment {
        switch summary.status {
        case .high:
            return Adjustment(
                delta: -8,
                impact: .negative,
                detail: "Recent training load is elevated."
            )
        case .overreaching:
            return Adjustment(
                delta: -15,
                impact: .negative,
                detail: "Recent training load is well above your recent pattern."
            )
        case .light, .normal:
            return Adjustment(
                delta: 0,
                impact: .neutral,
                detail: "Recent training load looks manageable."
            )
        case .unknown:
            return Adjustment(
                delta: 0,
                impact: .limited,
                detail: "Training load history is still limited."
            )
        }
    }

    private func consecutiveWorkoutAdjustment(days: Int) -> Adjustment {
        if days >= 4 {
            return Adjustment(
                delta: -10,
                impact: .negative,
                detail: "You have trained several days in a row."
            )
        }
        if days == 3 {
            return Adjustment(
                delta: -5,
                impact: .negative,
                detail: "You have trained three days in a row."
            )
        }
        return Adjustment(delta: 0, impact: .neutral, detail: "")
    }

    private func yesterdayActivityAdjustment(
        metrics: DailyHealthMetrics,
        baseline: HealthBaselineContext
    ) -> Adjustment {
        var delta = 0
        var elevated: [String] = []

        if let stepBaseline = baseline.averageSteps7d, stepBaseline > 0,
           Double(metrics.steps) > stepBaseline * RecoveryPolicy.highActivityStepsMultiplier {
            delta -= 4
            elevated.append("steps")
        }

        if let energyBaseline = baseline.averageActiveEnergy7d, energyBaseline > 0,
           metrics.activeEnergyKcal > energyBaseline * RecoveryPolicy.highActivityEnergyMultiplier {
            delta -= 3
            elevated.append("active energy")
        }

        guard delta != 0 else {
            return Adjustment(delta: 0, impact: .neutral, detail: "")
        }

        let detail = elevated.count == 2
            ? "Yesterday's steps and active energy were above your recent average."
            : "Yesterday's \(elevated[0]) were above your recent average."

        return Adjustment(delta: delta, impact: .negative, detail: detail)
    }

    // MARK: - Status & confidence

    private func resolveStatus(score: Int, limitedEstimate: Bool) -> RecoveryStatus {
        if limitedEstimate, score < RecoveryPolicy.readyScoreThreshold {
            return score >= RecoveryPolicy.moderateScoreThreshold ? .moderate : .low
        }
        if score >= RecoveryPolicy.readyScoreThreshold { return .ready }
        if score >= RecoveryPolicy.moderateScoreThreshold { return .moderate }
        return .low
    }

    private func resolveConfidence(
        reliableSignalCount: Int,
        meaningfulSignalCount: Int,
        limitedEstimate: Bool
    ) -> RecoveryConfidence {
        guard meaningfulSignalCount > 0 else { return .unknown }
        if reliableSignalCount >= 3, !limitedEstimate { return .high }
        if reliableSignalCount == 2 { return .moderate }
        if reliableSignalCount == 1 || limitedEstimate { return .low }
        return .low
    }

    private func recoveryCopy(
        status: RecoveryStatus,
        limitedEstimate: Bool,
        confidence: RecoveryConfidence
    ) -> (title: String, explanation: String, training: String, nutrition: String) {
        let limitedPrefix = limitedEstimate
            ? "This is a limited recovery estimate without sleep or heart signals. "
            : ""

        switch status {
        case .ready:
            return (
                title: "Ready for training",
                explanation: limitedPrefix + "Recovery signals look supportive for your usual training plan.",
                training: "Your usual training plan looks reasonable today.",
                nutrition: "Stick with your normal protein and hydration rhythm."
            )
        case .moderate:
            return (
                title: "Moderate recovery",
                explanation: limitedPrefix + "Recovery looks mixed, so steady pacing should work better than pushing hard.",
                training: "Moderate effort is a better fit; leave some room in the tank.",
                nutrition: "Prioritize protein and steady hydration today."
            )
        case .low:
            return (
                title: "Recovery needs attention",
                explanation: limitedPrefix + "Recovery signals suggest today is better for lighter movement and extra rest.",
                training: "Favor lighter movement or active recovery today.",
                nutrition: "Extra protein and fluids will support recovery."
            )
        case .unknown:
            return (
                title: "Recovery unclear",
                explanation: "Not enough recovery signals are available yet.",
                training: "Use how you feel before adding intensity today.",
                nutrition: "Stay on your usual plan until more data arrives."
            )
        }
    }
}
