//
//  OnboardingV4StructureTests.swift
//  Fitness CoachTests
//
//  Forma — Marketing-first onboarding v4 structure tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV4StructureTests: XCTestCase {

    private var v4FlagPrevious: Bool?

    override func setUp() {
        super.setUp()
        v4FlagPrevious = UserDefaults.standard.object(forKey: OnboardingV4FeatureFlag.enabledKey) as? Bool
        UserDefaults.standard.set(true, forKey: OnboardingV2FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV3FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV4FeatureFlag.enabledKey)
    }

    override func tearDown() {
        if let v4FlagPrevious {
            UserDefaults.standard.set(v4FlagPrevious, forKey: OnboardingV4FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV4FeatureFlag.enabledKey)
        }
        super.tearDown()
    }

    func testV4DisabledByDefaultWhenKeyAbsent() {
        UserDefaults.standard.removeObject(forKey: OnboardingV4FeatureFlag.enabledKey)
        XCTAssertFalse(OnboardingV4FeatureFlag.isEnabled)
    }

    func testFullV4FlowOrder() {
        XCTAssertEqual(OnboardingV4Step.fullFlow, [
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

    func testPostAuthV4FlowSkipsIntroProof() {
        XCTAssertEqual(OnboardingV4Step.postAuthFlow.first, .heightWeight)
        XCTAssertFalse(OnboardingV4Step.postAuthFlow.contains(.introProof))
    }

    func testValueFirstTeaserV4FlowIsIntroProofOnly() {
        XCTAssertEqual(OnboardingV4Step.valueFirstTeaserFlow, [.introProof])
    }

    func testPlanRevealAndSaveHideProgressHeader() {
        XCTAssertFalse(OnboardingV4Step.planReveal.showsProgressHeader)
        XCTAssertFalse(OnboardingV4Step.savePlan.showsProgressHeader)
        XCTAssertFalse(OnboardingV4Step.introProof.showsProgressHeader)
        XCTAssertTrue(OnboardingV4Step.heightWeight.showsProgressHeader)
    }

    func testFlowScopeUsesV4WhenFlagActive() {
        let scope = OnboardingFlowScope.v2Full
        XCTAssertTrue(scope.usesV4Steps)
        XCTAssertFalse(scope.usesV3Steps)
        XCTAssertEqual(scope.entryV4Step, .introProof)
    }

    func testV4SupersedesV3WhenBothFlagsEnabled() {
        UserDefaults.standard.set(true, forKey: OnboardingV3FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV4FeatureFlag.enabledKey)
        let scope = OnboardingFlowScope.v2Full
        XCTAssertTrue(scope.usesV4Steps)
        XCTAssertFalse(scope.usesV3Steps)
    }

    func testDraftBridgeMapsProfileStepsToLegacyBody() {
        XCTAssertEqual(
            OnboardingV4DraftBridge.persistedLegacyStep(for: .heightWeight),
            .body
        )
        XCTAssertEqual(
            OnboardingV4DraftBridge.persistedLegacyStep(for: .birthday),
            .body
        )
    }

    func testDraftBridgeMapsProofStepsToLegacySummary() {
        XCTAssertEqual(
            OnboardingV4DraftBridge.persistedLegacyStep(for: .formaProof),
            .summary
        )
        XCTAssertEqual(
            OnboardingV4DraftBridge.persistedLegacyStep(for: .review),
            .summary
        )
    }

    func testLinearNavigationThroughMarketingAndDataSteps() {
        let flow = OnboardingV4Step.fullFlow
        XCTAssertEqual(OnboardingV4Step.introProof.next(in: flow), .heightWeight)
        XCTAssertEqual(OnboardingV4Step.formaProof.next(in: flow), .review)
        XCTAssertEqual(OnboardingV4Step.review.next(in: flow), .generatingPlan)
    }

    func testV4StageMapping() {
        XCTAssertEqual(OnboardingV4Step.introProof.stage, .start)
        XCTAssertEqual(OnboardingV4Step.heightWeight.stage, .body)
        XCTAssertEqual(OnboardingV4Step.targetWeight.stage, .destination)
        XCTAssertEqual(OnboardingV4Step.activityLevel.stage, .activity)
        XCTAssertEqual(OnboardingV4Step.formaProof.stage, .proof)
        XCTAssertEqual(OnboardingV4Step.review.stage, .plan)
        XCTAssertEqual(OnboardingV4Step.savePlan.stage, .save)
    }
}
