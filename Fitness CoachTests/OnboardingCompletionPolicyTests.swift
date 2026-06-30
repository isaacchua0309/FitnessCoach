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
            OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: "plan"),
            .plan
        )
        XCTAssertEqual(
            OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: "profile"),
            .plan
        )
        XCTAssertEqual(
            OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: "journey"),
            .journey
        )
        XCTAssertEqual(
            OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: "progress"),
            .journey
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
