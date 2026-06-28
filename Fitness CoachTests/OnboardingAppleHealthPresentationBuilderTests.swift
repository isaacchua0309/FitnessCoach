//
//  OnboardingAppleHealthPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Apple Health onboarding presentation builder tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingAppleHealthPresentationBuilderTests: XCTestCase {

    func testReadyStateUsesConnectCTA() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .ready,
            deviceState: .notConnected
        )

        XCTAssertEqual(state.primaryTitle, FormaProductCopy.Onboarding.Flow.AppleHealth.connectCTA)
        XCTAssertEqual(state.secondaryTitle, FormaProductCopy.Onboarding.Flow.AppleHealth.skipCTA)
        XCTAssertNil(state.statusMessage)
        XCTAssertTrue(state.isPrimaryEnabled)
        XCTAssertTrue(state.isSkipEnabled)
    }

    func testUnavailableDeviceDisablesPrimaryAndShowsMessage() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .ready,
            deviceState: .unavailable
        )

        XCTAssertEqual(state.presentation, .unavailable)
        XCTAssertEqual(state.primaryTitle, FormaProductCopy.Onboarding.Flow.AppleHealth.unavailableCTA)
        XCTAssertFalse(state.isPrimaryEnabled)
        XCTAssertTrue(state.isSkipEnabled)
        XCTAssertEqual(state.statusMessage, FormaProductCopy.Onboarding.Flow.AppleHealth.unavailableMessage)
    }

    func testDeniedStateAllowsRetryAndSkip() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .denied,
            deviceState: .denied
        )

        XCTAssertEqual(state.statusMessage, FormaProductCopy.Onboarding.Flow.AppleHealth.deniedMessage)
        XCTAssertTrue(state.isPrimaryEnabled)
        XCTAssertTrue(state.isSkipEnabled)
    }

    func testFailedStateShowsRetryMessage() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .failed(message: "HealthKit unavailable"),
            deviceState: .failed(message: "HealthKit unavailable")
        )

        XCTAssertEqual(state.statusMessage, FormaProductCopy.Onboarding.Flow.AppleHealth.failedMessage)
        XCTAssertTrue(state.isPrimaryEnabled)
    }

    func testCopyAvoidsDynamicCaloriesAndAutomaticAdjustmentClaims() {
        let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self
        let joined = [
            copy.title,
            copy.subtitle,
            copy.privacyBody,
            copy.connectedMessage,
            copy.deniedMessage,
            copy.unavailableMessage,
            copy.failedMessage,
            copy.summaryCardTitle
        ].joined(separator: " ")
            + copy.readableDataRows.joined(separator: " ")

        XCTAssertFalse(joined.localizedCaseInsensitiveContains("dynamic calories"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("automatic calorie"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("automatically change"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("calorie target"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("required"))
    }

    func testAccessibilitySummaryAnnouncesOptionalConnection() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .ready,
            deviceState: .notConnected
        )

        XCTAssertEqual(
            state.accessibilitySummary,
            "Connect Apple Health. Optional. Sync workouts and activity to improve your progress insights."
        )
    }
}
