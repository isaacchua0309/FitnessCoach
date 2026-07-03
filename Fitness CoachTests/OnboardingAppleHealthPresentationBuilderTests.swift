//
//  OnboardingAppleHealthPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Apple Health onboarding presentation builder tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingAppleHealthPresentationBuilderTests: XCTestCase {

    func testNotDeterminedStateUsesConnectCTAAndSkip() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .notDetermined,
            deviceState: .notConnected
        )

        XCTAssertEqual(state.presentation, .notDetermined)
        XCTAssertEqual(state.primaryTitle, FormaProductCopy.Onboarding.Flow.AppleHealth.connectCTA)
        XCTAssertEqual(state.skipTitle, FormaProductCopy.Onboarding.Flow.AppleHealth.skipCTA)
        XCTAssertNil(state.statusMessage)
        XCTAssertTrue(state.isPrimaryEnabled)
        XCTAssertTrue(state.showsSkipButton)
        XCTAssertEqual(state.primaryAction, .requestPermission)
        XCTAssertTrue(state.showsHeroIcon)
        XCTAssertTrue(state.showsPermissionCard)
    }

    func testUnavailableDeviceUsesContinueCTAAndHidesPermissionCard() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .notDetermined,
            deviceState: .unavailable
        )

        XCTAssertEqual(state.presentation, .unavailable)
        XCTAssertEqual(state.primaryTitle, FormaProductCopy.Onboarding.Flow.AppleHealth.continueCTA)
        XCTAssertTrue(state.isPrimaryEnabled)
        XCTAssertFalse(state.showsSkipButton)
        XCTAssertEqual(state.primaryAction, .advance)
        XCTAssertFalse(state.showsPermissionCard)
        XCTAssertEqual(state.statusMessage, FormaProductCopy.Onboarding.Flow.AppleHealth.unavailableMessage)
    }

    func testDeniedStateUsesContinueAndHidesSkip() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .denied,
            deviceState: .denied
        )

        XCTAssertEqual(state.statusMessage, FormaProductCopy.Onboarding.Flow.AppleHealth.deniedMessage)
        XCTAssertEqual(state.primaryTitle, FormaProductCopy.Onboarding.Flow.AppleHealth.continueCTA)
        XCTAssertTrue(state.isPrimaryEnabled)
        XCTAssertFalse(state.showsSkipButton)
        XCTAssertEqual(state.primaryAction, .advance)
    }

    func testConnectedStateUsesContinueCTAAndHidesSkip() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .connected,
            deviceState: .connected
        )

        XCTAssertEqual(state.presentation, .connected)
        XCTAssertEqual(state.primaryTitle, FormaProductCopy.Common.continueAction)
        XCTAssertEqual(state.statusMessage, FormaProductCopy.Onboarding.Flow.AppleHealth.connectedMessage)
        XCTAssertTrue(state.isPrimaryEnabled)
        XCTAssertFalse(state.showsSkipButton)
        XCTAssertEqual(state.primaryAction, .advance)
        XCTAssertFalse(state.showsHeroIcon)
    }

    func testConnectedPresentationRequiresDeviceReadAccess() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .connected,
            deviceState: .notConnected
        )

        XCTAssertEqual(state.presentation, .notDetermined)
        XCTAssertEqual(state.primaryAction, .requestPermission)
        XCTAssertTrue(state.showsSkipButton)
    }

    func testRequestingPresentationReconcilesToDeniedAfterRefresh() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .requesting,
            deviceState: .denied
        )

        XCTAssertEqual(state.presentation, .denied)
        XCTAssertEqual(state.primaryAction, .advance)
        XCTAssertTrue(state.isPrimaryEnabled)
    }

    func testRequestingStateDisablesPrimaryCTAAndSkip() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .requesting,
            deviceState: .requestingPermission
        )

        XCTAssertFalse(state.isPrimaryEnabled)
        XCTAssertFalse(state.showsSkipButton)
        XCTAssertEqual(state.heroStyle, .loading)
    }

    func testFailedStateAllowsRetryAndSkip() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .failed(message: "HealthKit unavailable"),
            deviceState: .failed(message: "HealthKit unavailable")
        )

        XCTAssertEqual(state.statusMessage, FormaProductCopy.Onboarding.Flow.AppleHealth.failedMessage)
        XCTAssertTrue(state.isPrimaryEnabled)
        XCTAssertTrue(state.showsSkipButton)
        XCTAssertEqual(state.primaryAction, .requestPermission)
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
            presentation: .notDetermined,
            deviceState: .notConnected
        )

        XCTAssertEqual(
            state.accessibilitySummary,
            "Connect Apple Health. Optional. Sync workouts and activity so Forma can adjust your plan with less manual tracking."
        )
    }
}
