//
//  TrainingStrategyTestSupport.swift
//  Fitness CoachTests
//
//  Shared fixtures for Apple Health training strategy tests (no live HealthKit).
//

import XCTest
@testable import Fitness_Coach

enum TrainingStrategyTestSupport {

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static var referenceNow: Date {
        TrainingInsightsPreviewData.referenceNow
    }

    static func makeWorkout(
        daysAgo: Int,
        minutes: Int,
        calories: Int?,
        name: String,
        calendar: Calendar = utcCalendar,
        asOf: Date = TrainingInsightsPreviewData.referenceNow
    ) -> HealthWorkoutRecord {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        let end = calendar.date(byAdding: .minute, value: minutes, to: start)!
        return HealthWorkoutRecord(
            id: UUID(),
            activityName: name,
            startDate: start,
            endDate: end,
            durationMinutes: minutes,
            activeCalories: calories
        )
    }

    static func journeyWorkoutRowLabel(for training: JourneyWeeklyTrainingStatus) -> String {
        JourneyWeeklyReviewBuilder.trainingValue(for: training)
            ?? FormaProductCopy.Journey.statusNoData
    }

    enum JourneyTrainingAnalyticsDisplay: Equatable {
        case hidden
        case emptyConnected
        case metrics
    }

    /// Mirrors `JourneyDashboardBuilder.trainingAnalyticsDisplay`.
    static func journeyTrainingAnalyticsDisplay(
        training: JourneyWeeklyTrainingStatus,
        workoutSummary: ProgressWorkoutSummary?
    ) -> JourneyTrainingAnalyticsDisplay {
        switch JourneyDashboardBuilder.trainingAnalyticsDisplay(
            weeklyTraining: training,
            workoutSummary: workoutSummary
        ) {
        case .hidden:
            return .hidden
        case .connectedEmpty:
            return .emptyConnected
        case .metrics:
            return .metrics
        }
    }

    @MainActor
    static func seedProfile(in container: AppContainer) throws {
        let targets = UserTargets(
            calorieTarget: 2_100,
            proteinTarget: 160,
            carbTarget: 220,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: 0.4,
            aggressiveness: .moderate
        )
        let draft = UserProfileDraft(
            name: "Test",
            age: 30,
            sex: .male,
            heightCm: 178,
            currentWeightKg: 90,
            goalWeightKg: 82,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7_000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: targets
        )
        _ = try container.userProfileService.createProfile(draft)
        _ = try container.dailyLogService.ensureTodayLog()
    }

    static func stubCoachIntent(_ intent: CoachIntent) -> CoachIntentResult {
        CoachIntentResult(
            intent: intent,
            confidence: 0.9,
            domain: .fitness,
            requiresAppMutation: intent == .logFood || intent == .logWorkout,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false,
            action: nil
        )
    }
}
