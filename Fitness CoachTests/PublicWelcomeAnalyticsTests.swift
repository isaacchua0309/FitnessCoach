//
//  PublicWelcomeAnalyticsTests.swift
//  Fitness CoachTests
//
//  Forma — Public welcome analytics and copy contract tests.
//

import XCTest
@testable import Fitness_Coach

final class PublicWelcomeAnalyticsTests: XCTestCase {

    func testWelcomeAnalyticsEventNames() {
        XCTAssertEqual(PublicEntryAnalyticsEvent.welcomeViewed.rawValue, "public_welcome_viewed")
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.welcomeCreatePlanTapped.rawValue,
            "public_welcome_create_plan_tapped"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.welcomeSignInTapped.rawValue,
            "public_welcome_sign_in_tapped"
        )
    }

    func testWelcomeCopyMatchesProductSpec() {
        let copy = FormaProductCopy.PublicEntry.Welcome.self
        XCTAssertEqual(copy.title, "Welcome to Forma")
        XCTAssertEqual(copy.headline, "The smarter way to lose weight without restrictive diets.")
        XCTAssertEqual(
            copy.supportingCopy,
            "Build a personalized nutrition plan, track your meals effortlessly, and stay consistent every day."
        )
        XCTAssertEqual(copy.createMyPlanCTA, "Create My Plan")
        XCTAssertEqual(copy.existingAccountPrompt, "Already have an account?")
        XCTAssertEqual(copy.signInCTA, "Sign In →")
        XCTAssertEqual(copy.benefits.map(\.title), [
            "Personalized calorie targets",
            "Fast meal logging",
            "Long-term progress"
        ])
    }

    func testRecordingLoggerCapturesEvents() {
        let logger = CapturingPublicEntryAnalyticsLogger()
        let properties = PublicEntryAnalyticsContextBuilder.baseProperties(hasLocalProfile: false)
        logger.log(.welcomeViewed, properties: properties)
        logger.log(.welcomeCreatePlanTapped, properties: properties)
        logger.log(.welcomeSignInTapped, properties: properties)

        XCTAssertEqual(logger.events.map(\.event), [
            .welcomeViewed,
            .welcomeCreatePlanTapped,
            .welcomeSignInTapped
        ])
        XCTAssertEqual(logger.lastProperties(for: .welcomeViewed)?["auth_provider"], "google")
    }
}
