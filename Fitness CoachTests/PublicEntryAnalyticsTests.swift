//
//  PublicEntryAnalyticsTests.swift
//  Fitness CoachTests
//
//  Forma — Public entry analytics events, properties, and privacy guardrails.
//

import XCTest
@testable import Fitness_Coach

final class PublicEntryAnalyticsEventTests: XCTestCase {

    func testPublicEntryAnalyticsEventNames() {
        XCTAssertEqual(PublicEntryAnalyticsEvent.welcomeViewed.rawValue, "public_welcome_viewed")
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.welcomeCreatePlanTapped.rawValue,
            "public_welcome_create_plan_tapped"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.welcomeSignInTapped.rawValue,
            "public_welcome_sign_in_tapped"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInViewed.rawValue,
            "existing_sign_in_viewed"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInStarted.rawValue,
            "existing_sign_in_started"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInSucceeded.rawValue,
            "existing_sign_in_succeeded"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInFailed.rawValue,
            "existing_sign_in_failed"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInNoProfileFound.rawValue,
            "existing_sign_in_no_profile_found"
        )
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
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.logoutCompletedPublicEntryShown.rawValue,
            "logout_completed_public_entry_shown"
        )
    }
}

final class PublicEntryAnalyticsContextBuilderTests: XCTestCase {

    func testBasePropertiesIncludeAuthProviderAndLocalProfileFlag() {
        let properties = PublicEntryAnalyticsContextBuilder.baseProperties(hasLocalProfile: true)
        XCTAssertEqual(properties.asParameters()["auth_provider"], "google")
        XCTAssertEqual(properties.asParameters()["has_local_profile"], "true")
    }

    func testProfileResolutionResultMapping() {
        XCTAssertEqual(
            PublicEntryAnalyticsContextBuilder.analyticsValue(
                for: .profileFound(.cloudRestored)
            ),
            PublicEntryAnalyticsProfileResolution.profileFoundCloud.rawValue
        )
        XCTAssertEqual(
            PublicEntryAnalyticsContextBuilder.analyticsValue(
                for: .profileFound(.localOwned)
            ),
            PublicEntryAnalyticsProfileResolution.profileFoundLocal.rawValue
        )
        XCTAssertEqual(
            PublicEntryAnalyticsContextBuilder.analyticsValue(for: .noProfileFound),
            PublicEntryAnalyticsProfileResolution.noProfileFound.rawValue
        )
        XCTAssertEqual(
            PublicEntryAnalyticsContextBuilder.analyticsValue(for: .lookupFailed),
            PublicEntryAnalyticsProfileResolution.lookupFailed.rawValue
        )
        XCTAssertEqual(
            PublicEntryAnalyticsContextBuilder.analyticsValue(for: .conflict),
            PublicEntryAnalyticsProfileResolution.conflict.rawValue
        )
    }

    func testPropertiesIncludeEntrySourceAndReason() {
        let properties = PublicEntryAnalyticsContextBuilder.properties(
            hasLocalProfile: false,
            entrySource: .logout,
            profileResolutionResult: .noProfileFound,
            reason: "authCancelled"
        )

        XCTAssertEqual(properties.asParameters()["entry_source"], "logout")
        XCTAssertEqual(
            properties.asParameters()["profile_resolution_result"],
            PublicEntryAnalyticsProfileResolution.noProfileFound.rawValue
        )
        XCTAssertEqual(properties.asParameters()["reason"], "authCancelled")
    }

    func testPropertiesOmitsSensitiveIdentifiers() {
        let parameters = PublicEntryAnalyticsContextBuilder.properties(
            hasLocalProfile: true,
            entrySource: .freshInstall,
            profileResolutionResult: .profileFound(.cloudRestored),
            reason: "networkFailed"
        ).asParameters()

        let bannedKeys = ["uid", "email", "user_id", "token", "google_id"]
        for key in parameters.keys {
            for banned in bannedKeys {
                XCTAssertFalse(
                    key.localizedCaseInsensitiveContains(banned),
                    "Unexpected sensitive key: \(key)"
                )
            }
        }

        for value in parameters.values {
            XCTAssertFalse(value.contains("@"))
            XCTAssertFalse(value.localizedCaseInsensitiveContains("uid"))
        }
    }
}

final class PublicEntryAnalyticsLoggerTests: XCTestCase {

    func testCapturingLoggerRecordsEventsAndProperties() {
        let logger = CapturingPublicEntryAnalyticsLogger()
        let properties = PublicEntryAnalyticsContextBuilder.properties(
            hasLocalProfile: false,
            entrySource: .freshInstall
        )

        logger.log(.welcomeViewed, properties: properties)
        logger.log(.welcomeCreatePlanTapped, properties: properties)

        XCTAssertTrue(logger.contains(.welcomeViewed))
        XCTAssertEqual(logger.lastProperties(for: .welcomeViewed)?["entry_source"], "fresh_install")
        XCTAssertEqual(logger.lastProperties(for: .welcomeViewed)?["auth_provider"], "google")
    }

    func testLogoutAnalyticsUsesLogoutEntrySource() {
        let logger = CapturingPublicEntryAnalyticsLogger()
        let properties = PublicEntryAnalyticsContextBuilder.properties(
            hasLocalProfile: true,
            entrySource: .logout
        )

        logger.log(.logoutCompletedPublicEntryShown, properties: properties)

        XCTAssertTrue(logger.contains(.logoutCompletedPublicEntryShown))
        XCTAssertEqual(logger.lastProperties(for: .logoutCompletedPublicEntryShown)?["entry_source"], "logout")
        XCTAssertEqual(logger.lastProperties(for: .logoutCompletedPublicEntryShown)?["has_local_profile"], "true")
    }

    func testExistingSignInSuccessAnalyticsMapsProfileResolution() {
        let properties = PublicEntryAnalyticsContextBuilder.properties(
            hasLocalProfile: false,
            profileResolutionResult: .profileFound(.cloudRestored)
        )

        XCTAssertEqual(
            properties.asParameters()["profile_resolution_result"],
            PublicEntryAnalyticsProfileResolution.profileFoundCloud.rawValue
        )
    }

    func testExistingSignInNoProfileAnalyticsMapsResolution() {
        let properties = PublicEntryAnalyticsContextBuilder.properties(
            hasLocalProfile: false,
            profileResolutionResult: .noProfileFound
        )

        XCTAssertEqual(
            properties.asParameters()["profile_resolution_result"],
            PublicEntryAnalyticsProfileResolution.noProfileFound.rawValue
        )
    }

    func testLookupFailedAnalyticsMapsResolutionWithoutTreatingAsNewUser() {
        let properties = PublicEntryAnalyticsContextBuilder.properties(
            hasLocalProfile: false,
            profileResolutionResult: .lookupFailed,
            reason: ExistingUserSignInFailureKind.networkFailed.analyticsReason
        )

        XCTAssertEqual(
            properties.asParameters()["profile_resolution_result"],
            PublicEntryAnalyticsProfileResolution.lookupFailed.rawValue
        )
        XCTAssertNotEqual(
            properties.asParameters()["profile_resolution_result"],
            PublicEntryAnalyticsProfileResolution.noProfileFound.rawValue
        )
        XCTAssertEqual(properties.asParameters()["reason"], "networkFailed")
    }
}
