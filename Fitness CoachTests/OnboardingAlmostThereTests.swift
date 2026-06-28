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
            "Your personalized coach is waiting."
        )
        XCTAssertEqual(
            OnboardingStep.almostThere.subtitle,
            ""
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AlmostThere.headline,
            "Your personalized coach is waiting."
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AlmostThere.supporting,
            "You don't need more motivation. You need a plan built from your body, goal, and how you actually live."
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AlmostThere.continueCTA,
            "See what's next"
        )
    }

    func testAlmostThereUsesFixedViewportShell() {
        XCTAssertTrue(OnboardingStep.almostThere.usesFixedViewportShell)
    }

    func testAlmostThereBenefitsMatchProductCopy() {
        let benefits = OnboardingAlmostThereValues.benefits
        XCTAssertEqual(benefits.count, 3)
        XCTAssertEqual(benefits.map(\.title), [
            "Know what to do today",
            "Stop restarting every Monday",
            "Progress you can sustain"
        ])
    }

    func testAlmostThereBenefitsAccessibilityLabel() {
        XCTAssertEqual(
            OnboardingAlmostThereValues.benefitsAccessibilityLabel,
            "What changes: Know what to do today. Stop restarting every Monday. Progress you can sustain."
        )
    }

    func testAlmostThereRoutesNextToFormaProof() {
        XCTAssertEqual(
            OnboardingStep.almostThere.next(in: OnboardingStep.flow),
            .formaProof
        )
    }

    func testAlmostThereBenefitsUseProductionSafeCopy() {
        let benefits = OnboardingAlmostThereValues.benefits
        XCTAssertEqual(benefits.count, 3)
        XCTAssertEqual(benefits[0].icon, "sun.max.fill")
        XCTAssertEqual(benefits[1].icon, "arrow.counterclockwise")
        XCTAssertEqual(benefits[2].icon, "chart.line.uptrend.xyaxis")
    }

    func testAlmostThereCopyAvoidsUnimplementedClaims() {
        let copy = FormaProductCopy.Onboarding.Flow.AlmostThere.self
        let joined = [
            copy.title,
            copy.subtitle,
            copy.headline,
            copy.supporting,
            copy.trustFooter,
            copy.benefitsAccessibilityLabel,
            copy.accessibilitySummary
        ].joined(separator: " ")
            + OnboardingAlmostThereValues.benefits.map(\.title).joined(separator: " ")

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
            OnboardingAlmostThereValues.accessibilitySummary.contains("Your personalized coach is waiting")
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
