//
//  OnboardingSavePlanLayoutTests.swift
//  Fitness CoachTests
//
//  Forma — Fixed-viewport layout guardrails for protect-progress.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingSavePlanLayoutTests: XCTestCase {

    func testSavePlanUpperZoneWeightsSumToOne() {
        let profiles: [OnboardingPlanRevealLayoutProfile] = [.compact, .regular, .expansive]

        for profile in profiles {
            for showsJourney in [true, false] {
                let weights = profile.savePlanUpperZoneWeights(showsJourney: showsJourney)
                let activeWeights = weights.filter { $0.value > 0 }
                let sum = activeWeights.values.reduce(0, +)
                XCTAssertEqual(
                    sum,
                    1,
                    accuracy: 0.001,
                    "Weights should sum to 1 for \(profile) journey=\(showsJourney)"
                )
            }
        }
    }

    func testSavePlanCompactHidesJourneyCard() {
        XCTAssertFalse(OnboardingPlanRevealLayoutProfile.compact.savePlanShowsJourneyCard)
        XCTAssertTrue(OnboardingPlanRevealLayoutProfile.regular.savePlanShowsJourneyCard)
        XCTAssertTrue(OnboardingPlanRevealLayoutProfile.expansive.savePlanShowsJourneyCard)
    }

    func testSavePlanTrustRowLimitsScaleWithProfile() {
        XCTAssertEqual(OnboardingPlanRevealLayoutProfile.compact.savePlanTrustRowLimit, 3)
        XCTAssertEqual(OnboardingPlanRevealLayoutProfile.regular.savePlanTrustRowLimit, 4)
        XCTAssertEqual(OnboardingPlanRevealLayoutProfile.expansive.savePlanTrustRowLimit, 5)
    }

    func testSavePlanResolveUsesCompactForAccessibilityDynamicType() {
        let profile = OnboardingPlanRevealLayoutProfile.resolve(
            contentHeight: 800,
            contentWidth: 400,
            dynamicTypeSize: .accessibility2
        )
        XCTAssertEqual(profile, .compact)
    }

    func testSavePlanResolveUsesCompactForSEViewport() {
        let profile = OnboardingPlanRevealLayoutProfile.resolve(
            contentHeight: 480,
            contentWidth: 375,
            dynamicTypeSize: .large
        )
        XCTAssertEqual(profile, .compact)
    }

    func testSavePlanResolveUsesExpansiveForProMaxViewport() {
        let profile = OnboardingPlanRevealLayoutProfile.resolve(
            contentHeight: 760,
            contentWidth: 430,
            dynamicTypeSize: .large
        )
        XCTAssertEqual(profile, .expansive)
    }
}
