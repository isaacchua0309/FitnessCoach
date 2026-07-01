//
//  OnboardingFormaProofTests.swift
//  Fitness CoachTests
//
//  Forma — forma proof copy, builder, routing, and analytics tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingFormaProofTests: XCTestCase {

    private let unsafeCopyFragments = [
        "~2 kg",
        "~5 kg",
        "Lose 2X more",
        "Lose more weight with Forma",
        "Dynamic Calories",
        "automatic calorie adjustment"
    ]

    func testFormaProofStepUsesEmptyShellCopy() {
        XCTAssertEqual(OnboardingStep.formaProof.title, "")
        XCTAssertEqual(OnboardingStep.formaProof.subtitle, "")
        XCTAssertTrue(OnboardingStep.formaProof.usesFixedViewportShell)
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.FormaProof.continueCTA,
            "Review my blueprint"
        )
    }

    func testFormaProofDoesNotUseRedundantIntroParagraph() {
        let removedIntro = "Forma turns your goal into a daily plan"
        let removedSupport =
            "Clear targets, simple logging, and progress tracking help you stay consistent."

        XCTAssertFalse(
            OnboardingStep.formaProof.title.contains(removedIntro)
        )
        XCTAssertFalse(
            OnboardingStep.formaProof.subtitle.contains(removedSupport)
        )
        XCTAssertFalse(
            FormaProductCopy.Onboarding.Flow.FormaProof.Fallback.supporting.contains(removedIntro)
        )
    }

    func testFormaProofRoutesNextToReview() {
        XCTAssertEqual(
            OnboardingStep.formaProof.next(in: OnboardingStep.flow),
            .review
        )
    }

    func testFormaProofDoesNotShowDuplicateProgressHeader() {
        XCTAssertFalse(OnboardingStep.formaProof.showsProgressHeader)
    }

    func testLossCopyIsGoalAware() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: -3.5, unitSystem: .metric)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertEqual(proof.goalIntentLabel, "Lose")
        XCTAssertEqual(proof.targetWeightLabel, "66.5 kg")
        XCTAssertEqual(proof.visionHeadline, FormaProductCopy.Onboarding.Flow.FormaProof.visionHeadline)
        XCTAssertEqual(
            proof.visionSupporting,
            FormaProductCopy.Onboarding.Flow.FormaProof.Loss.supporting(targetWeightLabel: "66.5 kg")
        )
        XCTAssertEqual(proof.pathStyle, .loss)
        XCTAssertTrue(proof.isPersonalized)
        XCTAssertTrue(proof.accessibilityLabel.contains("Lose target 66.5 kg"))
    }

    func testGainCopyIsGoalAware() {
        let state = makeFormState(currentKg: 66, goalDeltaKg: 4, unitSystem: .metric)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertEqual(proof.goalIntentLabel, "Gain")
        XCTAssertEqual(proof.targetWeightLabel, "70 kg")
        XCTAssertEqual(proof.pathStyle, .gain)
        XCTAssertEqual(proof.benefits[0].title, "Fuel targets that make sense")
    }

    func testMaintainCopyIsGoalAware() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: 0, unitSystem: .metric)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertEqual(proof.goalIntentLabel, "Maintain")
        XCTAssertEqual(proof.targetWeightLabel, "70 kg")
        XCTAssertEqual(proof.pathStyle, .maintain)
        XCTAssertEqual(proof.ringProgress, 1)
        XCTAssertEqual(proof.benefits[0].title, "Guardrails, not restrictions")
    }

    func testFallbackCopyWhenWeightsMissing() {
        let proof = OnboardingFormaProofBuilder.build(from: OnboardingFormState())

        XCTAssertEqual(proof.visionHeadline, FormaProductCopy.Onboarding.Flow.FormaProof.visionHeadline)
        XCTAssertEqual(proof.goalIntentLabel, FormaProductCopy.Onboarding.Flow.FormaProof.Fallback.intentLabel)
        XCTAssertFalse(proof.isPersonalized)
        XCTAssertEqual(proof.pathStyle, .fallback)
    }

    func testImperialFormatting() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: -3.5, unitSystem: .imperial)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertTrue(proof.targetWeightLabel.contains("lb"))
        XCTAssertTrue(proof.accessibilityLabel.contains("pounds"))
    }

    func testFormaProofCopyAvoidsUnsafeClaims() {
        let samples = allFormaProofCopySamples()
        for sample in samples {
            let lowered = sample.lowercased()
            for fragment in unsafeCopyFragments {
                XCTAssertFalse(
                    lowered.contains(fragment.lowercased()),
                    "Unsafe fragment \"\(fragment)\" found in: \(sample)"
                )
            }
        }
    }

    func testRestoredDraftValuesProducePersonalizedProof() throws {
        let defaults = UserDefaults(suiteName: "OnboardingFormaProofTests.\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.setWeightKg(78, in: &formState)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-5, in: &formState)

        let store = OnboardingDraftStore(userDefaults: defaults)
        store.saveDraft(OnboardingDraft(formState: formState, step: .formaProof))
        let restored = try XCTUnwrap(store.loadDraft()?.makeFormState())
        let proof = OnboardingFormaProofBuilder.build(from: restored)

        XCTAssertEqual(proof.targetWeightLabel, "73 kg")
        XCTAssertEqual(proof.goalIntentLabel, "Lose")
        XCTAssertTrue(proof.isPersonalized)
    }

    // MARK: - Helpers

    private func makeFormState(
        currentKg: Double,
        goalDeltaKg: Double,
        unitSystem: UnitSystem
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        state.unitSystem = unitSystem
        OnboardingHeightWeightValues.setWeightKg(currentKg, in: &state)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(goalDeltaKg, in: &state)
        return state
    }

    private func allFormaProofCopySamples() -> [String] {
        let copy = FormaProductCopy.Onboarding.Flow.FormaProof.self
        let comparison = copy.Comparison.self
        return [
            copy.visionHeadline,
            copy.Fallback.supporting,
            copy.Fallback.trustNote,
            copy.Loss.supporting(targetWeightLabel: "70 kg"),
            copy.Gain.supporting(targetWeightLabel: "70 kg"),
            copy.Maintain.supporting(targetWeightLabel: "70 kg"),
            copy.Loss.benefits.map(\.title).joined(separator: " "),
            copy.Gain.benefits.map(\.title).joined(separator: " "),
            copy.Maintain.benefits.map(\.title).joined(separator: " "),
            comparison.withoutStructureTitle,
            comparison.withFormaTitle,
            comparison.withoutBullets.joined(separator: " "),
            comparison.withFormaBullets.joined(separator: " "),
            copy.Trust.personalized
        ]
    }
}

@MainActor
final class OnboardingFormaProofAnalyticsTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private let analytics = CapturingOnboardingAnalyticsLogger()

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingFormaProofAnalyticsTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testFormaProofLogsStepViewedAndCompletedOnNext() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(integration: integration)
        await OnboardingModelTestSupport.advanceTo(.formaProof, model: model, seedForm: true)

        XCTAssertEqual(model.currentStep, .formaProof)
        XCTAssertTrue(analytics.contains(.stepViewed, step: "forma_proof"))
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["stage"], OnboardingStage.proof.rawValue)

        model.goNext()

        XCTAssertEqual(model.currentStep, .review)
        XCTAssertTrue(analytics.contains(.stepCompleted, step: "forma_proof"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "review"))
    }

    func testFormaProofBackRoutesToAlmostThere() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(integration: integration)
        await OnboardingModelTestSupport.advanceTo(.formaProof, model: model, seedForm: true)

        model.goBack()

        XCTAssertEqual(model.currentStep, .almostThere)
    }

    private func makeOnboardingModel(
        integration: TrainingIntegrationProviding
    ) throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsLogger: analytics,
            analyticsEntry: .preAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: integration
        )
    }
}
