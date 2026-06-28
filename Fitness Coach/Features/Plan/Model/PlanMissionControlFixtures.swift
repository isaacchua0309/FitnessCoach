//
//  PlanMissionControlFixtures.swift
//  Fitness Coach
//
//  Forma — Static fixtures for Plan Mission Control previews and tests.
//

import Foundation

enum PlanMissionControlFixtures {

    private static let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!
    private static let calendar = Calendar.current

    // MARK: - Profiles

    static var loseProfile: UserProfile {
        UserProfile(
            id: UUID(uuidString: "A1A1A1A1-A1A1-A1A1-A1A1-A1A1A1A1A1")!,
            name: "Alex",
            birthDate: calendar.date(from: DateComponents(year: 1998, month: 3, day: 15)),
            age: 28,
            sex: .female,
            heightCm: 168,
            currentWeightKg: 90,
            goalWeightKg: 75,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 7500,
            dietPreference: nil,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 2233,
                proteinTarget: 180,
                carbTarget: 180,
                fatTarget: 58,
                waterTargetMl: 3150,
                expectedWeeklyWeightLossKg: 0.8,
                aggressiveness: .aggressive
            ),
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!,
            updatedAt: referenceDate
        )
    }

    static var gainProfile: UserProfile {
        var profile = loseProfile
        profile.currentWeightKg = 70
        profile.goalWeightKg = 76
        profile.targets = UserTargets(
            calorieTarget: 2800,
            proteinTarget: 160,
            carbTarget: 320,
            fatTarget: 75,
            waterTargetMl: 2800,
            expectedWeeklyWeightLossKg: nil,
            aggressiveness: .moderate
        )
        return profile
    }

    static var maintainProfile: UserProfile {
        var profile = loseProfile
        profile.currentWeightKg = 72
        profile.goalWeightKg = 72
        profile.targets = UserTargets(
            calorieTarget: 2400,
            proteinTarget: 150,
            carbTarget: 260,
            fatTarget: 70,
            waterTargetMl: 2700,
            expectedWeeklyWeightLossKg: nil,
            aggressiveness: .moderate
        )
        return profile
    }

    static var newUserProfile: UserProfile {
        UserProfile(
            id: UUID(uuidString: "B2B2B2B2-B2B2-B2B2-B2B2-B2B2B2B2B2B2")!,
            name: nil,
            birthDate: calendar.date(from: DateComponents(year: 2000, month: 7, day: 4)),
            age: 25,
            sex: .male,
            heightCm: 178,
            currentWeightKg: 82,
            goalWeightKg: 78,
            estimatedBodyFatPercentage: nil,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: 1,
            averageSteps: 5000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 2100,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2600,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    static var legacyAgeOnlyProfile: UserProfile {
        UserProfile(
            id: UUID(uuidString: "C3C3C3C3-C3C3-C3C3-C3C3-C3C3C3C3C3C3")!,
            name: "Legacy",
            birthDate: nil,
            age: 45,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 7500,
            dietPreference: nil,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 1800,
                proteinTarget: 130,
                carbTarget: 160,
                fatTarget: 55,
                waterTargetMl: 2400,
                expectedWeeklyWeightLossKg: 0.45,
                aggressiveness: .moderate
            ),
            createdAt: calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!,
            updatedAt: referenceDate
        )
    }

    // MARK: - Dashboards

    static func dashboard(
        for profile: UserProfile,
        weekLogs: [DailyLog] = [],
        weekWeights: [WeightEntry] = [],
        allWeights: [WeightEntry] = [],
        integrationState: TrainingIntegrationState = .notConnected
    ) -> PlanMissionControlDashboard {
        let context = PlanDashboardContext(
            profile: profile,
            weekLogs: weekLogs,
            weekWeights: weekWeights,
            allWeights: allWeights,
            weeklyTraining: .hidden,
            integrationState: integrationState,
            dataSource: .appleHealth,
            asOf: referenceDate,
            calendar: calendar
        )
        return PlanDashboardBuilder.missionControlDashboard(
            context: context,
            referenceDate: referenceDate
        )
    }

    static var loseDashboard: PlanMissionControlDashboard {
        dashboard(for: loseProfile)
    }

    static var gainDashboard: PlanMissionControlDashboard {
        dashboard(for: gainProfile)
    }

    static var maintainDashboard: PlanMissionControlDashboard {
        dashboard(for: maintainProfile)
    }

    static var newUserDashboard: PlanMissionControlDashboard {
        dashboard(for: newUserProfile)
    }

    static var activeUserDashboard: PlanMissionControlDashboard {
        let weights = activeWeightEntries
        return dashboard(
            for: loseProfile,
            weekLogs: activeWeekLogs,
            weekWeights: weights,
            allWeights: weights,
            integrationState: .connected
        )
    }

    static var incompleteDataDashboard: PlanMissionControlDashboard {
        dashboard(for: legacyAgeOnlyProfile)
    }

    // MARK: - Sample logs

    private static var activeWeightEntries: [WeightEntry] {
        let start = calendar.date(byAdding: .day, value: -21, to: referenceDate)!
        return [
            WeightEntry(id: UUID(), date: start, weightKg: 91.2, note: nil, createdAt: start),
            WeightEntry(
                id: UUID(),
                date: calendar.date(byAdding: .day, value: -14, to: referenceDate)!,
                weightKg: 90.8,
                note: nil,
                createdAt: calendar.date(byAdding: .day, value: -14, to: referenceDate)!
            ),
            WeightEntry(
                id: UUID(),
                date: calendar.date(byAdding: .day, value: -7, to: referenceDate)!,
                weightKg: 90.1,
                note: nil,
                createdAt: calendar.date(byAdding: .day, value: -7, to: referenceDate)!
            ),
            WeightEntry(id: UUID(), date: referenceDate, weightKg: 89.6, note: nil, createdAt: referenceDate)
        ]
    }

    private static var activeWeekLogs: [DailyLog] {
        (0..<5).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: referenceDate)!
            return DailyLog(
                id: UUID(),
                date: date,
                weightKg: nil,
                targets: loseProfile.targets,
                totals: MacroTotals(
                    calories: 2200,
                    protein: 170,
                    carbs: 175,
                    fat: 55,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: 3000,
                steps: nil,
                workoutCaloriesBurned: 0,
                dailyReviewId: nil,
                createdAt: date,
                updatedAt: date
            )
        }
    }
}
