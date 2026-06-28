//
//  OnboardingVisionLayoutTests.swift
//  Fitness CoachTests
//
//  Forma — Fixed-viewport marketing layout policy tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingVisionLayoutTests: XCTestCase {

    func testMarketingStepsUseFixedViewportShell() {
        XCTAssertTrue(OnboardingStep.almostThere.usesFixedViewportShell)
        XCTAssertTrue(OnboardingStep.formaProof.usesFixedViewportShell)
    }

    func testZoneWeightsFillTargetRange() {
        let profiles: [(OnboardingVisionScreen, OnboardingVisionLayoutProfile)] = [
            (.almostThere, .regular),
            (.almostThere, .compact),
            (.formaProof, .regular),
            (.formaProof, .compact)
        ]

        for (screen, profile) in profiles {
            let weights = OnboardingVisionZoneWeights.weights(for: screen, profile: profile)
            let fill = OnboardingVisionZoneWeights.normalizedFillRatio(weights)
            XCTAssertTrue(
                OnboardingVisionLayoutMetrics.targetFillRange.contains(fill),
                "Fill ratio \(fill) for \(screen) \(profile) outside target range"
            )
        }
    }

    func testCompactProfileActivatesForLandscapeAndShortViewport() {
        XCTAssertEqual(
            OnboardingVisionLayoutProfile.resolve(verticalSizeClass: .compact, contentHeight: 500),
            .compact
        )
        XCTAssertEqual(
            OnboardingVisionLayoutProfile.resolve(verticalSizeClass: .regular, contentHeight: 360),
            .compact
        )
        XCTAssertEqual(
            OnboardingVisionLayoutProfile.resolve(verticalSizeClass: .regular, contentHeight: 500),
            .regular
        )
    }

    func testEstimatedContentHeightAccountsForChrome() {
        let seHeight = OnboardingVisionLayoutMetrics.estimatedContentHeight(viewportHeight: 667)
        XCTAssertGreaterThan(seHeight, 400)
        XCTAssertLessThan(seHeight, 560)

        let proMaxHeight = OnboardingVisionLayoutMetrics.estimatedContentHeight(viewportHeight: 932)
        XCTAssertGreaterThan(proMaxHeight, seHeight)
    }

    func testNormalizedZoneHeightsFillContentArea() {
        let contentHeight: CGFloat = 480
        let weights = OnboardingVisionZoneWeights.almostThere
        let total = weights.values.reduce(0, +)
        let zoneHeights = weights.map { zone, weight in
            OnboardingVisionLayoutMetrics.zoneHeight(
                contentHeight: contentHeight,
                weight: weight,
                totalWeight: total
            )
        }
        let sum = zoneHeights.reduce(0, +)
        XCTAssertEqual(sum, contentHeight, accuracy: 0.5)
    }

    func testAccessibilityZoneScalePreservesFillOnLargeDynamicType() {
        let contentHeight: CGFloat = 480
        let weights = OnboardingVisionZoneWeights.formaProof
        let total = weights.values.reduce(0, +)
        let regularSum = weights.values.reduce(0) { partial, weight in
            partial + OnboardingVisionLayoutMetrics.zoneHeight(
                contentHeight: contentHeight,
                weight: weight,
                totalWeight: total,
                dynamicTypeScale: 1
            )
        }
        let accessibilitySum = weights.values.reduce(0) { partial, weight in
            partial + OnboardingVisionLayoutMetrics.zoneHeight(
                contentHeight: contentHeight,
                weight: weight,
                totalWeight: total,
                dynamicTypeScale: OnboardingVisual.accessibilityZoneScale
            )
        }
        XCTAssertEqual(accessibilitySum, regularSum * OnboardingVisual.accessibilityZoneScale, accuracy: 0.5)
        XCTAssertLessThan(accessibilitySum, contentHeight)
    }

    func testAlmostThereAccessibilityLabelsAreNonEmpty() {
        XCTAssertFalse(OnboardingAlmostThereValues.accessibilitySummary.isEmpty)
        XCTAssertFalse(OnboardingAlmostThereValues.benefitsAccessibilityLabel.isEmpty)
    }

    func testFormaProofAccessibilityLabelIncludesGoalContext() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setWeightKg(70, in: &state)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &state)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertFalse(proof.accessibilityLabel.isEmpty)
        XCTAssertFalse(proof.benefitsAccessibilityLabel.isEmpty)
        XCTAssertTrue(proof.accessibilityLabel.contains("Lose"))
    }

    func testMarketingStepsDoNotUseKeyboardValidation() {
        let almostThereRules = OnboardingInteractionPolicy.rules(for: .almostThere)
        let formaProofRules = OnboardingInteractionPolicy.rules(for: .formaProof)

        XCTAssertTrue(almostThereRules.showsSharedBottomBar)
        XCTAssertTrue(formaProofRules.showsSharedBottomBar)
        XCTAssertFalse(almostThereRules.allowsKeyboardForRequiredInput)
        XCTAssertFalse(formaProofRules.allowsKeyboardForRequiredInput)
        XCTAssertTrue(almostThereRules.dismissesKeyboardOnAppear)
        XCTAssertTrue(formaProofRules.dismissesKeyboardOnAppear)
    }
}
