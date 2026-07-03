//
//  PlanConfidenceStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanConfidenceStateTests: XCTestCase {

    func testLowConfidenceBucket() {
        XCTAssertEqual(PlanConfidenceStateBuilder.estimateBucket(for: 38), .low)
        XCTAssertEqual(
            FormaProductCopy.PlanMissionControl.planConfidenceScoreHeadline(score: 38, bucket: .low),
            "38% — Low estimate"
        )
    }

    func testGoodConfidence() {
        let confidence = PlanMissionControlFixtures.newUserDashboard.confidence

        XCTAssertEqual(confidence.sectionTitle, "Plan Confidence")
        XCTAssertEqual(confidence.estimateBucket, .good)
        XCTAssertEqual(confidence.confidenceScore, 68)
        XCTAssertEqual(confidence.scoreHeadline, "68% — Good estimate")
    }

    func testAppleHealthConnectedSignal() {
        let confidence = PlanMissionControlFixtures.connectedDashboard.confidence
        let appleHealth = confidence.compactSignals.first { $0.id == "appleHealth" }

        XCTAssertEqual(appleHealth?.label, "Apple Health")
        XCTAssertEqual(appleHealth?.value, "Connected")
        XCTAssertFalse(confidence.showsAppleHealthAction)
    }

    func testMissingWeighInRecommendation() {
        let confidence = PlanMissionControlFixtures.newUserDashboard.confidence

        XCTAssertTrue(
            confidence.improvementActions.contains {
                $0.text == FormaProductCopy.PlanMissionControl.planConfidenceActionLogWeight
            }
        )
        XCTAssertEqual(
            confidence.compactSignals.first { $0.id == "weighIn" }?.value,
            "No"
        )
    }

    func testMissingFoodLogsRecommendation() {
        let confidence = PlanMissionControlFixtures.newUserDashboard.confidence

        XCTAssertTrue(
            confidence.improvementActions.contains {
                $0.text == FormaProductCopy.PlanMissionControl.planConfidenceActionLogMeals
            }
        )
        XCTAssertEqual(
            confidence.compactSignals.first { $0.id == "foodLogs" }?.value,
            "Not enough"
        )
    }

    func testStrongConfidenceOmitsRoutineImprovementActions() {
        let confidence = PlanMissionControlFixtures.activeUserDashboard.confidence

        XCTAssertEqual(confidence.estimateBucket, .strong)
        XCTAssertGreaterThanOrEqual(confidence.confidenceScore, 85)
        XCTAssertFalse(
            confidence.improvementActions.contains {
                $0.text == FormaProductCopy.PlanMissionControl.planConfidenceActionLogWeight
            }
        )
        XCTAssertFalse(
            confidence.improvementActions.contains {
                $0.text == FormaProductCopy.PlanMissionControl.planConfidenceActionLogMeals
            }
        )
        XCTAssertEqual(
            confidence.compactSignals.first { $0.id == "weighIn" }?.value,
            "Yes"
        )
        XCTAssertEqual(
            confidence.compactSignals.first { $0.id == "foodLogs" }?.value,
            "Enough"
        )
    }

    func testDisconnectedAppleHealthSurfacesConnectAction() {
        let confidence = PlanMissionControlFixtures.loseDashboard.confidence

        XCTAssertTrue(confidence.showsAppleHealthAction)
        XCTAssertEqual(confidence.appleHealthActionTitle, TrainingIntegrationCopy.connectAppleHealth)
        XCTAssertEqual(
            confidence.compactSignals.first { $0.id == "appleHealth" }?.value,
            "Not connected"
        )
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

    func testConfidenceCopyIsExplanatoryNotMedical() {
        let confidence = PlanMissionControlFixtures.activeUserDashboard.confidence
        let combined = (
            [confidence.scoreHeadline, confidence.improveAccuracyHeading, confidence.compactSignalsHeading]
                + confidence.improvementActions.map(\.text)
                + confidence.compactSignals.map { "\($0.label) \($0.value)" }
        ).joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("diagnos"))
        XCTAssertFalse(combined.contains("clinical"))
        XCTAssertNil(PlanCopySafetyPolicy.forbiddenViolation(in: combined))
    }

    func testImprovementActionsAreCappedAtThree() {
        let confidence = PlanMissionControlFixtures.incompleteDataDashboard.confidence

        XCTAssertLessThanOrEqual(confidence.improvementActions.count, 3)
        XCTAssertFalse(confidence.accessibilitySummary.isEmpty)
    }
}
