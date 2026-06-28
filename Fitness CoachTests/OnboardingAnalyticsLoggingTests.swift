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

    func testLoggingModeOmitsDietNotes() {
        var form = OnboardingFormState()
        form.dietPreference = "No shellfish — private note"
        form.loggingPreferences = [.quickTaps, .noPressure]

        XCTAssertEqual(
            OnboardingAnalyticsContextBuilder.loggingMode(from: form),
            "noPressure,quickTaps"
        )
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

    func testFeedbackKindForPreferencesIgnoresFreeTextDietNotes() {
        var form = OnboardingFormState()
        form.dietPreference = "Allergic to peanuts"

        XCTAssertNil(
            OnboardingAnalyticsContextBuilder.feedbackKind(for: .preferences, formState: form)
        )

        form.loggingPreferences = [.quickTaps]
        XCTAssertEqual(
            OnboardingAnalyticsContextBuilder.feedbackKind(for: .preferences, formState: form),
            "preferences"
        )
    }
}

@MainActor
final class OnboardingModelAnalyticsTests: XCTestCase {

    private var v2FlagPrevious = false
    private var draftSuiteName: String!
    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private var analytics: CapturingOnboardingAnalyticsLogger!

    override func setUp() async throws {
        try await super.setUp()
        v2FlagPrevious = UserDefaults.standard.bool(forKey: OnboardingStepPolicy.featureFlagKey)
        UserDefaults.standard.set(true, forKey: OnboardingStepPolicy.featureFlagKey)

        draftSuiteName = "OnboardingModelAnalyticsTests.\(UUID().uuidString)"
        draftDefaults = UserDefaults(suiteName: draftSuiteName)!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
        draftStore.clearDraft()
        analytics = CapturingOnboardingAnalyticsLogger()
    }

    override func tearDown() async throws {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftSuiteName)
        UserDefaults.standard.set(v2FlagPrevious, forKey: OnboardingStepPolicy.featureFlagKey)
        try await super.tearDown()
    }

    func testFreshSessionLogsStartedAndStepViewed() throws {
        _ = try makeModel(entry: .preAuth)

        XCTAssertTrue(analytics.contains(.started))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "landing"))
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["entry"], "preAuth")
    }

    func testStepCompletedIncludesDurationAndFeedback() throws {
        let model = try makeModel()
        fillValidForm(model)
        while model.currentStep != .activity {
            model.goNext()
        }
        model.goNext()

        XCTAssertTrue(analytics.contains(.stepCompleted, step: "activity"))
        XCTAssertNotNil(analytics.lastProperties(for: .stepCompleted)?["durationMs"])
        XCTAssertTrue(analytics.contains(.feedbackShown, feedbackKind: "activity"))
    }

    func testPlanGenerationLogsPlanEvents() async throws {
        let model = try makeModel()
        fillValidForm(model)
        navigateToSummary(model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()

        XCTAssertTrue(analytics.contains(.planGenerated))
        XCTAssertTrue(analytics.contains(.planRevealed, step: "planReveal"))
        XCTAssertEqual(analytics.lastProperties(for: .planGenerated)?["goalDirection"], "cut")
    }

    func testSignInCancelledLogsDedicatedEvent() async throws {
        let model = try makeModel()
        navigateToSummary(model)
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

    private func fillValidForm(_ model: OnboardingModel) {
        var state = OnboardingFormState()
        state.ageText = "28"
        state.sex = .female
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        state.goalWeightKgText = "65"
        state.activityLevel = .moderatelyActive
        state.trainingFrequencyPerWeekText = "3"
        state.averageStepsText = "5000"
        state.selectPaceChoice(.moderate)
        model.formState = state
    }

    private func navigateToSummary(_ model: OnboardingModel) {
        fillValidForm(model)
        while model.currentStep != .summary {
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
        step: String? = nil,
        feedbackKind: String? = nil
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return records.contains { record in
            guard record.event == event else { return false }
            if let step, record.properties.step != step { return false }
            if let feedbackKind, record.properties.feedbackKind != feedbackKind { return false }
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

private extension OnboardingAnalyticsProperties {
    subscript(key: String) -> String? {
        asParameters()[key]
    }
}
