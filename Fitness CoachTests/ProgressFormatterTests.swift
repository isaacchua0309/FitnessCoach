//
//  ProgressFormatterTests.swift
//  Fitness CoachTests
//
//  Pure Journey / Progress display formatting (no SwiftUI, no services).
//

import XCTest
@testable import Fitness_Coach

final class ProgressFormatterTests: XCTestCase {

    private let referenceDate = ProfileTestFixtures.referenceDate

    func testNilValuesUseDashPlaceholders() {
        XCTAssertEqual(ProgressFormatter.compactKg(nil), "—")
        XCTAssertEqual(ProgressFormatter.kg(nil), "--")
        XCTAssertEqual(ProgressFormatter.kgChange(nil), "--")
        XCTAssertEqual(ProgressFormatter.grams(nil), "--")
        XCTAssertEqual(ProgressFormatter.kcal(nil), "--")
        XCTAssertEqual(ProgressFormatter.ml(nil), "--")
        XCTAssertEqual(ProgressFormatter.percent(nil), "--")
        XCTAssertEqual(ProgressFormatter.weeks(nil), "--")
        XCTAssertEqual(ProgressFormatter.date(nil), "--")
        XCTAssertEqual(ProgressFormatter.monthYear(nil), "—")
        XCTAssertEqual(ProgressFormatter.journeyKg(nil), "—")
    }

    func testWeightAndChangeFormatting() {
        XCTAssertEqual(ProgressFormatter.compactKg(68.4), "68.4 kg")
        XCTAssertEqual(ProgressFormatter.kg(68.45), "68.45 kg")
        XCTAssertEqual(ProgressFormatter.kgChange(-1.25), "-1.25 kg")
        XCTAssertEqual(ProgressFormatter.kgChange(0.5), "+0.50 kg")
    }

    func testGramsOmitsDecimalForWholeNumbers() {
        XCTAssertEqual(ProgressFormatter.grams(130), "130g")
        XCTAssertEqual(ProgressFormatter.grams(12.5), "12.5g")
    }

    func testJourneyKgAndDayCount() {
        XCTAssertEqual(ProgressFormatter.journeyKg(75), "75kg")
        XCTAssertEqual(ProgressFormatter.journeyKg(68.4), "68.4kg")
        XCTAssertEqual(ProgressFormatter.dayCount(1), "1 day")
        XCTAssertEqual(ProgressFormatter.dayCount(14), "14 days")
    }

    func testRemainingKgWithinToleranceReturnsNil() {
        XCTAssertNil(ProgressFormatter.remainingKg(current: 70, goal: 70.04))
        XCTAssertEqual(
            ProgressFormatter.remainingKg(current: 70, goal: 65),
            FormaProductCopy.Journey.remainingToGo("5kg")
        )
    }

    func testTrendDirectionAndConfidenceLabels() {
        XCTAssertEqual(ProgressFormatter.trendDirection(.decreasing), "Decreasing")
        XCTAssertEqual(ProgressFormatter.trendDirection(.insufficientData), "Need more data")
        XCTAssertEqual(ProgressFormatter.confidence(.high), "High confidence")
        XCTAssertEqual(ProgressFormatter.shortConfidence(.low), "Low")
    }

    func testNextMilestoneSkipsCurrentToUpcoming() {
        let milestones = [
            JourneyMilestone(id: "m0", weightKg: 90, status: .current),
            JourneyMilestone(id: "m1", weightKg: 86, status: .upcoming),
            JourneyMilestone(id: "m2", weightKg: 82, status: .upcoming)
        ]

        XCTAssertEqual(ProgressFormatter.nextMilestone(from: milestones)?.id, "m1")
    }

    func testNextMilestoneFallsBackToFirstUpcomingWhenNoCurrent() {
        let milestones = [
            JourneyMilestone(id: "m0", weightKg: 90, status: .completed),
            JourneyMilestone(id: "m1", weightKg: 86, status: .upcoming)
        ]

        XCTAssertEqual(ProgressFormatter.nextMilestone(from: milestones)?.id, "m1")
    }

    func testPercentAndDateFormatting() {
        XCTAssertEqual(ProgressFormatter.percent(0.456), "46%")
        XCTAssertEqual(ProgressFormatter.kcal(1800), "1800 kcal")
        XCTAssertEqual(ProgressFormatter.ml(2400), "2400 ml")
        XCTAssertFalse(ProgressFormatter.date(referenceDate).isEmpty)
    }
}
