//
//  TrainingLoadEngine.swift
//  Fitness Coach
//
//  Forma — Deterministic training load scoring from normalized workouts.
//
//  Pure engine: no repository, no HealthKit, no UI dependencies.
//

import Foundation

// MARK: - Status & confidence

enum TrainingLoadStatus: String, Equatable, Sendable, Codable {
    case light
    case normal
    case high
    case overreaching
    case unknown
}

enum TrainingLoadConfidence: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
}

enum TrainingLoadIntensity: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
    case unknown
}

enum TrainingLoadMissingSignal: String, Equatable, Sendable, Hashable, Codable {
    case workoutHistory
    case baseline
    case intensityData
    case calories
}

// MARK: - Summary

struct TrainingLoadSummary: Equatable, Sendable {
    var status: TrainingLoadStatus
    var todayLoad: Double
    var sevenDayLoad: Double
    var twentyEightDayAverageWeeklyLoad: Double
    var loadRatio: Double?
    var workoutDays7d: Int
    var workoutDays28d: Int
    var explanation: String
    var confidence: TrainingLoadConfidence
    var missingSignals: Set<TrainingLoadMissingSignal>

    static let unknown = TrainingLoadSummary(
        status: .unknown,
        todayLoad: 0,
        sevenDayLoad: 0,
        twentyEightDayAverageWeeklyLoad: 0,
        loadRatio: nil,
        workoutDays7d: 0,
        workoutDays28d: 0,
        explanation: "Not enough workout history to score training load yet.",
        confidence: .low,
        missingSignals: [.workoutHistory, .baseline]
    )
}

// MARK: - Input

struct TrainingLoadEngineInput: Equatable, Sendable {
    let targetDate: Date
    let workoutsToday: [NormalizedWorkout]
    let workoutsLast7Days: [NormalizedWorkout]
    let workoutsLast28Days: [NormalizedWorkout]
    let baselineAverageWeeklyLoad: Double?
    let calendar: Calendar
}

// MARK: - Policy

enum TrainingLoadPolicy {
    static let minimumWorkoutsForKnownStatus = 3
    static let maxSingleWorkoutLoad = 200.0
    static let lightRatioUpperBound = 0.70
    static let normalRatioUpperBound = 1.30
    static let highRatioUpperBound = 1.70
    static let weeksIn28DayWindow = 4.0

    static let lowIntensityCaloriesPerMinute = 6.0
    static let highIntensityCaloriesPerMinute = 10.0
}

// MARK: - Scoring

enum TrainingLoadScorer {

    static func workoutLoad(for workout: NormalizedWorkout) -> Double {
        let intensity = inferredIntensity(for: workout)
        let raw = Double(workout.durationMinutes)
            * intensity.multiplier
            * workout.category.typeMultiplier
        return min(raw, TrainingLoadPolicy.maxSingleWorkoutLoad)
    }

    static func totalLoad(for workouts: [NormalizedWorkout]) -> Double {
        workouts.reduce(0) { $0 + workoutLoad(for: $1) }
    }

    static func inferredIntensity(for workout: NormalizedWorkout) -> TrainingLoadIntensity {
        guard workout.durationMinutes > 0, workout.activeEnergyKcal > 0 else {
            return .unknown
        }

        let perMinute = workout.activeEnergyKcal / Double(workout.durationMinutes)
        if perMinute < TrainingLoadPolicy.lowIntensityCaloriesPerMinute {
            return .low
        }
        if perMinute <= TrainingLoadPolicy.highIntensityCaloriesPerMinute {
            return .moderate
        }
        return .high
    }

    static func workoutDays(
        in workouts: [NormalizedWorkout],
        calendar: Calendar
    ) -> Int {
        Set(workouts.map { calendar.startOfDay(for: $0.startDate) }).count
    }
}

private extension TrainingLoadIntensity {
    var multiplier: Double {
        switch self {
        case .low: 1.0
        case .moderate: 1.5
        case .high: 2.0
        case .unknown: 1.2
        }
    }
}

private extension FormaWorkoutCategory {
    var typeMultiplier: Double {
        switch self {
        case .walking: 0.75
        case .yoga: 0.8
        case .strength: 1.2
        case .hiit: 1.4
        case .running: 1.3
        case .cycling: 1.1
        case .swimming: 1.2
        case .other: 1.0
        }
    }
}

// MARK: - Engine

struct TrainingLoadEngine: TrainingLoadProviding {

    func evaluate(_ input: TrainingLoadEngineInput) throws -> TrainingLoadSummary {
        let calendar = input.calendar
        let workouts28 = input.workoutsLast28Days
        let workouts7 = input.workoutsLast7Days
        let workoutsToday = input.workoutsToday

        var missingSignals = Set<TrainingLoadMissingSignal>()

        let todayLoad = TrainingLoadScorer.totalLoad(for: workoutsToday)
        let sevenDayLoad = TrainingLoadScorer.totalLoad(for: workouts7)
        let twentyEightDayTotalLoad = TrainingLoadScorer.totalLoad(for: workouts28)
        let twentyEightDayAverageWeeklyLoad = twentyEightDayTotalLoad / TrainingLoadPolicy.weeksIn28DayWindow

        let workoutDays7d = TrainingLoadScorer.workoutDays(in: workouts7, calendar: calendar)
        let workoutDays28d = TrainingLoadScorer.workoutDays(in: workouts28, calendar: calendar)

        let workoutsWithMissingCalories = workouts28.filter {
            $0.durationMinutes > 0 && $0.activeEnergyKcal <= 0
        }
        if !workoutsWithMissingCalories.isEmpty {
            missingSignals.insert(.calories)
            missingSignals.insert(.intensityData)
        }

        let hasReliableBaseline = input.baselineAverageWeeklyLoad.map { $0 > 0 } ?? false
        if !hasReliableBaseline {
            missingSignals.insert(.baseline)
        }

        if workouts28.count < TrainingLoadPolicy.minimumWorkoutsForKnownStatus {
            missingSignals.insert(.workoutHistory)
        }

        let denominator = resolvedDenominator(
            baseline: input.baselineAverageWeeklyLoad,
            twentyEightDayAverageWeeklyLoad: twentyEightDayAverageWeeklyLoad
        )
        let loadRatio = denominator.map { base in
            base > 0 ? sevenDayLoad / base : nil
        } ?? nil

        let status = resolveStatus(
            loadRatio: loadRatio,
            workoutsIn28Days: workouts28.count,
            hasReliableBaseline: hasReliableBaseline
        )

        let confidence = resolveConfidence(
            workoutsIn28Days: workouts28.count,
            hasReliableBaseline: hasReliableBaseline,
            missingIntensityWorkouts: workoutsWithMissingCalories.count,
            totalWorkouts28: workouts28.count
        )

        let explanation = explanation(for: status, loadRatio: loadRatio)

        return TrainingLoadSummary(
            status: status,
            todayLoad: todayLoad,
            sevenDayLoad: sevenDayLoad,
            twentyEightDayAverageWeeklyLoad: twentyEightDayAverageWeeklyLoad,
            loadRatio: loadRatio,
            workoutDays7d: workoutDays7d,
            workoutDays28d: workoutDays28d,
            explanation: explanation,
            confidence: confidence,
            missingSignals: missingSignals
        )
    }

    // MARK: - Private

    private func resolvedDenominator(
        baseline: Double?,
        twentyEightDayAverageWeeklyLoad: Double
    ) -> Double? {
        if let baseline, baseline > 0 {
            return baseline
        }
        if twentyEightDayAverageWeeklyLoad > 0 {
            return twentyEightDayAverageWeeklyLoad
        }
        return nil
    }

    private func resolveStatus(
        loadRatio: Double?,
        workoutsIn28Days: Int,
        hasReliableBaseline: Bool
    ) -> TrainingLoadStatus {
        if workoutsIn28Days < TrainingLoadPolicy.minimumWorkoutsForKnownStatus,
           !hasReliableBaseline {
            return .unknown
        }

        guard let loadRatio else {
            if workoutsIn28Days == 0 {
                return .light
            }
            return .unknown
        }

        if loadRatio < TrainingLoadPolicy.lightRatioUpperBound {
            return .light
        }
        if loadRatio <= TrainingLoadPolicy.normalRatioUpperBound {
            return .normal
        }
        if loadRatio <= TrainingLoadPolicy.highRatioUpperBound {
            return .high
        }
        return .overreaching
    }

    private func resolveConfidence(
        workoutsIn28Days: Int,
        hasReliableBaseline: Bool,
        missingIntensityWorkouts: Int,
        totalWorkouts28: Int
    ) -> TrainingLoadConfidence {
        guard workoutsIn28Days >= TrainingLoadPolicy.minimumWorkoutsForKnownStatus else {
            return .low
        }

        let missingIntensityShare = totalWorkouts28 > 0
            ? Double(missingIntensityWorkouts) / Double(totalWorkouts28)
            : 1.0

        if missingIntensityShare > 0.5 {
            return .low
        }

        if hasReliableBaseline, missingIntensityWorkouts == 0 {
            return .high
        }

        if missingIntensityWorkouts == 0 {
            return .moderate
        }

        return .moderate
    }

    private func explanation(for status: TrainingLoadStatus, loadRatio: Double?) -> String {
        switch status {
        case .light:
            return "Training load is below your recent weekly average. Recovery should be straightforward."
        case .normal:
            return "Load is in line with your recent training pattern."
        case .high:
            return "Recent training load is elevated. Prioritize sleep and fueling."
        case .overreaching:
            return "Load is well above your baseline. Consider a lighter day."
        case .unknown:
            if loadRatio == nil {
                return "Not enough workout history to score training load yet."
            }
            return "Workout history is still limited, so load status is uncertain."
        }
    }
}
