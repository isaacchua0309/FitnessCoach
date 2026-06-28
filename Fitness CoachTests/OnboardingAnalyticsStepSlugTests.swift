//
//  OnboardingAnalyticsStepSlugTests.swift
//  Fitness CoachTests
//
//  Forma — onboarding analytics slug contract tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingAnalyticsStepSlugTests: XCTestCase {

    func testFullFlowSlugOrderMatchesProductContract() {
        let expected: [OnboardingAnalyticsStepSlug] = [
            .introProof,
            .heightWeight,
            .targetWeight,
            .targetEncouragement,
            .birthday,
            .activityLevel,
            .appleHealth,
            .almostThere,
            .formaProof,
            .review,
            .generatingPlan,
            .planReveal,
            .savePlan
        ]

        XCTAssertEqual(
            OnboardingStep.flow.map { OnboardingAnalyticsStepSlug(step: $0) },
            expected
        )
        XCTAssertEqual(
            OnboardingStep.flow.map(OnboardingDraftBridge.analyticsStepName),
            expected.map(\.rawValue)
        )
    }

    func testEveryStepMapsToUniqueSlug() {
        let slugs = OnboardingStep.allCases.map(OnboardingDraftBridge.analyticsStepName)
        XCTAssertEqual(slugs.count, Set(slugs).count)
        XCTAssertEqual(slugs.count, OnboardingAnalyticsStepSlug.allCases.count)
    }

    func testSlugEnumRoundTripsAllSteps() {
        for step in OnboardingStep.allCases {
            XCTAssertEqual(OnboardingAnalyticsStepSlug(step: step).step, step)
            XCTAssertEqual(
                OnboardingDraftBridge.analyticsStepName(step),
                OnboardingAnalyticsStepSlug(step: step).rawValue
            )
        }
    }

    func testFlowExcludesLegacyAnalyticsSlugs() {
        let slugs = Set(OnboardingStep.flow.map(OnboardingDraftBridge.analyticsStepName))
        let legacySlugs = [
            "landing", "motivation", "body_basics", "bodyBasics", "training_rhythm", "trainingRhythm",
            "preferences", "preference_details", "preferenceDetails", "welcome", "body", "goal",
            "activity", "summary", "plan_preview", "planPreview"
        ]
        for legacySlug in legacySlugs {
            XCTAssertFalse(slugs.contains(legacySlug), "Flow must not emit legacy slug \(legacySlug)")
        }
    }

    func testStepEventsUseOnlyCanonicalSlugs() {
        let canonical = Set(OnboardingAnalyticsStepSlug.allCases.map(\.rawValue))
        for step in OnboardingStep.allCases {
            XCTAssertTrue(canonical.contains(OnboardingDraftBridge.analyticsStepName(step)))
        }
    }

    func testAppleHealthUsesSnakeCaseSlug() {
        XCTAssertEqual(
            OnboardingDraftBridge.analyticsStepName(.appleHealth),
            OnboardingAnalyticsStepSlug.appleHealth.rawValue
        )
        XCTAssertEqual(OnboardingAnalyticsStepSlug.appleHealth.rawValue, "apple_health")
    }

    func testAppleHealthAnalyticsEventNamesMatchContract() {
        XCTAssertEqual(
            OnboardingAnalyticsEvent.appleHealthPromptViewed.rawValue,
            "apple_health_prompt_viewed"
        )
        XCTAssertEqual(
            OnboardingAnalyticsEvent.appleHealthPermissionRequested.rawValue,
            "apple_health_permission_requested"
        )
        XCTAssertEqual(
            OnboardingAnalyticsEvent.appleHealthPermissionResult.rawValue,
            "apple_health_permission_result"
        )
    }
}

