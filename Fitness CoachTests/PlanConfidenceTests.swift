//
//  PlanConfidenceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanConfidenceTests: XCTestCase {

    // MARK: - New user

    func testNewUserHasModerateScoreWithMissingWeightAndLogs() {
        let confidence = PlanMissionControlFixtures.newUserDashboard.confidence

        XCTAssertEqual(confidence.sectionTitle, "Plan Confidence")
        XCTAssertGreaterThanOrEqual(confidence.confidenceScore, 50)
        XCTAssertLessThan(confidence.confidenceScore, 85)
        XCTAssertTrue(confidence.missingItems.contains { $0.text == "No recent weigh-in" })
        XCTAssertTrue(confidence.missingItems.contains { $0.text == "Not enough food logs yet" })
        XCTAssertFalse(confidence.whyItems.contains { $0.text == "Recent weight logged" })
        XCTAssertFalse(confidence.whyItems.contains { $0.text == "Consistent food logging" })
    }

    // MARK: - Complete profile

    func testCompleteProfileIncludesBirthdayHeightAndActivityReasons() {
        let confidence = PlanMissionControlFixtures.loseDashboard.confidence

        XCTAssertTrue(confidence.whyItems.contains { $0.text == "Activity level selected" })
        XCTAssertTrue(confidence.whyItems.contains { $0.text == "Birthday and height available" })
        XCTAssertTrue(confidence.whyItems.contains { $0.text == "Calorie targets look reasonable" })
        XCTAssertFalse(confidence.missingItems.contains { $0.text == "Birthday and height not fully set" })
    }

    func testIncompleteProfileSurfacesMissingBirthdayHeight() {
        let confidence = PlanMissionControlFixtures.incompleteDataDashboard.confidence

        XCTAssertTrue(confidence.missingItems.contains { $0.text == "Birthday and height not fully set" })
        XCTAssertFalse(confidence.whyItems.contains { $0.text == "Birthday and height available" })
    }

    // MARK: - Stale weight

    func testStaleWeightShowsMissingRecentWeighInWithPartialCredit() {
        let confidence = PlanMissionControlFixtures.staleWeightDashboard.confidence
        let noWeight = PlanMissionControlFixtures.noLogsDashboard.confidence

        XCTAssertTrue(confidence.missingItems.contains { $0.text == "No recent weigh-in" })
        XCTAssertFalse(confidence.whyItems.contains { $0.text == "Recent weight logged" })
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

    // MARK: - No logs

    func testNoLogsSurfacesMissingFoodLogsReason() {
        let confidence = PlanMissionControlFixtures.noLogsDashboard.confidence

        XCTAssertTrue(confidence.missingItems.contains { $0.text == "Not enough food logs yet" })
        XCTAssertFalse(confidence.whyItems.contains { $0.text == "Consistent food logging" })
    }

    // MARK: - Strong logging history

    func testStrongLoggingHistoryBoostsScoreWithConnectedSignals() {
        let confidence = PlanMissionControlFixtures.activeUserDashboard.confidence

        XCTAssertGreaterThanOrEqual(confidence.confidenceScore, 85)
        XCTAssertEqual(confidence.confidenceLevel, .high)
        XCTAssertTrue(confidence.whyItems.contains { $0.text == "Recent weight logged" })
        XCTAssertTrue(confidence.whyItems.contains { $0.text == "Consistent food logging" })
        XCTAssertTrue(confidence.whyItems.contains { $0.text == "Apple Health connected" })
        XCTAssertFalse(confidence.missingItems.contains { $0.text == "Not enough food logs yet" })
    }

    // MARK: - Tone & determinism

    func testConfidenceCopyIsExplanatoryNotMedical() {
        let confidence = PlanMissionControlFixtures.activeUserDashboard.confidence
        let combined = (
            confidence.whyItems.map(\.text)
                + confidence.missingItems.map(\.text)
                + [confidence.footerCopy]
        ).joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("diagnos"))
        XCTAssertFalse(combined.contains("clinical"))
        XCTAssertFalse(combined.contains("medical"))
    }

    func testScoreIsClampedAndFormatted() {
        let confidence = PlanMissionControlFixtures.activeUserDashboard.confidence

        XCTAssertTrue((0...100).contains(confidence.confidenceScore))
        XCTAssertEqual(confidence.scoreLabel, "\(confidence.confidenceScore)%")
        XCTAssertFalse(confidence.accessibilitySummary.isEmpty)
    }
}
