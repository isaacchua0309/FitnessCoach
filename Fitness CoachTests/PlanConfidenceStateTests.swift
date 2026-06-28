//
//  PlanConfidenceStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanConfidenceStateTests: XCTestCase {

    func testNewUserHasModerateScoreWithMissingWeightAndLogs() {
        let confidence = PlanMissionControlFixtures.newUserDashboard.confidence

        XCTAssertEqual(confidence.sectionTitle, "Plan Confidence")
        XCTAssertGreaterThanOrEqual(confidence.confidenceScore, 50)
        XCTAssertLessThan(confidence.confidenceScore, 85)
        XCTAssertTrue(confidence.missingItems.contains { $0.text == "No recent weigh-in" })
        XCTAssertTrue(confidence.missingItems.contains { $0.text == "Not enough food logs yet" })
    }

    func testCompleteProfileIncludesBirthdayHeightAndActivityReasons() {
        let confidence = PlanMissionControlFixtures.loseDashboard.confidence

        XCTAssertTrue(confidence.whyItems.contains { $0.text == "Activity level selected" })
        XCTAssertTrue(confidence.whyItems.contains { $0.text == "Birthday and height available" })
        let targetWhyCopy = [
            FormaProductCopy.PlanMissionControl.confidenceTargetsReasonable,
            FormaProductCopy.PlanMissionControl.confidenceTargetsGuardrailed
        ]
        XCTAssertTrue(
            confidence.whyItems.contains { targetWhyCopy.contains($0.text) },
            "Expected calculated targets in why items, got: \(confidence.whyItems.map(\.text))"
        )
    }

    func testIncompleteProfileSurfacesMissingBirthdayHeight() {
        let confidence = PlanMissionControlFixtures.incompleteDataDashboard.confidence

        XCTAssertTrue(confidence.missingItems.contains { $0.text == "Birthday and height not fully set" })
    }

    func testStaleWeightShowsMissingRecentWeighInWithPartialCredit() {
        let confidence = PlanMissionControlFixtures.staleWeightDashboard.confidence
        let noWeight = PlanMissionControlFixtures.noLogsDashboard.confidence

        XCTAssertTrue(confidence.missingItems.contains { $0.text == "No recent weigh-in" })
        XCTAssertGreaterThan(confidence.confidenceScore, noWeight.confidenceScore)
    }

    func testHasRecentWeightLogWithinWindow() {
        let referenceDate = Calendar.current.date(
            from: DateComponents(year: 2026, month: 6, day: 28)
        )!
        let recent = WeightEntry(
            id: UUID(),
            date: referenceDate,
            weightKg: 80,
            note: nil,
            createdAt: referenceDate
        )

        XCTAssertTrue(
            PlanConfidenceStateBuilder.hasRecentWeightLog(
                in: [recent],
                asOf: referenceDate,
                calendar: .current
            )
        )
    }

    func testStrongLoggingHistoryBoostsScoreWithConnectedSignals() {
        let confidence = PlanMissionControlFixtures.activeUserDashboard.confidence

        XCTAssertGreaterThanOrEqual(confidence.confidenceScore, 85)
        XCTAssertEqual(confidence.confidenceLevel, .high)
        XCTAssertTrue(confidence.whyItems.contains { $0.text == "Apple Health connected" })
    }

    func testConfidenceCopyIsExplanatoryNotMedical() {
        let confidence = PlanMissionControlFixtures.activeUserDashboard.confidence
        let combined = (
            confidence.whyItems.map(\.text)
                + confidence.missingItems.map(\.text)
                + [confidence.footerCopy]
        ).joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("diagnos"))
        XCTAssertFalse(combined.contains("clinical"))
        XCTAssertNil(PlanCopySafetyPolicy.forbiddenViolation(in: combined))
    }

    func testScoreIsClampedAndFormatted() {
        let confidence = PlanMissionControlFixtures.activeUserDashboard.confidence

        XCTAssertTrue((0...100).contains(confidence.confidenceScore))
        XCTAssertEqual(
            confidence.scoreLabel,
            FormaProductCopy.PlanMissionControl.planConfidenceScore(confidence.confidenceScore)
        )
        XCTAssertTrue(confidence.scoreLabel.hasPrefix("Plan confidence:"))
        XCTAssertFalse(confidence.accessibilitySummary.isEmpty)
    }
}
