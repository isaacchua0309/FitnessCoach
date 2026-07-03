//
//  OnboardingStepLayoutMetricsTests.swift
//  Fitness CoachTests
//
//  Forma — Unified onboarding step layout metrics tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingStepLayoutMetricsTests: XCTestCase {

    func testUnifiedLayoutSteps() {
        XCTAssertTrue(OnboardingStep.introProof.usesUnifiedLayoutShell)
        XCTAssertTrue(OnboardingStep.appleHealth.usesUnifiedLayoutShell)
        XCTAssertFalse(OnboardingStep.heightWeight.usesUnifiedLayoutShell)
        XCTAssertFalse(OnboardingStep.almostThere.usesUnifiedLayoutShell)
    }

    func testIntroProofUsesUnifiedShellNotLegacyScroll() {
        XCTAssertTrue(OnboardingStep.introProof.usesUnifiedLayoutShell)
        XCTAssertFalse(OnboardingStep.introProof.usesFixedViewportShell)
    }

    func testAppleHealthUsesUnifiedShellNotLegacyFixed() {
        XCTAssertTrue(OnboardingStep.appleHealth.usesUnifiedLayoutShell)
        XCTAssertFalse(OnboardingStep.appleHealth.usesFixedViewportShell)
    }

    func testCompactProfileActivatesForShortViewports() {
        XCTAssertEqual(OnboardingStepLayoutProfile.resolve(viewportHeight: 640), .compact)
        XCTAssertEqual(OnboardingStepLayoutProfile.resolve(viewportHeight: 844), .regular)
    }

    func testContentAreaHeightIsPositiveForModernPhoneViewport() {
        let profile = OnboardingStepLayoutProfile.regular
        let height = OnboardingStepLayoutMetrics.contentAreaHeight(
            viewportHeight: 700,
            step: .introProof,
            profile: profile
        )
        XCTAssertGreaterThan(height, 200)
        XCTAssertLessThan(height, 700)
    }

    func testIntroProofHeroCardHeightScalesWithContentArea() {
        let compact = OnboardingStepLayoutMetrics.introProofHeroCardHeight(
            contentHeight: 320,
            profile: .compact,
            dynamicTypeSize: .large
        )
        let regular = OnboardingStepLayoutMetrics.introProofHeroCardHeight(
            contentHeight: 520,
            profile: .regular,
            dynamicTypeSize: .large
        )
        XCTAssertGreaterThan(regular, compact)
        XCTAssertGreaterThanOrEqual(compact, 190)
        XCTAssertLessThanOrEqual(regular, 380)
    }

    func testIntroProofFooterStackGrowsForAccessibilityDynamicType() {
        let regular = OnboardingStepLayoutMetrics.introProofFooterStackHeight(
            profile: .regular,
            dynamicTypeSize: .large
        )
        let accessibility = OnboardingStepLayoutMetrics.introProofFooterStackHeight(
            profile: .regular,
            dynamicTypeSize: .accessibility3
        )
        XCTAssertGreaterThan(accessibility, regular)
    }
}
