//
//  NoExistingProfileFoundTests.swift
//  Fitness CoachTests
//
//  Forma — No-existing-profile interstitial copy, analytics, and CTA policy.
//

import XCTest
@testable import Fitness_Coach

final class NoExistingProfileFoundCopyTests: XCTestCase {

    func testCopyMatchesProductSpec() {
        let copy = FormaProductCopy.PublicEntry.NoExistingPlan.self
        XCTAssertEqual(copy.title, "We couldn't find a Forma plan for this account")
        XCTAssertEqual(
            copy.subtitle,
            "This account doesn't have a saved plan yet. Let's build one now."
        )
        XCTAssertEqual(copy.supportingCopy, "New to Forma? This only takes about 2 minutes.")
        XCTAssertEqual(copy.startOnboardingCTA, "Start Onboarding")
        XCTAssertEqual(copy.useAnotherAccountCTA, "Use another account")
    }

    func testCopyDoesNotImplyAuthFailure() {
        let copy = FormaProductCopy.PublicEntry.NoExistingPlan.self
        XCTAssertFalse(copy.title.localizedCaseInsensitiveContains("sign in failed"))
        XCTAssertFalse(copy.title.localizedCaseInsensitiveContains("login failed"))
        XCTAssertFalse(copy.subtitle.localizedCaseInsensitiveContains("sign in failed"))
        XCTAssertFalse(copy.subtitle.localizedCaseInsensitiveContains("login failed"))
    }
}

final class NoExistingProfileFoundAnalyticsTests: XCTestCase {

    func testAnalyticsEventNames() {
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.noExistingProfileViewed.rawValue,
            "no_existing_profile_viewed"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.noExistingProfileStartOnboardingTapped.rawValue,
            "no_existing_profile_start_onboarding_tapped"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.noExistingProfileUseAnotherAccountTapped.rawValue,
            "no_existing_profile_use_another_account_tapped"
        )
    }

    func testRecordingLoggerCapturesViewAndCTAEvents() {
        let logger = RecordingNoExistingProfileAnalyticsLogger()
        logger.log(.noExistingProfileViewed, properties: PublicEntryAnalyticsProperties())
        logger.log(
            .noExistingProfileStartOnboardingTapped,
            properties: PublicEntryAnalyticsProperties()
        )
        logger.log(
            .noExistingProfileUseAnotherAccountTapped,
            properties: PublicEntryAnalyticsProperties()
        )

        XCTAssertEqual(
            logger.events,
            [
                .noExistingProfileViewed,
                .noExistingProfileStartOnboardingTapped,
                .noExistingProfileUseAnotherAccountTapped
            ]
        )
    }
}

final class NoExistingProfileFoundPolicyTests: XCTestCase {

    func testStartOnboardingUsesPostAuthEntryWhenSignedIn() {
        XCTAssertEqual(
            NoExistingProfileFoundPolicy.onboardingEntry(isSignedIn: true),
            .postAuth
        )
        XCTAssertEqual(OnboardingEntry.initialStep(for: .postAuth), .heightWeight)
    }

    func testStartOnboardingUsesPreAuthEntryWhenSignedOut() {
        XCTAssertEqual(
            NoExistingProfileFoundPolicy.onboardingEntry(isSignedIn: false),
            .preAuth
        )
        XCTAssertEqual(OnboardingEntry.initialStep(for: .preAuth), .introProof)
    }

    func testUseAnotherAccountReturnsToExistingUserSignIn() {
        XCTAssertEqual(
            NoExistingProfileFoundPolicy.useAnotherAccountDestination,
            .existingUserSignIn
        )
        XCTAssertEqual(
            PublicEntryRouteResolver.resolveSignedOutShell(
                PublicEntryRouteResolver.Input(
                    destination: NoExistingProfileFoundPolicy.useAnotherAccountDestination,
                    isOnboardingModelReady: false,
                    localProfileAwaitingSignIn: false,
                    hasPersistedOnboardingDraft: false,
                    hasLocalProfile: false,
                    pendingOnboardingCompletion: false,
                    signedOutWithProfilePolicy: .requireSignIn
                )
            ),
            .existingUserSignIn
        )
    }
}

private final class RecordingNoExistingProfileAnalyticsLogger: PublicEntryAnalyticsLogging {
    private(set) var events: [PublicEntryAnalyticsEvent] = []

    func log(_ event: PublicEntryAnalyticsEvent, properties: PublicEntryAnalyticsProperties) {
        events.append(event)
    }
}
