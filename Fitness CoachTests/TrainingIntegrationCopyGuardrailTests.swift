//
//  TrainingIntegrationCopyGuardrailTests.swift
//  Fitness CoachTests
//
//  Pure copy/formatting guardrails for training integration states (no HealthKit).
//

import XCTest
@testable import Fitness_Coach

final class TrainingIntegrationCopyGuardrailTests: XCTestCase {

    func testSettingsDetailCopyAvoidsHealthKitTerminology() {
        for state in allStates {
            XCTAssertFalse(
                TrainingIntegrationCopy.settingsDetailDescription(for: state)
                    .localizedCaseInsensitiveContains("healthkit"),
                "Unexpected HealthKit term for state \(state)"
            )
        }
    }

    func testGateTitleAndMessagePerState() {
        XCTAssertEqual(TrainingIntegrationCopy.gateTitle(for: .unavailable), TrainingIntegrationCopy.unavailableTitle)
        XCTAssertEqual(TrainingIntegrationCopy.gateTitle(for: .denied), TrainingIntegrationCopy.deniedTitle)
        XCTAssertEqual(TrainingIntegrationCopy.gateTitle(for: .connected), TrainingIntegrationCopy.screenTitle)
        XCTAssertEqual(
            TrainingIntegrationCopy.gateMessage(for: .denied),
            TrainingIntegrationCopy.deniedMessage
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.gateMessage(for: .connected),
            TrainingIntegrationCopy.poweredByAppleFitness
        )
    }

    func testConnectButtonTitleOnlyWhenActionable() {
        XCTAssertEqual(
            TrainingIntegrationCopy.connectButtonTitle(for: .notConnected),
            TrainingIntegrationCopy.connectAppleHealth
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.connectButtonTitle(for: .denied),
            TrainingIntegrationCopy.openSettings
        )
        XCTAssertNil(TrainingIntegrationCopy.connectButtonTitle(for: .connected))
        XCTAssertNil(TrainingIntegrationCopy.connectButtonTitle(for: .unavailable))
    }

    func testFailedMessageFallsBackWhenEmpty() {
        XCTAssertEqual(
            TrainingIntegrationCopy.failedMessage(""),
            "We couldn't connect to Apple Health. Try again."
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.failedMessage("Custom failure"),
            "Custom failure"
        )
    }

    func testCoachWorkoutLogMessageSwitchesOnConnection() {
        XCTAssertEqual(
            TrainingIntegrationCopy.coachWorkoutLogMessage(isAppleHealthConnected: false),
            TrainingIntegrationCopy.coachWorkoutLogNotConnected
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.coachWorkoutLogMessage(isAppleHealthConnected: true),
            TrainingIntegrationCopy.coachWorkoutLogConnected
        )
    }

    func testPlanIntegrationMessageReflectsConnection() {
        XCTAssertEqual(
            TrainingIntegrationCopy.planIntegrationMessage(isAppleHealthConnected: true),
            TrainingIntegrationCopy.planConnectedNote
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.planIntegrationMessage(isAppleHealthConnected: false),
            TrainingIntegrationCopy.planConnectPrompt
        )
    }

    func testRequestingAndFailedDetailDescriptions() {
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsDetailDescription(for: .requestingPermission),
            TrainingIntegrationCopy.requestingMessage
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsDetailDescription(for: .failed(message: "Network error")),
            "Network error"
        )
    }

    private var allStates: [TrainingIntegrationState] {
        [
            .notConnected,
            .connected,
            .denied,
            .unavailable,
            .requestingPermission,
            .failed(message: "timeout")
        ]
    }
}
