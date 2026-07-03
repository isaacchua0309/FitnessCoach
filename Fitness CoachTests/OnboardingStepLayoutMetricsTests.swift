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
        XCTAssertEqual(
            OnboardingStepLayoutProfile.resolve(viewportHeight: 640, dynamicTypeSize: .large),
            .compact
        )
        XCTAssertEqual(
            OnboardingStepLayoutProfile.resolve(viewportHeight: 844, dynamicTypeSize: .large),
            .regular
        )
    }

    func testCompactProfileActivatesForAccessibilityTypeOnShorterPhones() {
        XCTAssertEqual(
            OnboardingStepLayoutProfile.resolve(viewportHeight: 780, dynamicTypeSize: .accessibility3),
            .compact
        )
    }

    func testAppleHealthAllowsScrollOnCompactProfile() {
        XCTAssertTrue(
            OnboardingStepLayoutProfile.compact.allowsScrollableContent(
                step: .appleHealth,
                dynamicTypeSize: .large
            )
        )
        XCTAssertFalse(
            OnboardingStepLayoutProfile.regular.allowsScrollableContent(
                step: .appleHealth,
                dynamicTypeSize: .large
            )
        )
    }

    func testProgressChromeHeightGrowsForAccessibilityDynamicType() {
        let regular = OnboardingStepLayoutMetrics.progressChromeHeight(
            step: .introProof,
            profile: .regular,
            showsSubtitle: true,
            dynamicTypeSize: .large
        )
        let accessibility = OnboardingStepLayoutMetrics.progressChromeHeight(
            step: .introProof,
            profile: .regular,
            showsSubtitle: true,
            dynamicTypeSize: .accessibility3
        )
        XCTAssertGreaterThan(accessibility, regular)
    }

    func testUnifiedCardMetricsMatchDesignTokens() {
        XCTAssertEqual(OnboardingUnifiedCardMetrics.cornerRadius, FormaTokens.Radius.card)
        XCTAssertEqual(OnboardingUnifiedCardMetrics.padding, FormaTokens.Spacing.cardPadding)
        XCTAssertEqual(
            OnboardingUnifiedChromeTypography.subtitleMaxWidth,
            FormaTokens.Layout.maxContentWidth
        )
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
