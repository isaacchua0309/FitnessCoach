//
//  HealthIntelligenceMocks.swift
//  Fitness Coach
//
//  Forma — DEBUG-only mock factories for Health Intelligence previews and tests.
//  Not compiled into Release builds.
//

#if DEBUG
import Foundation

// MARK: - Fixtures

enum HealthIntelligenceMockFixtures {

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static var referenceDay: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
    }

    static func startOfDay(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        calendar: Calendar = Self.calendar
    ) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: year, month: month, day: day))!)
    }

    static func workoutTimestamp(
        on day: Date,
        hour: Int,
        calendar: Calendar = Self.calendar
    ) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: calendar.startOfDay(for: day)
        ) ?? day
    }
}

// MARK: - Component mocks

extension RecoverySummary {

    static var mockReady: RecoverySummary {
        RecoverySummary(
            score: 84,
            status: .ready,
            title: "Ready to train",
            explanation: "Sleep and recovery signals look supportive for your usual plan today.",
            recommendedTraining: "Your usual training plan looks reasonable today.",
            recommendedNutrition: "Stick with your normal protein and hydration rhythm.",
            confidence: .high,
            contributingFactors: [
                RecoveryContributingFactor(
                    signal: .sleep,
                    impact: .positive,
                    detail: "Mock: sleep on track"
                ),
                RecoveryContributingFactor(
                    signal: .hrv,
                    impact: .positive,
                    detail: "Mock: HRV supportive"
                )
            ],
            missingSignals: []
        )
    }

    static var mockLow: RecoverySummary {
        RecoverySummary(
            score: 48,
            status: .low,
            title: "Recovery is low",
            explanation: "Sleep was short and recent training load is elevated.",
            recommendedTraining: "Keep today lighter and avoid stacking hard sessions.",
            recommendedNutrition: "Prioritize protein, hydration, and steady fueling today.",
            confidence: .moderate,
            contributingFactors: [
                RecoveryContributingFactor(
                    signal: .sleep,
                    impact: .negative,
                    detail: "Mock: short sleep"
                ),
                RecoveryContributingFactor(
                    signal: .trainingLoad,
                    impact: .negative,
                    detail: "Mock: elevated load"
                )
            ],
            missingSignals: []
        )
    }
}

extension WorkoutSummary {

    static func mockStrengthWorkout(
        on day: Date = HealthIntelligenceMockFixtures.referenceDay,
        calendar: Calendar = HealthIntelligenceMockFixtures.calendar
    ) -> WorkoutSummary {
        let start = HealthIntelligenceMockFixtures.workoutTimestamp(on: day, hour: 7, calendar: calendar)
        let end = calendar.date(byAdding: .minute, value: 50, to: start) ?? start

        return WorkoutSummary(
            hasWorkout: true,
            primaryWorkoutType: .strength,
            title: "Strength training",
            workoutCount: 1,
            totalDurationMinutes: 50,
            totalActiveCalories: 320,
            intensity: .moderate,
            demand: .high,
            latestWorkoutStart: start,
            latestWorkoutEnd: end,
            nutritionAdvice: "Aim for 30–40g protein in your next meal.",
            hydrationAdviceMl: 700,
            explanation: "Strength training added meaningful load today.",
            confidence: .high,
            sourceSummary: "Mock synced workout."
        )
    }
}

extension TrainingLoadSummary {

    static var mockNormal: TrainingLoadSummary {
        TrainingLoadSummary(
            status: .normal,
            todayLoad: 58,
            sevenDayLoad: 245,
            twentyEightDayAverageWeeklyLoad: 220,
            loadRatio: 1.11,
            workoutDays7d: 3,
            workoutDays28d: 11,
            explanation: "Training load is in a normal range for your recent history.",
            confidence: .moderate,
            missingSignals: []
        )
    }
}

extension AdaptiveNutritionSummary {

    static var mockPostWorkout: AdaptiveNutritionSummary {
        AdaptiveNutritionSummary(
            proteinRecommendationGrams: 35,
            suggestedProteinRemaining: 28,
            waterIncreaseMl: 350,
            suggestedWaterRemainingMl: 900,
            calorieAdvice: "Keep calories steady and prioritize protein after training.",
            shouldChangeTarget: false,
            suggestedCalorieAdjustment: 0,
            adjustmentReason: "",
            priority: 6,
            confidence: .high,
            missingSignals: []
        )
    }
}

extension NextBestAction {

    static func mockLogProtein(
        on day: Date = HealthIntelligenceMockFixtures.referenceDay
    ) -> NextBestAction {
        NextBestAction(
            id: "mock-log-protein",
            title: "Log protein",
            message: "You still have meaningful protein left after today's workout.",
            ctaTitle: "Log meal",
            destination: .logMeal,
            priority: 2,
            reason: .postWorkoutRecovery,
            createdAt: day,
            expiresAt: Calendar.current.date(byAdding: .hour, value: 3, to: day)
        )
    }
}

extension WeeklyHealthReview {

    static func mockStrongWeek(
        endingOn day: Date = HealthIntelligenceMockFixtures.referenceDay,
        calendar: Calendar = HealthIntelligenceMockFixtures.calendar
    ) -> WeeklyHealthReview {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: day)) ?? day

        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: calendar.startOfDay(for: day),
            title: "Strong week",
            summary: "You built solid momentum with consistent training and fueling.",
            stats: WeeklyStats(
                totalWorkouts: 4,
                totalWorkoutMinutes: 185,
                totalActiveCalories: 1_450,
                averageSteps: 8_200,
                totalSteps: 57_400,
                proteinHitDays: 6,
                calorieTargetHitDays: 5,
                waterHitDays: 5,
                averageRecoveryScore: 76,
                lowRecoveryDays: 1,
                weightChangeKg: -0.25,
                loggingConsistencyDays: 6
            ),
            wins: [
                "You trained on 4 days this week.",
                "Protein targets were hit on 6 days."
            ],
            risks: [],
            nextWeekFocus: ["Keep your current rhythm and stay consistent."],
            confidence: .high,
            missingSignals: [],
            generatedAt: day
        )
    }
}

// MARK: - Snapshot mocks

extension HealthIntelligenceSnapshot {

    static func mockReadyDay(
        for date: Date = HealthIntelligenceMockFixtures.referenceDay,
        calendar: Calendar = HealthIntelligenceMockFixtures.calendar
    ) -> HealthIntelligenceSnapshot {
        let day = calendar.startOfDay(for: date)

        return HealthIntelligenceSnapshot(
            date: day,
            recovery: .mockReady,
            workout: nil,
            activity: ActivitySummary(steps: 8_450, activeEnergyKcal: 420, exerciseMinutes: 38),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.82, label: "High"),
            nextBestAction: NextBestAction(
                id: "mock-stay-on-plan",
                title: "Stay on plan",
                message: "Recovery looks good. Keep following your usual plan today.",
                ctaTitle: "",
                destination: .none,
                priority: 7,
                reason: .stayOnPlan,
                createdAt: day,
                expiresAt: nil
            )
        )
    }

    static func mockWorkoutDay(
        for date: Date = HealthIntelligenceMockFixtures.referenceDay,
        calendar: Calendar = HealthIntelligenceMockFixtures.calendar
    ) -> HealthIntelligenceSnapshot {
        let day = calendar.startOfDay(for: date)

        return HealthIntelligenceSnapshot(
            date: day,
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
            workout: .mockStrengthWorkout(on: day, calendar: calendar),
            activity: ActivitySummary(steps: 9_120, activeEnergyKcal: 560, exerciseMinutes: 52),
            nutritionAdjustment: .mockPostWorkout,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            nextBestAction: .mockLogProtein(on: day)
        )
    }

    static func mockLowRecoveryDay(
        for date: Date = HealthIntelligenceMockFixtures.referenceDay,
        calendar: Calendar = HealthIntelligenceMockFixtures.calendar
    ) -> HealthIntelligenceSnapshot {
        let day = calendar.startOfDay(for: date)

        return HealthIntelligenceSnapshot(
            date: day,
            recovery: .mockLow,
            workout: nil,
            activity: ActivitySummary(steps: 5_600, activeEnergyKcal: 290, exerciseMinutes: 22),
            nutritionAdjustment: AdaptiveNutritionSummary(
                proteinRecommendationGrams: nil,
                suggestedProteinRemaining: nil,
                waterIncreaseMl: 250,
                suggestedWaterRemainingMl: 1_100,
                calorieAdvice: "Keep fueling steady while recovery catches up.",
                shouldChangeTarget: false,
                suggestedCalorieAdjustment: 0,
                adjustmentReason: "",
                priority: 3,
                confidence: .moderate,
                missingSignals: []
            ),
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.62, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "mock-recover",
                title: "Prioritize recovery",
                message: "Recovery is low today. Keep movement light and fuel steadily.",
                ctaTitle: "View recovery",
                destination: .viewRecovery,
                priority: 2,
                reason: .lowRecovery,
                createdAt: day,
                expiresAt: nil
            )
        )
    }

    static func mockNoHealthData(
        for date: Date = HealthIntelligenceMockFixtures.referenceDay,
        calendar: Calendar = HealthIntelligenceMockFixtures.calendar
    ) -> HealthIntelligenceSnapshot {
        let day = calendar.startOfDay(for: date)

        return HealthIntelligenceSnapshot(
            date: day,
            recovery: .unknown,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: NextBestAction(
                id: "mock-connect-health",
                title: "Connect Apple Health",
                message: "Enable Apple Health to unlock recovery and activity insights.",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: day,
                expiresAt: nil
            )
        )
    }

    static func mockWeeklyReview(
        for date: Date = HealthIntelligenceMockFixtures.referenceDay,
        calendar: Calendar = HealthIntelligenceMockFixtures.calendar
    ) -> HealthIntelligenceSnapshot {
        let day = calendar.startOfDay(for: date)

        return HealthIntelligenceSnapshot(
            date: day,
            recovery: .mockReady,
            workout: nil,
            activity: ActivitySummary(steps: 7_900, activeEnergyKcal: 390, exerciseMinutes: 36),
            nutritionAdjustment: .none,
            weeklyReview: .mockStrongWeek(endingOn: day, calendar: calendar),
            planConfidence: PlanHealthConfidence(score: 0.75, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "mock-weekly-review",
                title: "Review your week",
                message: "Your weekly review is ready with wins and focus areas.",
                ctaTitle: "",
                destination: .none,
                priority: 5,
                reason: .stayOnPlan,
                createdAt: day,
                expiresAt: nil
            )
        )
    }
}
#endif
