//
//  PlanDailyTargetsStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanDailyTargetsStateTests: XCTestCase {

    func testTargetsRenderCorrectly() {
        let targets = PlanMissionControlFixtures.loseDashboard.dailyTargets

        XCTAssertEqual(targets.sectionTitle, "Daily Targets")
        XCTAssertEqual(targets.caloriesLabel, "2233 kcal")
        XCTAssertEqual(targets.proteinLabel, "180g protein")
        XCTAssertEqual(targets.carbsLabel, "180g carbs")
        XCTAssertEqual(targets.fatLabel, "58g fat")
        XCTAssertEqual(targets.waterLabel, "3.1L water")
        XCTAssertEqual(targets.trainingTargetLabel, "3 training sessions/week")
        XCTAssertEqual(targets.prescriptionCopy, "Built for fat loss while preserving muscle.")
        XCTAssertEqual(targets.goToTodayTitle, "Go to Today")
    }

    func testMissingMacroFallback() {
        let profile = UserProfile(
            id: UUID(),
            name: "Test",
            birthDate: nil,
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 70,
            goalWeightKg: 65,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 0,
            averageSteps: 6000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 0,
                proteinTarget: 0,
                carbTarget: 0,
                fatTarget: 0,
                waterTargetMl: 3150,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            createdAt: Date(),
            updatedAt: Date()
        )

        let targets = DailyTargetsStateBuilder.build(profile: profile)

        XCTAssertEqual(targets.caloriesLabel, "—")
        XCTAssertEqual(targets.proteinLabel, "—")
        XCTAssertEqual(targets.carbsLabel, "—")
        XCTAssertEqual(targets.fatLabel, "—")
        XCTAssertEqual(targets.waterLabel, "3.1L water")
    }

    func testWaterTargetFallback() {
        let profile = UserProfile(
            id: UUID(),
            name: "Test",
            birthDate: nil,
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 70,
            goalWeightKg: 65,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 6000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 2000,
                proteinTarget: 150,
                carbTarget: 180,
                fatTarget: 60,
                waterTargetMl: 0,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            createdAt: Date(),
            updatedAt: Date()
        )

        let targets = DailyTargetsStateBuilder.build(profile: profile)

        XCTAssertEqual(targets.waterLabel, "—")
        XCTAssertEqual(targets.caloriesLabel, "2000 kcal")
    }

    func testNoDailyCompletionStateAppears() {
        let targets = PlanMissionControlFixtures.loseDashboard.dailyTargets
        let encoded = [
            targets.caloriesLabel,
            targets.proteinLabel,
            targets.carbsLabel,
            targets.fatLabel,
            targets.waterLabel,
            targets.prescriptionCopy,
            targets.accessibilitySummary
        ].joined(separator: " ").lowercased()

        XCTAssertFalse(encoded.contains("remaining"))
        XCTAssertFalse(encoded.contains("consumed"))
        XCTAssertFalse(encoded.contains("logged"))
        XCTAssertFalse(encoded.contains("complete"))
        XCTAssertFalse(encoded.contains("progress"))
    }

    func testTrainingTargetHiddenWhenNoSessionsConfigured() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.trainingFrequencyPerWeek = 0

        let targets = DailyTargetsStateBuilder.build(profile: profile)

        XCTAssertNil(targets.trainingTargetLabel)
    }

    func testAccessibilitySummaryIncludesPrescriptionTargets() {
        let targets = PlanMissionControlFixtures.loseDashboard.dailyTargets

        XCTAssertTrue(targets.accessibilitySummary.contains("Daily Targets"))
        XCTAssertTrue(targets.accessibilitySummary.contains(targets.caloriesLabel))
        XCTAssertTrue(targets.accessibilitySummary.contains(targets.waterLabel))
        XCTAssertTrue(targets.accessibilitySummary.contains(targets.prescriptionCopy))
    }

    func testLitersCompactFormatsWaterTarget() {
        XCTAssertEqual(PlanFormatter.litersCompact(3400), "3.4L")
        XCTAssertEqual(PlanFormatter.litersCompact(3150), "3.1L")
        XCTAssertEqual(
            DailyTargetsStateBuilder.waterLabel(for: 3150),
            "3.1L water"
        )
    }
}
