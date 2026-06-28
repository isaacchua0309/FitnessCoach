//
//  PlanRationaleVisualFlowTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanRationaleVisualFlowTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    // MARK: - Lose

    func testLoseVisualFlowShowsMaintenanceDeficitAndDailyTarget() throws {
        let profile = loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let rationale = PlanRationaleCopyBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        XCTAssertTrue(rationale.usesVisualFlowLayout)
        let steps = try XCTUnwrap(rationale.flowSteps)
        XCTAssertEqual(steps.map(\.id), ["maintenance", "adjustment", "target"])
        XCTAssertEqual(steps[0].label, "Estimated Maintenance")
        XCTAssertEqual(steps[1].label, "Healthy Deficit")
        XCTAssertEqual(steps[2].label, "Daily Target")
        XCTAssertTrue(steps[0].value.contains("kcal"))
        XCTAssertFalse(steps[0].value.contains("/day"))
    }

    func testLoseBasedOnIncludesBirthdayDerivedAgeAndActivityLevel() throws {
        let profile = loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let rationale = PlanRationaleCopyBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        let basedOn = try XCTUnwrap(rationale.basedOnItems)
        XCTAssertEqual(basedOn.map(\.id), ["age", "weight", "height", "sex", "activity", "goal"])
        XCTAssertEqual(basedOn[0].label, "Birthday-derived age")
        XCTAssertEqual(basedOn[0].value, "28 years")
        XCTAssertEqual(basedOn[4].label, "Activity level")
        XCTAssertEqual(basedOn[4].value, "Moderately active")
    }

    // MARK: - Gain

    func testGainVisualFlowShowsSurplusInsteadOfDeficit() throws {
        let profile = gainProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let rationale = PlanRationaleCopyBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        let steps = try XCTUnwrap(rationale.flowSteps)
        XCTAssertEqual(steps.first?.label, "Estimated Maintenance")
        XCTAssertEqual(steps.last?.label, "Daily Target")
        let surplus = max(result.calorieTargetKcal - result.tdeeKcal, 0)
        if surplus > 0 {
            XCTAssertEqual(steps.map(\.label), ["Estimated Maintenance", "Healthy Surplus", "Daily Target"])
        } else {
            XCTAssertEqual(steps.map(\.label), ["Estimated Maintenance", "Daily Target"])
        }
        XCTAssertFalse(steps.contains { $0.label == "Healthy Deficit" })
    }

    // MARK: - Maintain

    func testMaintainVisualFlowShowsMaintenanceTarget() throws {
        let profile = maintainProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let rationale = PlanRationaleCopyBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        let steps = try XCTUnwrap(rationale.flowSteps)
        XCTAssertEqual(steps.map(\.id), ["maintenance", "target"])
        XCTAssertEqual(steps[1].label, "Maintenance Target")
        XCTAssertFalse(steps.contains { $0.label == "Healthy Deficit" })
        XCTAssertFalse(steps.contains { $0.label == "Healthy Surplus" })
    }

    func testSeeCalculationCTAUsesFriendlyTitle() throws {
        let profile = loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let rationale = PlanRationaleCopyBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        XCTAssertEqual(rationale.seeCalculationTitle, "See calculation")
        XCTAssertNotNil(rationale.calculationDetails)
    }

    func testAccessibilitySummaryIncludesFlowAndBasedOnSections() throws {
        let profile = loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let rationale = PlanRationaleCopyBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        XCTAssertTrue(rationale.accessibilitySummary.contains("Why This Works"))
        XCTAssertTrue(rationale.accessibilitySummary.contains("Based on:"))
        XCTAssertTrue(rationale.accessibilitySummary.contains("Birthday-derived age"))
    }

    // MARK: - Fixtures

    private var loseProfile: UserProfile {
        UserProfile(
            id: UUID(),
            name: "Alex",
            birthDate: Calendar.current.date(from: DateComponents(year: 1998, month: 3, day: 15)),
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
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    private var gainProfile: UserProfile {
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

    private var maintainProfile: UserProfile {
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
}
