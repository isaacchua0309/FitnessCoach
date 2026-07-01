//
//  JourneyFormatterTests.swift
//  Fitness CoachTests
//
//  Pure Journey display formatting (no SwiftUI, no services).
//

import XCTest
@testable import Fitness_Coach

final class JourneyFormatterTests: XCTestCase {

    private let referenceDate = ProfileTestFixtures.referenceDate

    func testNilValuesUseDashPlaceholders() {
        XCTAssertEqual(JourneyFormatter.compactKg(nil), "—")
        XCTAssertEqual(JourneyFormatter.kg(nil), "--")
        XCTAssertEqual(JourneyFormatter.kgChange(nil), "--")
        XCTAssertEqual(JourneyFormatter.grams(nil), "--")
        XCTAssertEqual(JourneyFormatter.kcal(nil), "--")
        XCTAssertEqual(JourneyFormatter.ml(nil), "--")
        XCTAssertEqual(JourneyFormatter.percent(nil), "--")
        XCTAssertEqual(JourneyFormatter.weeks(nil), "--")
        XCTAssertEqual(JourneyFormatter.date(nil), "--")
        XCTAssertEqual(JourneyFormatter.monthYear(nil), "—")
        XCTAssertEqual(JourneyFormatter.journeyKg(nil), "—")
    }

    func testWeightAndChangeFormatting() {
        XCTAssertEqual(JourneyFormatter.compactKg(68.4), "68.4 kg")
        XCTAssertEqual(JourneyFormatter.kg(68.45), "68.45 kg")
        XCTAssertEqual(JourneyFormatter.kgChange(-1.25), "-1.25 kg")
        XCTAssertEqual(JourneyFormatter.kgChange(0.5), "+0.50 kg")
    }

    func testGramsOmitsDecimalForWholeNumbers() {
        XCTAssertEqual(JourneyFormatter.grams(130), "130g")
        XCTAssertEqual(JourneyFormatter.grams(12.5), "12.5g")
    }

    func testJourneyKgAndDayCount() {
        XCTAssertEqual(JourneyFormatter.journeyKg(75), "75kg")
        XCTAssertEqual(JourneyFormatter.journeyKg(68.4), "68.4kg")
        XCTAssertEqual(JourneyFormatter.dayCount(1), "1 day")
        XCTAssertEqual(JourneyFormatter.dayCount(14), "14 days")
    }

    func testRemainingKgWithinToleranceReturnsNil() {
        XCTAssertNil(JourneyFormatter.remainingKg(current: 70, goal: 70.04))
        XCTAssertEqual(
            JourneyFormatter.remainingKg(current: 70, goal: 65),
            FormaProductCopy.Journey.Transformation.remainingToGo("5kg")
        )
    }

    func testTrendDirectionAndConfidenceLabels() {
        XCTAssertEqual(JourneyFormatter.trendDirection(.decreasing), "Decreasing")
        XCTAssertEqual(JourneyFormatter.trendDirection(.insufficientData), "Need more data")
        XCTAssertEqual(JourneyFormatter.confidence(.high), "High confidence")
        XCTAssertEqual(JourneyFormatter.shortConfidence(.low), "Low")
    }

    func testNextMilestoneSkipsCurrentToUpcoming() {
        let milestones = [
            JourneyMilestone(id: "m0", title: "Start", status: .current, weightKg: 90),
            JourneyMilestone(id: "m1", title: "Next", status: .upcoming, weightKg: 86),
            JourneyMilestone(id: "m2", title: "Goal", status: .upcoming, weightKg: 82)
        ]

        XCTAssertEqual(JourneyFormatter.nextMilestone(from: milestones)?.id, "m1")
    }

    func testNextMilestoneFallsBackToFirstUpcomingWhenNoCurrent() {
        let milestones = [
            JourneyMilestone(id: "m0", title: "Start", status: .completed, weightKg: 90),
            JourneyMilestone(id: "m1", title: "Next", status: .upcoming, weightKg: 86)
        ]

        XCTAssertEqual(JourneyFormatter.nextMilestone(from: milestones)?.id, "m1")
    }

    func testPercentAndDateFormatting() {
        XCTAssertEqual(JourneyFormatter.percent(0.456), "46%")
        XCTAssertEqual(JourneyFormatter.kcal(1800), "1800 kcal")
        XCTAssertEqual(JourneyFormatter.ml(2400), "2400 ml")
        XCTAssertFalse(JourneyFormatter.date(referenceDate).isEmpty)
    }
}
