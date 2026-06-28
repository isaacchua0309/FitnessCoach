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
            currentWeightLabel: "72 kg",
            goalWeightLabel: "65 kg",
            goalProgressLabel: "72 kg → 65 kg",
            estimatedWeeksLabel: "About 15 weeks",
            journeySummaryLine: "Cut to 65 kg",
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
        seedValidForm(&model.formState)
        model.goNext()

        XCTAssertTrue(analytics.contains(.stepCompleted, step: "intro_proof"))
        XCTAssertNotNil(analytics.lastProperties(for: .stepCompleted)?["durationMs"])
        XCTAssertNil(analytics.lastProperties(for: .stepCompleted)?["v2Enabled"])
    }

    func testStepEventsOmitLegacyPreferenceAnalytics() throws {
        let model = try makeModel()
        seedValidForm(&model.formState)
        model.formState.loggingPreferences = [.quickTaps, .noPressure]
        model.goNext()

        let completed = analytics.lastProperties(for: .stepCompleted)
        XCTAssertNil(completed?["loggingMode"])
        XCTAssertNil(completed?["goalDirection"])
    }

    func testPlanGenerationLogsPlanContext() async throws {
        let model = try makeModel()
        seedValidForm(&model.formState)
        navigateToReview(model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()

        XCTAssertTrue(analytics.contains(.planGenerated))
        XCTAssertTrue(analytics.contains(.planRevealed, step: "plan_reveal"))
        XCTAssertEqual(analytics.lastProperties(for: .planGenerated)?["goalDirection"], "cut")
        XCTAssertNil(analytics.lastProperties(for: .planGenerated)?["loggingMode"])
    }

    func testSignInCancelledLogsDedicatedEvent() async throws {
        let model = try makeModel()
        seedValidForm(&model.formState)
        navigateToReview(model)
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

    private func seedValidForm(_ formState: inout OnboardingFormState) {
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &formState)
        formState.sex = .female
        formState.activityLevel = .moderatelyActive
        OnboardingActivityLevelValues.applyDefaultsIfNeeded(to: &formState)
        formState.selectPaceChoice(.moderate)
    }

    private func navigateToReview(_ model: OnboardingModel) {
        seedValidForm(&model.formState)
        while model.currentStep != .review {
            model.goNext()
        }
    }
}

private final class CapturingOnboardingAnalyticsLogger: OnboardingAnalyticsLogging, @unchecked Sendable {

    struct Record: Sendable {
        let event: OnboardingAnalyticsEvent
        let properties: OnboardingAnalyticsProperties
    }

    private let lock = NSLock()
    private var records: [Record] = []

    func log(_ event: OnboardingAnalyticsEvent, properties: OnboardingAnalyticsProperties) {
        lock.lock()
        records.append(Record(event: event, properties: properties))
        lock.unlock()
    }

    func contains(
        _ event: OnboardingAnalyticsEvent,
        step: String? = nil
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return records.contains { record in
            guard record.event == event else { return false }
            if let step, record.properties.step != step { return false }
            return true
        }
    }

    func lastProperties(for event: OnboardingAnalyticsEvent) -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        guard let record = records.last(where: { $0.event == event }) else { return nil }
        return record.properties.asParameters()
    }
}
