//
//  JourneyHealthIntelligencePreviewData.swift
//  Fitness Coach
//
//  Forma — Preview fixtures for Journey Health Intelligence sections.
//

import Foundation

#if DEBUG
enum JourneyHealthIntelligencePreviewData {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private static var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
    }

    static var strongWeek: JourneyHealthIntelligenceSectionState {
        JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(
                currentSnapshot: currentSnapshot,
                historicalSnapshots: historicalSnapshots
            ),
            calendar: calendar,
            isUIEnabled: true
        )!
    }

    static var loading: JourneyHealthIntelligenceSectionState {
        JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(isLoading: true),
            calendar: calendar,
            isUIEnabled: true
        )!
    }

    static var unavailable: JourneyHealthIntelligenceSectionState {
        JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(),
            calendar: calendar,
            isUIEnabled: true
        )!
    }

    private static var currentSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 74,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable after recent training.",
                recommendedTraining: "You can train, but avoid stacking intensity tonight.",
                recommendedNutrition: "Prioritize protein and hydration after your workout.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .strength,
                title: "Strength training",
                workoutCount: 1,
                totalDurationMinutes: 50,
                totalActiveCalories: 320,
                intensity: .moderate,
                demand: .high,
                latestWorkoutStart: referenceDay,
                latestWorkoutEnd: referenceDay,
                nutritionAdvice: "Aim for 30–40g protein in your next meal.",
                hydrationAdviceMl: 700,
                explanation: "Strength training added meaningful load today.",
                confidence: .high,
                sourceSummary: "Synced workout."
            ),
            activity: ActivitySummary(steps: 9_120, activeEnergyKcal: 560, exerciseMinutes: 52),
            nutritionAdjustment: .none,
            weeklyReview: weeklyReview,
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            nextBestAction: .none
        )
    }

    private static var weeklyReview: WeeklyHealthReview {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: referenceDay)!
        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: referenceDay,
            title: "Solid training week",
            summary: "You logged consistent workouts and kept protein on track most days.",
            stats: WeeklyStats(
                totalWorkouts: 4,
                totalWorkoutMinutes: 210,
                totalActiveCalories: 1_420,
                averageSteps: 8_200,
                totalSteps: 57_400,
                proteinHitDays: 5,
                calorieTargetHitDays: 4,
                waterHitDays: 3,
                averageRecoveryScore: 68,
                lowRecoveryDays: 1,
                weightChangeKg: -0.3,
                loggingConsistencyDays: 6
            ),
            wins: ["4 workouts logged", "Protein on target 5 days"],
            risks: ["Hydration dipped mid-week"],
            nextWeekFocus: ["Front-load water", "Keep one rest day lighter"],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: referenceDay
        )
    }

    private static var historicalSnapshots: [HealthIntelligenceSnapshot] {
        (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else {
                return nil
            }
            let hasWorkout = offset == 0 || offset == 2
            return HealthIntelligenceSnapshot(
                date: day,
                recovery: RecoverySummary(
                    score: offset == 1 ? 52 : 72,
                    status: offset == 1 ? .low : .moderate,
                    title: offset == 1 ? "Recovery is low" : "Moderate recovery",
                    explanation: offset == 1
                        ? "Sleep was short and recent training load is elevated."
                        : "Recovery is acceptable after recent training.",
                    recommendedTraining: "Train based on how you feel.",
                    recommendedNutrition: "Stay on your usual plan.",
                    confidence: .moderate,
                    contributingFactors: [],
                    missingSignals: []
                ),
                workout: hasWorkout
                    ? WorkoutSummary(
                        hasWorkout: true,
                        primaryWorkoutType: .strength,
                        title: "Strength training",
                        workoutCount: 1,
                        totalDurationMinutes: 45 + offset * 2,
                        totalActiveCalories: 300,
                        intensity: .moderate,
                        demand: .high,
                        latestWorkoutStart: day,
                        latestWorkoutEnd: day,
                        nutritionAdvice: "",
                        hydrationAdviceMl: 0,
                        explanation: "Meaningful training load logged.",
                        confidence: .high,
                        sourceSummary: ""
                    )
                    : nil,
                activity: ActivitySummary(steps: 7_000 + offset * 200, activeEnergyKcal: 400, exerciseMinutes: 30),
                nutritionAdjustment: .none,
                weeklyReview: offset == 0 ? weeklyReview : nil,
                planConfidence: .unknown,
                nextBestAction: .none
            )
        }
    }
}
#endif
