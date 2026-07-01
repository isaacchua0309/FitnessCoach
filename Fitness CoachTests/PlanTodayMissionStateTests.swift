//
//  PlanTodayMissionStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanTodayMissionStateTests: XCTestCase {

    func testLoseTodayMissionFormatsAllMacrosFromStoredTargets() {
        let today = PlanMissionControlFixtures.loseDashboard.todayMission

        XCTAssertEqual(today.calorieTarget, 2233)
        XCTAssertEqual(today.caloriesLabel, "2233 kcal")
        XCTAssertEqual(today.proteinLabel, "180g protein")
        XCTAssertEqual(today.carbsLabel, "180g carbs")
        XCTAssertEqual(today.fatLabel, "58g fat")
        XCTAssertEqual(
            today.waterLabel,
            PlanTodayMissionStateBuilder.waterLabel(for: today.waterTargetMl)
        )
        XCTAssertEqual(today.sectionTitle, "Today's Mission")
        XCTAssertEqual(today.goToTodayTitle, "Go to Today")
    }

    func testTodayMissionProgressCopyUsesStoredWeeklyPace() {
        let today = PlanMissionControlFixtures.loseDashboard.todayMission

        XCTAssertEqual(
            today.progressCopy,
            "Designed for about 0.8 kg/week progress."
        )
    }

    func testGainTodayMissionUsesFallbackProgressCopyWithoutWeeklyPace() {
        let today = PlanMissionControlFixtures.gainDashboard.todayMission

        XCTAssertEqual(
            today.progressCopy,
            FormaProductCopy.PlanMissionControl.todayMissionProgressFallback(for: .gain)
        )
    }

    func testMaintainTodayMissionUsesFallbackProgressCopy() {
        let today = PlanMissionControlFixtures.maintainDashboard.todayMission

        XCTAssertEqual(
            today.progressCopy,
            FormaProductCopy.PlanMissionControl.todayMissionProgressFallback(for: .maintain)
        )
    }

    func testMissingTargetsUseUnavailableFallbackLabels() {
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
                calorieTarget: 0,
                proteinTarget: 0,
                carbTarget: 0,
                fatTarget: 0,
                waterTargetMl: 0,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            createdAt: Date(),
            updatedAt: Date()
        )

        let today = PlanTodayMissionStateBuilder.build(profile: profile)

        XCTAssertEqual(today.caloriesLabel, "—")
        XCTAssertEqual(today.proteinLabel, "—")
        XCTAssertEqual(today.carbsLabel, "—")
        XCTAssertEqual(today.fatLabel, "—")
        XCTAssertEqual(today.waterLabel, "—")
        XCTAssertEqual(
            today.progressCopy,
            FormaProductCopy.PlanMissionControl.todayMissionProgressFallback(for: .lose)
        )
    }

    func testAccessibilitySummaryIncludesAllMacroLines() {
        let today = PlanMissionControlFixtures.loseDashboard.todayMission

        XCTAssertTrue(today.accessibilitySummary.contains("Today's Mission"))
        XCTAssertTrue(today.accessibilitySummary.contains(today.caloriesLabel))
        XCTAssertTrue(today.accessibilitySummary.contains(today.waterLabel))
        XCTAssertTrue(today.accessibilitySummary.contains(today.progressCopy))
    }

    func testLitersCompactFormatsWaterForMissionCard() {
        XCTAssertEqual(PlanFormatter.litersCompact(3400), "3.4L")
        XCTAssertEqual(PlanFormatter.litersCompact(3150), "3.1L")
        XCTAssertEqual(
            PlanTodayMissionStateBuilder.waterLabel(for: 3150),
            "3.1L water"
        )
    }
}
