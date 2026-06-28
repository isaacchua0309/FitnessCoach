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
            "Continue"
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
        XCTAssertNotEqual(
            FormaProductCopy.Onboarding.Flow.FormaProof.Fallback.title,
            removedIntro
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

        XCTAssertEqual(proof.title, FormaProductCopy.Onboarding.Flow.FormaProof.Loss.title)
        XCTAssertEqual(proof.subtitle, FormaProductCopy.Onboarding.Flow.FormaProof.Loss.subtitle)
        XCTAssertEqual(proof.heroMetric, "Lose toward 66.5 kg")
        XCTAssertEqual(proof.journeyLine, "70 kg → 66.5 kg")
        XCTAssertEqual(proof.pathStyle, .loss)
        XCTAssertTrue(proof.isPersonalized)
        XCTAssertTrue(proof.accessibilityLabel.contains("lose weight steadily"))
    }

    func testGainCopyIsGoalAware() {
        let state = makeFormState(currentKg: 66, goalDeltaKg: 4, unitSystem: .metric)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertEqual(proof.title, FormaProductCopy.Onboarding.Flow.FormaProof.Gain.title)
        XCTAssertEqual(proof.heroMetric, "Gain toward 70 kg")
        XCTAssertEqual(proof.journeyLine, "66 kg → 70 kg")
        XCTAssertEqual(proof.pathStyle, .gain)
        XCTAssertEqual(proof.comparison.withoutHeadline, FormaProductCopy.Onboarding.Flow.FormaProof.Gain.withoutHeadline)
    }

    func testMaintainCopyIsGoalAware() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: 0, unitSystem: .metric)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertEqual(proof.title, FormaProductCopy.Onboarding.Flow.FormaProof.Maintain.title)
        XCTAssertEqual(proof.heroMetric, "Maintain around 70 kg")
        XCTAssertEqual(proof.pathStyle, .maintain)
        XCTAssertEqual(proof.comparison.withHeadline, FormaProductCopy.Onboarding.Flow.FormaProof.Maintain.withHeadline)
    }

    func testFallbackCopyWhenWeightsMissing() {
        let proof = OnboardingFormaProofBuilder.build(from: OnboardingFormState())

        XCTAssertEqual(proof.title, FormaProductCopy.Onboarding.Flow.FormaProof.Fallback.title)
        XCTAssertNil(proof.journeyLine)
        XCTAssertFalse(proof.isPersonalized)
        XCTAssertEqual(proof.pathStyle, .fallback)
    }

    func testImperialFormatting() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: -3.5, unitSystem: .imperial)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertTrue(proof.heroMetric.contains("lb"))
        XCTAssertTrue(proof.journeyLine?.contains("lb") == true)
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
        OnboardingTargetWeightValues.setGoalFromLossKg(5, in: &formState)

        let store = OnboardingDraftStore(userDefaults: defaults)
        store.saveDraft(OnboardingDraft(formState: formState, step: .formaProof))
        let restored = try XCTUnwrap(store.loadDraft()?.makeFormState())
        let proof = OnboardingFormaProofBuilder.build(from: restored)

        XCTAssertEqual(proof.heroMetric, "Lose toward 73 kg")
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
            copy.Fallback.title,
            copy.Fallback.subtitle,
            copy.Fallback.heroMetric,
            copy.Fallback.heroSupporting,
            copy.Loss.title,
            copy.Loss.subtitle,
            copy.Loss.heroSupporting,
            copy.Loss.withoutHeadline,
            copy.Loss.withHeadline,
            copy.Gain.title,
            copy.Gain.subtitle,
            copy.Gain.withoutHeadline,
            copy.Gain.withHeadline,
            copy.Maintain.title,
            copy.Maintain.subtitle,
            copy.Maintain.withoutHeadline,
            copy.Maintain.withHeadline,
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
            userProfileService: container.userProfileService,
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
