//
//  WorkoutIntelligenceEngine.swift
//  Fitness Coach
//
//  Forma — Workout detection and summarization for Health Intelligence.
//
//  Pure deterministic engine: no HealthKit, no UI dependencies.
//

import Foundation

// MARK: - Input

struct WorkoutIntelligenceInput: Equatable, Sendable {
    let targetDate: Date
    let workoutsToday: [WorkoutRecord]
    let recentWorkouts: [WorkoutRecord]
    let trainingLoadSummary: TrainingLoadSummary
    let baselineContext: HealthBaselineContext
    let calendar: Calendar
}

// MARK: - Policy

enum WorkoutIntelligencePolicy {
    static let lowIntensityCaloriesPerMinute = 4.0
    static let highIntensityCaloriesPerMinute = 8.0
    static let longSessionMinutes = 45
    static let highDemandDurationMinutes = 60
    static let moderateDemandDurationLowerBound = 30
    static let hydrationLowMl = 250
    static let hydrationModerateMl = 500
    static let hydrationHighBaseMl = 700
    static let hydrationHighCapMl = 900
}

// MARK: - Engine

struct WorkoutIntelligenceEngine: WorkoutIntelligenceProviding {

    func evaluate(_ input: WorkoutIntelligenceInput) throws -> WorkoutSummary {
        let calendar = input.calendar
        let targetDay = calendar.startOfDay(for: input.targetDate)
        let workoutsToday = Self.workoutsOnTargetDay(
            input.workoutsToday,
            targetDay: targetDay,
            calendar: calendar
        )

        guard !workoutsToday.isEmpty else {
            return restDaySummary(trainingLoad: input.trainingLoadSummary)
        }

        let primary = workoutsToday.max {
            TrainingLoadScorer.workoutLoad(for: $0) < TrainingLoadScorer.workoutLoad(for: $1)
        } ?? workoutsToday[0]

        let totalDuration = workoutsToday.reduce(0) { $0 + $1.durationMinutes }
        let calorieValues = workoutsToday.compactMap { workout -> Int? in
            guard workout.activeEnergyKcal > 0 else { return nil }
            return Int(workout.activeEnergyKcal.rounded())
        }
        let totalCalories = calorieValues.isEmpty
            ? nil
            : calorieValues.reduce(0, +)

        let intensity = Self.aggregateIntensity(for: workoutsToday, totalDuration: totalDuration)
        let demand = resolveDemand(
            workouts: workoutsToday,
            totalDuration: totalDuration,
            intensity: intensity,
            primary: primary
        )
        let confidence = resolveConfidence(for: workoutsToday)
        let latest = workoutsToday.max { $0.endDate < $1.endDate }

        let hydrationAdviceMl = hydrationAdvice(for: demand, totalDuration: totalDuration)
        let nutritionAdvice = nutritionAdvice(for: demand)
        let explanation = explanation(
            for: workoutsToday,
            primary: primary,
            totalDuration: totalDuration,
            intensity: intensity,
            demand: demand
        )

        return WorkoutSummary(
            hasWorkout: true,
            primaryWorkoutType: primary.category,
            title: title(primary: primary, workoutCount: workoutsToday.count),
            workoutCount: workoutsToday.count,
            totalDurationMinutes: totalDuration,
            totalActiveCalories: totalCalories,
            intensity: intensity,
            demand: demand,
            latestWorkoutStart: latest?.startDate,
            latestWorkoutEnd: latest?.endDate,
            nutritionAdvice: nutritionAdvice,
            hydrationAdviceMl: hydrationAdviceMl,
            explanation: explanation,
            confidence: confidence,
            sourceSummary: sourceSummary(for: workoutsToday)
        )
    }

    // MARK: - Day filtering

    static func workoutsOnTargetDay(
        _ workouts: [WorkoutRecord],
        targetDay: Date,
        calendar: Calendar
    ) -> [WorkoutRecord] {
        let dayStart = calendar.startOfDay(for: targetDay)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return workouts
            .filter { workout in
                workout.startDate < dayEnd && workout.endDate > dayStart
            }
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.startDate < rhs.startDate
            }
    }

    // MARK: - Intensity

    static func intensity(for workout: WorkoutRecord) -> WorkoutSummaryIntensity {
        if workout.durationMinutes > 0, workout.activeEnergyKcal > 0 {
            let perMinute = workout.activeEnergyKcal / Double(workout.durationMinutes)
            let base: WorkoutSummaryIntensity
            if perMinute < WorkoutIntelligencePolicy.lowIntensityCaloriesPerMinute {
                base = .low
            } else if perMinute <= WorkoutIntelligencePolicy.highIntensityCaloriesPerMinute {
                base = .moderate
            } else {
                base = .high
            }
            return adjustIntensity(base, for: workout.category)
        }
        return inferredIntensity(for: workout)
    }

    private static func aggregateIntensity(
        for workouts: [WorkoutRecord],
        totalDuration: Int
    ) -> WorkoutSummaryIntensity {
        guard totalDuration > 0 else { return .unknown }

        let weighted = workouts.map { workout -> (WorkoutSummaryIntensity, Int) in
            (intensity(for: workout), workout.durationMinutes)
        }

        let highMinutes = weighted.filter { $0.0 == .high }.map(\.1).reduce(0, +)
        let moderateMinutes = weighted.filter { $0.0 == .moderate }.map(\.1).reduce(0, +)
        let lowMinutes = weighted.filter { $0.0 == .low }.map(\.1).reduce(0, +)

        if highMinutes >= totalDuration / 2 { return .high }
        if moderateMinutes + highMinutes >= totalDuration / 2 { return .moderate }
        if lowMinutes > 0 { return .low }
        return .unknown
    }

    private static func adjustIntensity(
        _ base: WorkoutSummaryIntensity,
        for category: FormaWorkoutCategory
    ) -> WorkoutSummaryIntensity {
        switch category {
        case .walking, .yoga:
            switch base {
            case .high: return .moderate
            case .moderate: return .low
            default: return base
            }
        case .hiit:
            switch base {
            case .low: return .moderate
            default: return base
            }
        default:
            return base
        }
    }

    private static func inferredIntensity(for workout: WorkoutRecord) -> WorkoutSummaryIntensity {
        switch workout.category {
        case .hiit:
            return workout.durationMinutes >= 20 ? .moderate : .low
        case .running:
            return workout.durationMinutes >= 30 ? .moderate : .low
        case .strength:
            return workout.durationMinutes >= 45 ? .moderate : .low
        case .walking, .yoga:
            return .low
        case .cycling, .swimming:
            return workout.durationMinutes >= 40 ? .moderate : .low
        case .other:
            return workout.durationMinutes >= 45 ? .moderate : .low
        }
    }

    // MARK: - Demand

    private func resolveDemand(
        workouts: [WorkoutRecord],
        totalDuration: Int,
        intensity: WorkoutSummaryIntensity,
        primary: WorkoutRecord
    ) -> WorkoutDemand {
        if isHighDemandLongSession(
            workouts: workouts,
            totalDuration: totalDuration,
            intensity: intensity
        ) {
            return .high
        }

        if totalDuration > WorkoutIntelligencePolicy.highDemandDurationMinutes,
           intensity == .moderate || intensity == .high {
            return .high
        }

        if totalDuration >= WorkoutIntelligencePolicy.moderateDemandDurationLowerBound,
           totalDuration <= WorkoutIntelligencePolicy.highDemandDurationMinutes {
            return .moderate
        }

        if totalDuration < WorkoutIntelligencePolicy.moderateDemandDurationLowerBound,
           intensity == .low {
            return .low
        }

        if totalDuration > 0 {
            return .moderate
        }

        return .unknown
    }

    private func isHighDemandLongSession(
        workouts: [WorkoutRecord],
        totalDuration: Int,
        intensity: WorkoutSummaryIntensity
    ) -> Bool {
        let demandingCategories: Set<FormaWorkoutCategory> = [.hiit, .running, .strength]
        return workouts.contains { workout in
            demandingCategories.contains(workout.category)
                && workout.durationMinutes >= WorkoutIntelligencePolicy.longSessionMinutes
                && (intensity == .moderate || intensity == .high)
        }
    }

    // MARK: - Advice

    private func hydrationAdvice(for demand: WorkoutDemand, totalDuration: Int) -> Int {
        switch demand {
        case .low:
            return WorkoutIntelligencePolicy.hydrationLowMl
        case .moderate:
            return WorkoutIntelligencePolicy.hydrationModerateMl
        case .high:
            let extra = max(0, totalDuration - WorkoutIntelligencePolicy.highDemandDurationMinutes) * 5
            return min(
                WorkoutIntelligencePolicy.hydrationHighCapMl,
                WorkoutIntelligencePolicy.hydrationHighBaseMl + extra
            )
        case .unknown:
            return WorkoutIntelligencePolicy.hydrationLowMl
        }
    }

    private func nutritionAdvice(for demand: WorkoutDemand) -> String {
        switch demand {
        case .high:
            return "Aim for 30–45g protein in your next meal to support recovery."
        case .moderate:
            return "Aim for 20–35g protein in your next meal."
        case .low, .unknown:
            return "Stay on your usual plan today."
        }
    }

    // MARK: - Copy

    private func title(primary: WorkoutRecord, workoutCount: Int) -> String {
        let label = primary.activityLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = label.isEmpty ? displayName(for: primary.category) : label
        guard workoutCount > 1 else { return name }
        return "\(name) + \(workoutCount - 1) more"
    }

    private func displayName(for category: FormaWorkoutCategory) -> String {
        switch category {
        case .strength: "Strength training"
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .yoga: "Yoga"
        case .hiit: "HIIT"
        case .other: "Workout"
        }
    }

    private func explanation(
        for workouts: [WorkoutRecord],
        primary: WorkoutRecord,
        totalDuration: Int,
        intensity: WorkoutSummaryIntensity,
        demand: WorkoutDemand
    ) -> String {
        let name = displayName(for: primary.category)
        if workouts.count > 1 {
            return "You logged \(workouts.count) workouts today for \(totalDuration) minutes. Keep recovery practical with fuel and fluids."
        }

        switch demand {
        case .high:
            return "\(name) was a bigger session today. Prioritize protein, fluids, and a little extra rest tonight."
        case .moderate:
            return "\(name) added solid training volume today. A balanced next meal will help you stay on track."
        case .low:
            return "\(name) was a lighter session. Stay consistent and build from here."
        case .unknown:
            return "\(name) is logged for today. Use how you feel to guide your next meal and recovery."
        }
    }

    private func sourceSummary(for workouts: [WorkoutRecord]) -> String {
        let sources = Set(workouts.compactMap(\.sourceName).filter { !$0.isEmpty })
        if sources.isEmpty {
            return "Based on synced workouts. Calorie figures are estimates and can vary."
        }
        if sources.count == 1, let source = sources.first {
            return "Based on workouts from \(source). Calorie figures are estimates and can vary."
        }
        return "Based on synced workouts. Calorie figures are estimates and can vary."
    }

    private func restDaySummary(trainingLoad: TrainingLoadSummary) -> WorkoutSummary {
        var summary = WorkoutSummary.noWorkout
        if trainingLoad.status == .high || trainingLoad.status == .overreaching {
            summary.demand = .low
            summary.explanation = "No workout logged yet today. Yesterday's load was elevated, so a lighter day can help."
        }
        return summary
    }

    // MARK: - Confidence

    private func resolveConfidence(for workouts: [WorkoutRecord]) -> WorkoutSummaryConfidence {
        let hasDuration = workouts.allSatisfy { $0.durationMinutes > 0 }
        let hasType = workouts.allSatisfy {
            $0.category != .other || !$0.activityLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let hasCalories = workouts.allSatisfy { $0.activeEnergyKcal > 0 }

        if hasDuration, hasType, hasCalories {
            return .high
        }
        if hasDuration, hasType {
            return .moderate
        }
        return .low
    }
}
