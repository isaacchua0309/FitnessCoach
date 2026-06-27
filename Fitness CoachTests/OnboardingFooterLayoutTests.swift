//
//  OnboardingFooterLayoutTests.swift
//  Fitness CoachTests
//
//  Forma — Footer inset and validation display policy tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingFooterLayoutTests: XCTestCase {

    func testScrollContentBottomInsetAddsKeyboardHeight() {
        XCTAssertEqual(
            OnboardingLayout.scrollContentBottomInset(keyboardHeight: 0),
            OnboardingLayout.scrollContentBreathingRoom
        )
        XCTAssertEqual(
            OnboardingLayout.scrollContentBottomInset(keyboardHeight: 320),
            OnboardingLayout.scrollContentBreathingRoom + 320
        )
    }

    func testScrollContentBottomInsetIgnoresNegativeKeyboardHeight() {
        XCTAssertEqual(
            OnboardingLayout.scrollContentBottomInset(keyboardHeight: -12),
            OnboardingLayout.scrollContentBreathingRoom
        )
    }
}
