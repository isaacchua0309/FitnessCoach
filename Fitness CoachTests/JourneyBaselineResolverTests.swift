//
//  JourneyBaselineResolverTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyBaselineResolverTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let referenceDate = ProfileTestFixtures.referenceDate

    // MARK: - Baseline weight resolution

    func testNoWeightEntryUsesProfileAsSyntheticBaseline() {
        let profile = ProfileTestFixtures.sampleProfile

        let baseline = resolve(profile: profile, weights: [], asOf: referenceDate)

        XCTAssertEqual(baseline.startWeightKg, profile.currentWeightKg)
        XCTAssertEqual(baseline.currentWeightKg, profile.currentWeightKg)
        XCTAssertFalse(baseline.hasRealWeightEntries)
        XCTAssertTrue(baseline.usesSyntheticBaselinePoint)
        XCTAssertTrue(baseline.showsWeightChart)
        XCTAssertFalse(baseline.chartPoints.isEmpty)
        XCTAssertTrue(baseline.chartPoints.allSatisfy(\.isSynthetic))
        XCTAssertEqual(baseline.chartPoints.first?.pointLabel, .onboarding)
    }

    func testOneWeightEntryAfterOnboardingAddsSyntheticLead() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 68

        let logDate = calendar.date(byAdding: .day, value: 7, to: referenceDate)!
        let weights = [
            makeWeight(date: logDate, weightKg: 66)
        ]

        let baseline = resolve(profile: profile, weights: weights, asOf: logDate)

        XCTAssertEqual(baseline.startWeightKg, 68)
        XCTAssertEqual(baseline.currentWeightKg, 66)
        XCTAssertTrue(baseline.usesSyntheticBaselinePoint)
        XCTAssertGreaterThanOrEqual(baseline.chartPoints.count, 2)

        let synthetic = baseline.chartPoints.first { $0.isSynthetic }
        XCTAssertEqual(synthetic?.weightKg, 68)
        XCTAssertEqual(synthetic?.pointLabel, .onboarding)

        let logged = baseline.chartPoints.first { !$0.isSynthetic }
        XCTAssertEqual(logged?.weightKg, 66)
        XCTAssertEqual(logged?.pointLabel, .logged)
    }

    func testTwoWeightEntriesUseEarliestLogAsStart() {
        let dayOne = referenceDate
        let dayTwo = calendar.date(byAdding: .day, value: 7, to: referenceDate)!
        let weights = [
            makeWeight(date: dayOne, weightKg: 68),
            makeWeight(date: dayTwo, weightKg: 66)
        ]

        let baseline = resolve(profile: ProfileTestFixtures.sampleProfile, weights: weights, asOf: dayTwo)

        XCTAssertEqual(baseline.startWeightKg, 68)
        XCTAssertEqual(baseline.currentWeightKg, 66)
        XCTAssertFalse(baseline.usesSyntheticBaselinePoint)
        XCTAssertEqual(baseline.chartPoints.filter { !$0.isSynthetic }.count, 2)
    }

    func testEditedProfileDoesNotCorruptBaselineWhenLogsExist() {
        let daySeven = calendar.date(byAdding: .day, value: 7, to: referenceDate)!
        let dayFourteen = calendar.date(byAdding: .day, value: 14, to: referenceDate)!
        let editedAt = calendar.date(byAdding: .day, value: 20, to: referenceDate)!

        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 72
        profile.updatedAt = editedAt

        let weights = [
            makeWeight(date: daySeven, weightKg: 66),
            makeWeight(date: dayFourteen, weightKg: 65)
        ]

        let baseline = resolve(profile: profile, weights: weights, asOf: editedAt)

        XCTAssertEqual(baseline.startWeightKg, 66)
        XCTAssertEqual(baseline.currentWeightKg, 65)
        XCTAssertNotEqual(baseline.startWeightKg, profile.currentWeightKg)
        XCTAssertNotEqual(baseline.currentWeightKg, profile.currentWeightKg)
    }

    // MARK: - Goal direction

    func testGoalDirectionLose() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 80
        profile.goalWeightKg = 70

        let baseline = resolve(profile: profile, weights: [], asOf: referenceDate)
        XCTAssertEqual(baseline.goalDirection, .lose)
    }

    func testGoalDirectionGain() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 60
        profile.goalWeightKg = 70

        let baseline = resolve(profile: profile, weights: [], asOf: referenceDate)
        XCTAssertEqual(baseline.goalDirection, .gain)
    }

    func testGoalDirectionMaintain() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 70
        profile.goalWeightKg = 70

        let baseline = resolve(profile: profile, weights: [], asOf: referenceDate)
        XCTAssertEqual(baseline.goalDirection, .maintain)
    }

    // MARK: - Progress percent

    func testProgressPercentLoseGoal() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.goalWeightKg = 80
        profile.currentWeightKg = 90

        let dayOne = referenceDate
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: referenceDate)!
        let weights = [
            makeWeight(date: dayOne, weightKg: 90),
            makeWeight(date: dayTwo, weightKg: 85)
        ]

        let baseline = resolve(profile: profile, weights: weights, asOf: dayTwo)

        XCTAssertEqual(baseline.progressPercent ?? 0, 50, accuracy: 0.1)
        XCTAssertEqual(baseline.totalChangeKg ?? 0, -5, accuracy: 0.01)
    }

    func testProgressPercentGainGoal() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 60
        profile.goalWeightKg = 70

        let dayOne = referenceDate
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: referenceDate)!
        let weights = [
            makeWeight(date: dayOne, weightKg: 60),
            makeWeight(date: dayTwo, weightKg: 65)
        ]

        let baseline = resolve(profile: profile, weights: weights, asOf: dayTwo)

        XCTAssertEqual(baseline.progressPercent ?? 0, 50, accuracy: 0.1)
    }

    func testProgressPercentNeverNegative() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 80
        profile.goalWeightKg = 70

        let dayOne = referenceDate
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: referenceDate)!
        let weights = [
            makeWeight(date: dayOne, weightKg: 80),
            makeWeight(date: dayTwo, weightKg: 82)
        ]

        let baseline = resolve(profile: profile, weights: weights, asOf: dayTwo)

        XCTAssertEqual(baseline.progressPercent, 0)
    }

    func testProgressPercentCapsAtOrAboveOneHundredWhenGoalExceeded() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 90
        profile.goalWeightKg = 75

        let dayOne = referenceDate
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: referenceDate)!
        let weights = [
            makeWeight(date: dayOne, weightKg: 90),
            makeWeight(date: dayTwo, weightKg: 70)
        ]

        let baseline = resolve(profile: profile, weights: weights, asOf: dayTwo)

        XCTAssertGreaterThanOrEqual(baseline.progressPercent ?? 0, 100)
    }

    func testMaintainGoalHasNoProgressPercentWhenStartMatchesGoal() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 70
        profile.goalWeightKg = 70

        let dayOne = referenceDate
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: referenceDate)!
        let weights = [
            makeWeight(date: dayOne, weightKg: 70),
            makeWeight(date: dayTwo, weightKg: 69.8)
        ]

        let baseline = resolve(profile: profile, weights: weights, asOf: dayTwo)

        XCTAssertEqual(baseline.goalDirection, .maintain)
        XCTAssertNil(baseline.progressPercent)
    }

    // MARK: - Chart points

    func testChartPointsInRangePreservesSyntheticLead() {
        let start = referenceDate
        let logDate = calendar.date(byAdding: .day, value: 30, to: referenceDate)!
        let rangeStart = calendar.date(byAdding: .day, value: 20, to: referenceDate)!

        let points = JourneyBaselineResolver.buildChartPoints(
            startDate: start,
            asOf: logDate,
            onboardingWeight: 68,
            startWeightKg: 68,
            currentWeightKg: 66,
            sortedWeights: [makeWeight(date: logDate, weightKg: 66)],
            calendar: calendar
        )

        let filtered = JourneyBaselineResolver.chartPointsInRange(
            points,
            from: rangeStart,
            to: logDate,
            calendar: calendar
        )

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.first?.isSynthetic == true)
        XCTAssertFalse(filtered.last?.isSynthetic == true)
    }

    // MARK: - Helpers

    private func resolve(
        profile: UserProfile,
        weights: [WeightEntry],
        asOf: Date
    ) -> JourneyBaseline {
        JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: profile,
                allWeights: weights,
                maturityLogs: [],
                goalProjection: nil,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func makeWeight(date: Date, weightKg: Double) -> WeightEntry {
        WeightEntry(
            id: UUID(),
            date: date,
            weightKg: weightKg,
            note: nil,
            createdAt: date
        )
    }
}
