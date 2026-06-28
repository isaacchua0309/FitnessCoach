//
//  OnboardingStructureTests.swift
//  Fitness CoachTests
//
//  Forma — Canonical onboarding flow structure tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingStructureTests: XCTestCase {

    func testFlowOrder() {
        XCTAssertEqual(OnboardingStep.flow, [
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
        ])
    }

    func testSignedOutEntryStartsAtIntroProof() {
        XCTAssertEqual(OnboardingEntry.initialStep(for: .preAuth), .introProof)
    }

    func testSignedInIncompleteProfileEntryStartsAtHeightWeight() {
        XCTAssertEqual(OnboardingEntry.initialStep(for: .postAuth), .heightWeight)
    }

    func testPlanRevealAndSaveHideProgressHeader() {
        XCTAssertFalse(OnboardingStep.planReveal.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.savePlan.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.introProof.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.heightWeight.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.targetWeight.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.birthday.showsProgressHeader)
        XCTAssertTrue(OnboardingStep.birthday.usesFixedViewportShell)
        XCTAssertTrue(OnboardingStep.activityLevel.usesFixedViewportShell)
        XCTAssertFalse(OnboardingStep.activityLevel.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.appleHealth.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.almostThere.showsProgressHeader)
    }

    func testDraftStoresCanonicalStepRawValues() {
        let draft = OnboardingDraft(formState: OnboardingFormState(), step: .heightWeight)
        XCTAssertEqual(draft.currentStepRawValue, OnboardingStep.heightWeight.rawValue)
        XCTAssertEqual(draft.step, .heightWeight)
    }

    func testDraftStepResolverRestoresIntroFromLegacyLanding() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.landing.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .introProof)
    }

    func testDraftStepResolverRestoresSavePlanFromLegacySavePlan() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.savePlan.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .savePlan)
    }

    func testLegacyWelcomeDraftMigratesToIntroProof() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.welcome.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .introProof)
    }

    func testLegacyPreferencesDraftMigratesToNearestRequiredStep() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.preferences.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restored, .targetWeight)
    }

    func testFlowDoesNotIncludeRemovedDataCollectionSteps() {
        let flowRawValues = Set(OnboardingStep.flow.map(\.rawValue))
        let removedSteps: [OnboardingLegacyPersistedStep] = [
            .welcome,
            .motivation,
            .preferences,
            .planPreview
        ]

        for step in removedSteps {
            XCTAssertFalse(flowRawValues.contains(step.rawValue))
        }
    }

    func testCanonicalFlowExcludesRemovedOnboardingScreens() {
        let flowStepNames = OnboardingStep.flow.map {
            OnboardingDraftBridge.analyticsStepName($0)
        }

        let removedScreenSlugs = [
            "landing",
            "motivation",
            "body_basics",
            "bodyBasics",
            "training_rhythm",
            "trainingRhythm",
            "preferences",
            "about_you",
            "aboutYou",
            "dynamic_calories",
            "dynamicCalories",
            "body_fat",
            "bodyFat",
            "manual_age",
            "manualAge"
        ]

        for slug in removedScreenSlugs {
            XCTAssertFalse(
                flowStepNames.contains(slug),
                "Canonical flow must not include removed screen \(slug)"
            )
        }
    }

    func testCanonicalFlowMatchesProductStages() {
        XCTAssertEqual(OnboardingStep.introProof.stage, .start)
        XCTAssertEqual(OnboardingStep.heightWeight.stage, .body)
        XCTAssertEqual(OnboardingStep.targetWeight.stage, .destination)
        XCTAssertEqual(OnboardingStep.birthday.stage, .body)
        XCTAssertEqual(OnboardingStep.activityLevel.stage, .activity)
        XCTAssertEqual(OnboardingStep.almostThere.stage, .proof)
        XCTAssertEqual(OnboardingStep.formaProof.stage, .proof)
        XCTAssertEqual(OnboardingStep.review.stage, .plan)
        XCTAssertEqual(OnboardingStep.savePlan.stage, .save)
    }
}
