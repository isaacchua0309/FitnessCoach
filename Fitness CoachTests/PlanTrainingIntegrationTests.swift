//
//  PlanTrainingIntegrationTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanTrainingIntegrationTests: XCTestCase {

    // MARK: - Connected

    func testConnectedPresentationShowsCheckmarkAndInsightsCopy() {
        let presentation = PlanTrainingIntegrationPresentationBuilder.build(integrationState: .connected)

        XCTAssertEqual(presentation.sectionTitle, "Apple Health")
        XCTAssertTrue(presentation.showsStatusCheckmark)
        XCTAssertEqual(presentation.statusLabel, "Connected")
        XCTAssertEqual(presentation.bodyCopy, TrainingIntegrationCopy.planCardConnectedBody)
        XCTAssertNil(presentation.ctaTitle)
    }

    // MARK: - Disconnected

    func testNotConnectedPresentationShowsConnectCTA() {
        let presentation = PlanTrainingIntegrationPresentationBuilder.build(integrationState: .notConnected)

        XCTAssertFalse(presentation.showsStatusCheckmark)
        XCTAssertEqual(presentation.statusLabel, "Not connected")
        XCTAssertEqual(
            presentation.bodyCopy,
            TrainingIntegrationCopy.planCardDisconnectedBody
        )
        XCTAssertEqual(presentation.ctaTitle, "Connect Apple Health")
    }

    func testFailedPresentationFallsBackToDisconnectedCopyWhenMessageEmpty() {
        let presentation = PlanTrainingIntegrationPresentationBuilder.build(
            integrationState: .failed(message: "")
        )

        XCTAssertEqual(
            presentation.bodyCopy,
            TrainingIntegrationCopy.planCardDisconnectedBody
        )
        XCTAssertEqual(presentation.ctaTitle, "Connect Apple Health")
    }

    func testFailedPresentationUsesCustomMessageWhenProvided() {
        let presentation = PlanTrainingIntegrationPresentationBuilder.build(
            integrationState: .failed(message: "Network error")
        )

        XCTAssertEqual(presentation.bodyCopy, "Network error")
    }

    // MARK: - Denied

    func testDeniedPresentationShowsOpenSettingsCTA() {
        let presentation = PlanTrainingIntegrationPresentationBuilder.build(integrationState: .denied)

        XCTAssertFalse(presentation.showsStatusCheckmark)
        XCTAssertEqual(presentation.statusLabel, "Access denied")
        XCTAssertEqual(
            presentation.bodyCopy,
            "Turn on workout access in Health to improve activity insights."
        )
        XCTAssertEqual(presentation.ctaTitle, "Open Settings")
    }

    // MARK: - Unavailable

    func testUnavailablePresentationHasNoConnectCTA() {
        let presentation = PlanTrainingIntegrationPresentationBuilder.build(integrationState: .unavailable)

        XCTAssertEqual(presentation.statusLabel, "Unavailable")
        XCTAssertEqual(
            presentation.bodyCopy,
            "Apple Health is not available on this device."
        )
        XCTAssertNil(presentation.ctaTitle)
    }

    // MARK: - Requesting

    func testRequestingPresentationShowsConnectingCopy() {
        let presentation = PlanTrainingIntegrationPresentationBuilder.build(
            integrationState: .requestingPermission
        )

        XCTAssertEqual(presentation.statusLabel, "Connecting")
        XCTAssertEqual(presentation.bodyCopy, "Connecting to Apple Health…")
        XCTAssertNil(presentation.ctaTitle)
    }

    // MARK: - Guardrails

    func testPlanCardCopyDoesNotImplyAutomaticCalorieChanges() {
        let states: [TrainingIntegrationState] = [
            .connected,
            .notConnected,
            .denied,
            .unavailable,
            .requestingPermission,
            .failed(message: "")
        ]

        for state in states {
            let presentation = PlanTrainingIntegrationPresentationBuilder.build(integrationState: state)
            let combined = (
                [presentation.statusLabel, presentation.bodyCopy, presentation.ctaTitle]
                    .compactMap { $0 }
            ).joined(separator: " ").lowercased()

            XCTAssertFalse(combined.contains("calorie target"))
            XCTAssertFalse(combined.contains("automatically change"))
            XCTAssertFalse(combined.contains("auto-change"))
            XCTAssertFalse(combined.contains("dynamic calor"))
        }
    }

    func testAccessibilitySummaryIncludesStatusAndBody() {
        let presentation = PlanTrainingIntegrationPresentationBuilder.build(integrationState: .connected)

        XCTAssertTrue(presentation.accessibilitySummary.contains("Apple Health"))
        XCTAssertTrue(presentation.accessibilitySummary.contains("Connected"))
        XCTAssertTrue(presentation.accessibilitySummary.contains(presentation.bodyCopy))
    }
}
