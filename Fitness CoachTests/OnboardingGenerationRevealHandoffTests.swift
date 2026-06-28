//
//  OnboardingGenerationRevealHandoffTests.swift
//  Fitness CoachTests
//
//  Forma — Generation-to-reveal continuity and handoff timing.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingGenerationRevealHandoffTests: XCTestCase {

    func testPlanReadyStatePrecedesRevealStepTransition() async throws {
        let model = try makeModel()
        await navigateToReview(model)

        model.beginGeneration()
        await model.flushPendingGenerationForTesting()

        XCTAssertEqual(model.currentStep, .planReveal)
        XCTAssertNotNil(model.generatedPlan)
        XCTAssertNotNil(model.planRevealState)
        XCTAssertEqual(model.viewState, .editing)
    }

    func testMinimumPresentationBeforeSuccessMatchesStagedChecklist() {
        let timing = OnboardingGeneratingPlanTiming.self
        let expected = timing.firstStepDelay + timing.stepActiveDurations.reduce(0, +)

        XCTAssertEqual(timing.minimumPresentationBeforeSuccess, expected, accuracy: 0.001)
        XCTAssertEqual(
            timing.minimumDisplayDuration,
            expected + timing.successHold,
            accuracy: 0.001
        )
    }

    func testCompleteGenerationRevealHandoffIsIdempotent() async throws {
        let model = try makeModel()
        await navigateToReview(model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()

        let step = model.currentStep
        model.completeGenerationRevealHandoff()
        XCTAssertEqual(model.currentStep, step)
    }

    func testGeneratingPlanReservesRevealFooterSpace() {
        let rules = OnboardingInteractionPolicy.rules(for: .generatingPlan)
        XCTAssertFalse(rules.showsSharedBottomBar)
        XCTAssertTrue(rules.reservesPlanRevealFooterSpace)
    }

    // MARK: - Helpers

    private func makeModel() throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: OnboardingDraftStore(
                userDefaults: UserDefaults(suiteName: "OnboardingGenerationRevealHandoffTests.\(UUID())")!
            ),
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }

    private func navigateToReview(_ model: OnboardingModel) async {
        OnboardingModelTestSupport.seedCanonicalForm(&model.formState)
        await OnboardingModelTestSupport.advanceTo(.review, model: model, seedForm: false)
    }
}
