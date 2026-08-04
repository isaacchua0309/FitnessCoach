//
//  OnboardingNavigationStateMachineTests.swift
//  Fitness CoachTests
//
//  Focused tests for onboarding step forward/back ownership.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingNavigationStateMachineTests: XCTestCase {

    private var draftSuiteName: String!
    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        draftSuiteName = "OnboardingNavigationStateMachineTests.\(UUID().uuidString)"
        draftDefaults = UserDefaults(suiteName: draftSuiteName)!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftSuiteName)
        draftDefaults = nil
        draftStore = nil
        draftSuiteName = nil
        super.tearDown()
    }

    func testForwardTransitionAdvancesOneStep() async throws {
        let model = try makePreAuthModel()
        XCTAssertEqual(model.currentStep, .introProof)
        model.goNext()
        XCTAssertEqual(model.currentStep, .heightWeight)
    }

    func testBackwardTransitionMovesOneStep() async throws {
        let model = try makePreAuthModel()
        model.goNext()
        model.goBack()
        XCTAssertEqual(model.currentStep, .introProof)
    }

    func testBackFromFirstStepResolvesExitToWelcome() async throws {
        let model = try makePreAuthModel()
        XCTAssertEqual(model.resolveBackAction(), .exitToWelcome)
        var exited = false
        model.handleBack(exitToWelcome: { exited = true })
        XCTAssertTrue(exited)
        XCTAssertEqual(model.currentStep, .introProof)
    }

    func testNoTransitionBeforeFirstStepForPostAuthFloor() async throws {
        let model = try makePostAuthModel()
        XCTAssertEqual(model.currentStep, .heightWeight)
        XCTAssertEqual(model.resolveBackAction(), .none)
        model.handleBack(exitToWelcome: { XCTFail("must not exit to welcome") })
        XCTAssertEqual(model.currentStep, .heightWeight)
    }

    func testNoTransitionBeyondFinalStepViaGoNextOnGenerating() async throws {
        let model = try makePreAuthModel()
        await advanceTo(.review, model: model)
        model.beginGeneration()
        XCTAssertEqual(model.currentStep, .generatingPlan)
        model.goNext()
        XCTAssertEqual(model.currentStep, .generatingPlan)
        XCTAssertEqual(model.resolveBackAction(), .none)
        await model.flushPendingGenerationForTesting()
    }

    func testRapidRepeatedBackRequestsStayLinear() async throws {
        let model = try makePreAuthModel()
        await advanceTo(.birthday, model: model)

        var path: [OnboardingStep] = [model.currentStep]
        while model.resolveBackAction() == .moveToPreviousStep {
            let before = model.currentStep
            model.handleBack(exitToWelcome: { XCTFail("unexpected welcome exit") })
            path.append(model.currentStep)
            XCTAssertNotEqual(before, model.currentStep)
        }

        XCTAssertEqual(model.currentStep, .introProof)
        XCTAssertEqual(model.resolveBackAction(), .exitToWelcome)
        XCTAssertEqual(Set(path).count, path.count, "path should not revisit steps: \(path)")
    }

    func testResetAfterExitAllowsCleanReentryAtIntroProof() async throws {
        let container = try AppContainer(inMemory: true)
        let first = try makePreAuthModel(container: container)
        first.goNext()
        XCTAssertEqual(first.currentStep, .heightWeight)
        XCTAssertTrue(draftStore.hasDraft)

        draftStore.clearDraft()
        let second = try makePreAuthModel(container: container)
        XCTAssertEqual(second.currentStep, .introProof)
        XCTAssertEqual(second.resolveBackAction(), .exitToWelcome)
    }

    func testPaceSkipForwardAndBackRemainSingleStep() async throws {
        let model = try makePreAuthModel()
        // Defaults keep goal weight ~= current weight → pace step is skipped.
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &model.formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &model.formState)
        XCTAssertFalse(model.formState.isPaceApplicable())

        model.goNext() // heightWeight
        model.goNext() // targetWeight
        model.goNext() // skips pace → encouragement
        XCTAssertEqual(model.currentStep, .targetEncouragement)

        model.goBack()
        XCTAssertEqual(model.currentStep, .targetWeight)
    }

    func testHandleBackDoesNotMutateStepWhenExiting() async throws {
        let model = try makePreAuthModel()
        var exitCount = 0
        model.handleBack(exitToWelcome: { exitCount += 1 })
        model.handleBack(exitToWelcome: { exitCount += 1 })
        XCTAssertEqual(exitCount, 2)
        XCTAssertEqual(model.currentStep, .introProof)
    }

    // MARK: - Helpers

    private func makePreAuthModel(container: AppContainer? = nil) throws -> OnboardingModel {
        let resolved = try container ?? AppContainer(inMemory: true)
        return OnboardingModel(
            actionCenter: resolved.actionCenter,
            userProfileReader: resolved.userProfileService,
            planTargetCalculator: resolved.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsEntry: .preAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }

    private func makePostAuthModel() throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            planTargetCalculator: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsEntry: .postAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }

    private func seedForm(_ formState: inout OnboardingFormState) {
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &formState)
        formState.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &formState)
        formState.selectPaceChoice(.moderate)
    }

    private func advanceTo(_ target: OnboardingStep, model: OnboardingModel) async {
        seedForm(&model.formState)
        var iterations = 0
        while model.currentStep != target {
            iterations += 1
            XCTAssertLessThanOrEqual(iterations, 40)
            switch model.currentStep {
            case .appleHealth:
                model.skipAppleHealth()
                for _ in 0..<50 where model.currentStep == .appleHealth {
                    await Task.yield()
                }
            case .generatingPlan:
                await model.flushPendingGenerationForTesting()
            default:
                model.goNext()
            }
        }
    }
}
