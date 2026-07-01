//
//  OnboardingGeneratingPlanTests.swift
//  Fitness CoachTests
//
//  Forma — Plan-generation moment presentation and flow tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingGeneratingPlanTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingGeneratingPlanTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testGoalAwareSubtitleForLoss() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.setWeightKg(90, in: &formState)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-10, in: &formState)

        let presentation = OnboardingGeneratingPlanCopyBuilder.build(from: formState)

        XCTAssertEqual(presentation.goalDirection, .cut)
        XCTAssertEqual(
            presentation.subtitle,
            FormaProductCopy.Onboarding.V2.Generating.Subtitle.loss
        )
    }

    func testGoalAwareSubtitleForGain() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.setWeightKg(70, in: &formState)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(8, in: &formState)

        let presentation = OnboardingGeneratingPlanCopyBuilder.build(from: formState)

        XCTAssertEqual(presentation.goalDirection, .gain)
        XCTAssertEqual(
            presentation.subtitle,
            FormaProductCopy.Onboarding.V2.Generating.Subtitle.gain
        )
    }

    func testGoalAwareSubtitleForMaintain() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.setWeightKg(72, in: &formState)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(0, in: &formState)

        let presentation = OnboardingGeneratingPlanCopyBuilder.build(from: formState)

        XCTAssertEqual(presentation.goalDirection, .maintain)
        XCTAssertEqual(
            presentation.subtitle,
            FormaProductCopy.Onboarding.V2.Generating.Subtitle.maintain
        )
    }

    func testFallbackSubtitleWhenWeightsMissing() {
        let presentation = OnboardingGeneratingPlanCopyBuilder.build(from: OnboardingFormState())

        XCTAssertEqual(
            presentation.subtitle,
            FormaProductCopy.Onboarding.V2.Generating.Subtitle.fallback
        )
    }

    func testStepTimingMatchesChecklistCount() {
        XCTAssertEqual(
            OnboardingGeneratingPlanTiming.stepActiveDurations.count,
            FormaProductCopy.Onboarding.V2.Generating.checklist.count
        )
    }

    func testGeneratingCopyAvoidsDynamicCaloriesAndAutoAdjustmentClaims() {
        let samples = [
            FormaProductCopy.Onboarding.V2.Generating.title,
            FormaProductCopy.Onboarding.V2.Generating.successTitle,
            FormaProductCopy.Onboarding.V2.Generating.anticipationText,
            FormaProductCopy.Onboarding.V2.Generating.slowGenerationMessage,
            FormaProductCopy.Onboarding.V2.Generating.failureTitle,
            FormaProductCopy.Onboarding.V2.Generating.failureMessage,
            FormaProductCopy.Onboarding.V2.Generating.tryAgainCTA,
            FormaProductCopy.Onboarding.V2.Generating.goBackCTA,
            FormaProductCopy.Onboarding.V2.Generating.Subtitle.loss,
            FormaProductCopy.Onboarding.V2.Generating.Subtitle.gain,
            FormaProductCopy.Onboarding.V2.Generating.Subtitle.maintain,
            FormaProductCopy.Onboarding.V2.Generating.Subtitle.fallback,
            FormaProductCopy.Onboarding.V2.Generating.checklist.joined(separator: " ")
        ]

        for sample in samples {
            let lowered = sample.lowercased()
            XCTAssertFalse(lowered.contains("dynamic calor"), sample)
            XCTAssertFalse(lowered.contains("automatic adjust"), sample)
            XCTAssertFalse(lowered.contains("ai is"), sample)
        }
    }

    func testFailureCopyIncludesRetryAndGoBackActions() {
        XCTAssertEqual(
            FormaProductCopy.Onboarding.V2.Generating.tryAgainCTA,
            "Try again"
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.V2.Generating.goBackCTA,
            "Go back"
        )
    }

    func testGenerationSuccessRoutesToPlanReveal() async throws {
        let model = try makeModel()
        await navigateToReview(model)

        model.beginGeneration()
        await model.flushPendingGenerationForTesting()

        XCTAssertEqual(model.currentStep, .planReveal)
        XCTAssertNotNil(model.generatedPlan)
        XCTAssertNotNil(model.planRevealState)
    }

    func testRetryGenerationNoOpUnlessFailed() async throws {
        let model = try makeModel()
        await navigateToReview(model)

        model.retryGeneration()
        XCTAssertEqual(model.viewState, .editing)

        model.beginGeneration()
        XCTAssertEqual(model.viewState, .generatingPlanAnimated)

        model.retryGeneration()
        XCTAssertEqual(model.viewState, .generatingPlanAnimated)

        await model.flushPendingGenerationForTesting()
    }

    func testDuplicateGenerationRequestDoesNotRestartWhileGenerating() async throws {
        let model = try makeModel()
        await navigateToReview(model)

        model.beginGeneration()
        XCTAssertEqual(model.viewState, .generatingPlanAnimated)

        model.beginGeneration()
        model.generatePlanPreview()

        XCTAssertEqual(model.currentStep, .generatingPlan)
        XCTAssertEqual(model.viewState, .generatingPlanAnimated)

        await model.flushPendingGenerationForTesting()
        XCTAssertEqual(model.currentStep, .planReveal)
    }

    // MARK: - Helpers

    private func makeModel() throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            planTargetCalculator: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }

    private func navigateToReview(_ model: OnboardingModel) async {
        OnboardingModelTestSupport.seedCanonicalForm(&model.formState)
        await OnboardingModelTestSupport.advanceTo(.review, model: model, seedForm: false)
    }
}
