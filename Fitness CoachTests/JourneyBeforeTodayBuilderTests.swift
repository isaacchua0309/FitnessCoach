//
//  JourneyBeforeTodayBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyBeforeTodayBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = ProfileTestFixtures.referenceDate

    func testFullDataAvailable() throws {
        let profile = ProfileTestFixtures.sampleProfile
        let startDate = calendar.date(byAdding: .day, value: -30, to: asOf)!
        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 86,
            goalWeight: 75,
            direction: .lose,
            startDate: startDate
        )

        let state = build(profile: profile, baseline: baseline)

        XCTAssertEqual(state.startedWeightKg, 90)
        XCTAssertEqual(state.currentWeightKg, 86)
        XCTAssertEqual(state.goalWeightKg, 75)
        XCTAssertTrue(state.showsMaintenanceRow)
        XCTAssertTrue(state.showsTargetRow)
        XCTAssertNotNil(state.startingMaintenanceCaloriesKcal)
        XCTAssertNotNil(state.currentMaintenanceCaloriesKcal)
        XCTAssertNotNil(state.startingTargetCaloriesKcal)
        XCTAssertEqual(state.currentTargetCaloriesKcal, profile.targets.calorieTarget)
        XCTAssertGreaterThan(state.daysOnJourney, 0)
    }

    func testMissingMaintenanceWhenProfileUnavailable() {
        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 86,
            goalWeight: 75,
            direction: .lose,
            startDate: asOf
        )

        let state = build(profile: nil, baseline: baseline)

        XCTAssertFalse(state.showsMaintenanceRow)
        XCTAssertNil(state.startingMaintenanceCaloriesKcal)
        XCTAssertNil(state.currentMaintenanceCaloriesKcal)
    }

    func testMissingTargetCaloriesWhenProfileHasNoTarget() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.targets = UserTargets(
            calorieTarget: 0,
            proteinTarget: profile.targets.proteinTarget,
            carbTarget: profile.targets.carbTarget,
            fatTarget: profile.targets.fatTarget,
            waterTargetMl: profile.targets.waterTargetMl,
            expectedWeeklyWeightLossKg: profile.targets.expectedWeeklyWeightLossKg,
            aggressiveness: profile.targets.aggressiveness
        )

        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 86,
            goalWeight: 75,
            direction: .lose,
            startDate: calendar.date(byAdding: .day, value: -14, to: asOf)!
        )

        let state = build(profile: profile, baseline: baseline)

        XCTAssertFalse(state.showsTargetRow)
        XCTAssertNil(state.currentTargetCaloriesKcal)
    }

    func testGainGoalUsesGoalWeight() {
        let profile = gainProfile()
        let baseline = makeBaseline(
            startWeight: 60,
            currentWeight: 63,
            goalWeight: 70,
            direction: .gain,
            startDate: calendar.date(byAdding: .day, value: -20, to: asOf)!
        )

        let state = build(profile: profile, baseline: baseline)

        XCTAssertEqual(state.goalWeightKg, 70)
        XCTAssertGreaterThan(state.currentWeightKg ?? 0, state.startedWeightKg ?? 0)
    }

    func testMaintainGoalSnapshot() {
        let profile = ProfileTestFixtures.sampleProfile
        let baseline = makeBaseline(
            startWeight: 72,
            currentWeight: 72.2,
            goalWeight: 72,
            direction: .maintain,
            startDate: calendar.date(byAdding: .day, value: -10, to: asOf)!
        )

        let state = build(profile: profile, baseline: baseline)

        XCTAssertEqual(state.goalWeightKg, 72)
        XCTAssertTrue(state.showsMaintenanceRow)
    }

    func testBaselineAndCurrentSameWeightStillBuildsSnapshot() {
        let profile = ProfileTestFixtures.sampleProfile
        let baseline = makeBaseline(
            startWeight: 82,
            currentWeight: 82,
            goalWeight: 74,
            direction: .lose,
            startDate: calendar.date(byAdding: .day, value: -7, to: asOf)!
        )

        let state = build(profile: profile, baseline: baseline)

        XCTAssertEqual(state.startedWeightKg, 82)
        XCTAssertEqual(state.currentWeightKg, 82)
        XCTAssertFalse(state.showsAdaptedTargetCopy)
    }

    func testAdaptedTargetCopyOnlyWhenTargetsDiffer() {
        let profile = ProfileTestFixtures.sampleProfile
        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 86,
            goalWeight: 75,
            direction: .lose,
            startDate: calendar.date(byAdding: .day, value: -30, to: asOf)!
        )

        let state = build(profile: profile, baseline: baseline)

        if state.showsTargetRow,
           let start = state.startingTargetCaloriesKcal,
           let current = state.currentTargetCaloriesKcal,
           abs(start - current) > 25 {
            XCTAssertTrue(state.showsAdaptedTargetCopy)
        } else {
            XCTAssertFalse(state.showsAdaptedTargetCopy)
        }
    }

    // MARK: - Helpers

    private func build(
        profile: UserProfile?,
        baseline: JourneyBaseline
    ) -> JourneyBeforeTodayState {
        JourneyBeforeTodayBuilder.build(
            JourneyBeforeTodayBuilder.Input(
                profile: profile,
                baseline: baseline,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func makeBaseline(
        startWeight: Double,
        currentWeight: Double,
        goalWeight: Double,
        direction: JourneyGoalDirection,
        startDate: Date
    ) -> JourneyBaseline {
        JourneyBaseline(
            startWeightKg: startWeight,
            startDate: startDate,
            currentWeightKg: currentWeight,
            goalWeightKg: goalWeight,
            goalDirection: direction,
            totalChangeKg: currentWeight - startWeight,
            remainingChangeKg: abs(currentWeight - goalWeight),
            progressPercent: 25,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: true,
            usesSyntheticBaselinePoint: false,
            onboardingBaselineWeightKg: startWeight,
            chartPoints: [],
            showsWeightChart: true
        )
    }

    private func gainProfile() -> UserProfile {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 63
        profile.goalWeightKg = 70
        return profile
    }
}
