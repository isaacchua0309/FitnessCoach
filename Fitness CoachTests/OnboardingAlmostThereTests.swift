//
//  OnboardingAlmostThereTests.swift
//  Fitness CoachTests
//
//  Forma — almost there copy, routing, and analytics tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingAlmostThereTests: XCTestCase {

    func testAlmostThereStepUsesProductCopy() {
        XCTAssertEqual(
            OnboardingStep.almostThere.title,
            "Your plan is almost ready"
        )
        XCTAssertEqual(
            OnboardingStep.almostThere.subtitle,
            "We've got what we need to build your personalized plan."
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AlmostThere.summaryHeadline,
            "Forma turns your plan into daily actions."
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AlmostThere.summarySupporting,
            "Track meals, follow your targets, and see progress over time."
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AlmostThere.valueSectionTitle,
            "What you'll get"
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AlmostThere.continueCTA,
            "Continue"
        )
    }

    func testAlmostThereUsesFixedViewportShell() {
        XCTAssertTrue(OnboardingStep.almostThere.usesFixedViewportShell)
    }

    func testAlmostThereValueRowsMatchFeatureTitles() {
        let rows = OnboardingAlmostThereValues.valueRows
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows, [
            "Fast meal tracking",
            "Daily targets",
            "Progress journey",
            "Smart coaching"
        ])
    }

    func testAlmostThereValueSectionAccessibilityLabel() {
        XCTAssertEqual(
            OnboardingAlmostThereValues.valueSectionAccessibilityLabel,
            "What you'll get: Fast meal tracking, Daily targets, Progress journey, Smart coaching."
        )
    }

    func testAlmostThereRoutesNextToFormaProof() {
        XCTAssertEqual(
            OnboardingStep.almostThere.next(in: OnboardingStep.flow),
            .formaProof
        )
    }

    func testAlmostThereFeaturesUseProductionSafeCopy() {
        let features = OnboardingAlmostThereValues.features
        XCTAssertEqual(features.count, 4)
        XCTAssertEqual(features[0].title, "Fast meal tracking")
        XCTAssertEqual(features[1].title, "Daily targets")
        XCTAssertEqual(features[2].title, "Progress journey")
        XCTAssertEqual(features[3].title, "Smart coaching")
    }

    func testAlmostThereCopyAvoidsUnimplementedClaims() {
        let copy = FormaProductCopy.Onboarding.Flow.AlmostThere.self
        let joined = [
            copy.title,
            copy.subtitle,
            copy.summaryHeadline,
            copy.summarySupporting,
            copy.valueSectionTitle,
            copy.valueSectionAccessibilityLabel,
            copy.trustStrip,
            copy.accessibilitySummary
        ].joined(separator: " ")
            + OnboardingAlmostThereValues.features.map { "\($0.title) \($0.subtitle)" }.joined(separator: " ")

        XCTAssertFalse(joined.localizedCaseInsensitiveContains("challenge friends"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("leaderboard"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("adaptive goal"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("dynamic calories"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("adjust automatically"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("adjust to your lifestyle"))
    }

    func testAlmostThereAccessibilitySummary() {
        XCTAssertEqual(
            OnboardingAlmostThereValues.accessibilitySummary,
            FormaProductCopy.Onboarding.Flow.AlmostThere.accessibilitySummary
        )
        XCTAssertTrue(
            OnboardingAlmostThereValues.accessibilitySummary.contains("Your plan is almost ready")
        )
    }

    func testAlmostThereStepDoesNotShowProgressHeaderInShell() {
        XCTAssertFalse(OnboardingStep.almostThere.showsProgressHeader)
    }
}

@MainActor
final class OnboardingAlmostThereAnalyticsTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private let analytics = CapturingOnboardingAnalyticsLogger()

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingAlmostThereAnalyticsTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testAlmostThereLogsStepViewedAndCompletedOnNext() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(integration: integration)
        await OnboardingModelTestSupport.advanceTo(.almostThere, model: model, seedForm: true)

        XCTAssertEqual(model.currentStep, .almostThere)
        XCTAssertTrue(analytics.contains(.stepViewed, step: "almost_there"))
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["stage"], OnboardingStage.proof.rawValue)

        model.goNext()

        XCTAssertEqual(model.currentStep, .formaProof)
        XCTAssertTrue(analytics.contains(.stepCompleted, step: "almost_there"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "forma_proof"))
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
