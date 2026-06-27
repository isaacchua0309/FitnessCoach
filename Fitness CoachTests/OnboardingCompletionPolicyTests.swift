//
//  OnboardingCompletionPolicyTests.swift
//  Fitness CoachTests
//
//  Forma — Main tab routing after onboarding completion.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingCompletionPolicyTests: XCTestCase {

    func testDefaultsToTodayWhenNoPersistedTab() {
        XCTAssertEqual(
            OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: nil),
            .today
        )
    }

    func testUsesPersistedTabWhenAvailable() {
        XCTAssertEqual(
            OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: "profile"),
            .profile
        )
        XCTAssertEqual(
            OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: "coach"),
            .coach
        )
    }

    func testFallsBackToTodayForUnknownPersistedTab() {
        XCTAssertEqual(
            OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: "unknown-tab"),
            .today
        )
    }
}
