//
//  OnboardingAnalyticsLoggingTests.swift
//  Fitness CoachTests
//
//  Forma — Onboarding analytics property builder and model wiring tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingAnalyticsContextBuilderTests: XCTestCase {

    func testGoalDirectionUsesCutMaintainGainLabels() {
        var form = OnboardingFormState()
        form.currentWeightKgText = "80"
        form.goalWeightKgText = "70"
        XCTAssertEqual(OnboardingAnalyticsContextBuilder.goalDirection(from: form), "cut")

        form.goalWeightKgText = "80"
        XCTAssertEqual(OnboardingAnalyticsContextBuilder.goalDirection(from: form), "maintain")

        form.goalWeightKgText = "85"
        XCTAssertEqual(OnboardingAnalyticsContextBuilder.goalDirection(from: form), "gain")
    }

    func testEstimatedWeeksExtractsDigitsOnly() {
        let reveal = OnboardingPlanRevealState(
            goalDirection: .cut,
            currentWeightLabel: "72 kg",
            goalWeightLabel: "65 kg",
            goalProgressLabel: "72 kg → 65 kg",
            goalHeroSectionTitle: FormaProductCopy.Onboarding.V2.PlanReveal.GoalHero.sectionTitle,
            goalHeroHeadline: "Lose toward 65 kg",
            goalHeroProgressLine: "From 72 kg to 65 kg",
            goalHeroSupport: FormaProductCopy.Onboarding.V2.PlanReveal.GoalHero.lossSupport,
            dailyMissionSectionTitle: FormaProductCopy.Onboarding.V2.PlanReveal.dailyMissionSectionTitle,
            dailyMissionCalorieLine: "1,800 kcal / day",
            focusTitle: FormaProductCopy.Onboarding.V2.PlanReveal.Focus.lossTitle,
            focusBody: FormaProductCopy.Onboarding.V2.PlanReveal.Focus.lossBody,
            nextStepLine: FormaProductCopy.Onboarding.V2.PlanReveal.nextStepLine,
            accessibilitySummary: "Your Forma plan is ready.",
            estimatedWeeksLabel: "About 15 weeks",
            journeySummaryLine: "Lose toward 65 kg with clear daily targets.",
            strategyLabel: FormaProductCopy.Onboarding.V2.PlanReveal.Strategy.moderateCut,
            dailyCalorieLabel: "1,800 kcal",
            calorieExplanationLine: FormaProductCopy.Onboarding.V2.PlanReveal.cutCalorieExplanation,
            proteinLabel: "150 g",
            waterLabel: "2,800 ml",
            planStatus: OnboardingPlanRevealStatus(
                title: FormaProductCopy.Onboarding.V2.PlanReveal.Status.sustainableTitle,
                body: nil,
                style: .positive
            )
        )
        XCTAssertEqual(
            OnboardingAnalyticsContextBuilder.estimatedWeeks(from: reveal),
            "15"
        )
    }
}

@MainActor
final class OnboardingModelAnalyticsTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private let analytics = CapturingOnboardingAnalyticsLogger()

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingModelAnalyticsTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testFreshSessionLogsStartedAndStepViewed() throws {
        _ = try makeModel(entry: .preAuth)

        XCTAssertTrue(analytics.contains(.started))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "intro_proof"))
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["entry"], "preAuth")
        XCTAssertNil(analytics.lastProperties(for: .stepViewed)?["v2Enabled"])
    }

    func testStepCompletedIncludesDuration() throws {
        let model = try makeModel()
        OnboardingModelTestSupport.seedCanonicalForm(&model.formState)
        model.goNext()

        XCTAssertTrue(analytics.contains(.stepCompleted, step: "intro_proof"))
        XCTAssertNotNil(analytics.lastProperties(for: .stepCompleted)?["durationMs"])
        XCTAssertNil(analytics.lastProperties(for: .stepCompleted)?["v2Enabled"])
    }

    func testStepEventsOmitLegacyPreferenceAnalytics() throws {
        let model = try makeModel()
        OnboardingModelTestSupport.seedCanonicalForm(&model.formState)
        model.formState.loggingPreferences = [.quickTaps, .noPressure]
        model.goNext()

        let completed = analytics.lastProperties(for: .stepCompleted)
        XCTAssertNil(completed?["loggingMode"])
        XCTAssertNil(completed?["goalDirection"])
    }

    func testPlanGenerationLogsPlanContext() async throws {
        let model = try makeModel()
        await OnboardingModelTestSupport.advanceTo(.review, model: model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()

        XCTAssertTrue(analytics.contains(.planGenerated))
        XCTAssertTrue(analytics.contains(.planRevealed, step: "plan_reveal"))
        XCTAssertEqual(analytics.lastProperties(for: .planGenerated)?["goalDirection"], "maintain")
        XCTAssertNil(analytics.lastProperties(for: .planGenerated)?["loggingMode"])
    }

    func testSignInCancelledLogsDedicatedEvent() async throws {
        let model = try makeModel()
        await OnboardingModelTestSupport.advanceTo(.review, model: model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()
        model.prepareForSavePlan()
        XCTAssertEqual(model.currentStep, .savePlan)

        model.handleSignInCompletionFailure(wasCancelled: true)

        XCTAssertTrue(analytics.contains(.signInCancelled))
    }

    // MARK: - Helpers

    private func makeModel(entry: OnboardingAnalyticsEntry = .preAuth) throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsLogger: analytics,
            analyticsEntry: entry,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }
}
