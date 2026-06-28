//
//  OnboardingV4CompletionTests.swift
//  Fitness CoachTests
//
//  Forma — V4 review tail, plan generation, and save-plan completion tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV4PersonalizationSummaryTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let referenceDate = FormaCalculationTestFixtures.referenceDate

    func testV4ReviewStepUsesDedicatedCopy() {
        XCTAssertEqual(
            OnboardingV4Step.review.title,
            FormaProductCopy.Onboarding.V4.Summary.title
        )
        XCTAssertEqual(
            OnboardingV4Step.review.subtitle,
            FormaProductCopy.Onboarding.V4.Summary.subtitle
        )
    }

    func testV4RecapCardsShowRequiredFieldsOnly() throws {
        let state = try validV4FormState()
        let cards = OnboardingPersonalizationSummaryBuilder.recapCards(
            for: state,
            usesV4Steps: true,
            referenceDate: referenceDate
        )

        XCTAssertEqual(cards.count, 6)
        XCTAssertEqual(cards.map(\.id), ["height", "currentWeight", "targetWeight", "age", "sex", "activity"])

        let copy = FormaProductCopy.Onboarding.V4.Summary.self
        XCTAssertEqual(cards[0].title, copy.heightLabel)
        XCTAssertEqual(cards[1].title, copy.currentWeightLabel)
        XCTAssertEqual(cards[2].title, copy.targetWeightLabel)
        XCTAssertEqual(cards[3].title, copy.ageLabel)
        XCTAssertEqual(cards[4].title, copy.sexLabel)
        XCTAssertEqual(cards[5].title, copy.activityLabel)

        XCTAssertFalse(cards.contains { $0.title == FormaProductCopy.Onboarding.V2.Summary.paceLabel })
        XCTAssertFalse(cards.contains { $0.title == FormaProductCopy.Onboarding.V2.Summary.preferencesLabel })
        XCTAssertFalse(cards.contains { $0.title == FormaProductCopy.Onboarding.V2.Summary.motivationLabel })
        XCTAssertFalse(cards[5].value.contains("training days"))
        XCTAssertFalse(cards[5].value.contains("steps"))
    }

    func testV4RecapAgeUsesBirthDateNotManualAgeText() throws {
        var state = try validV4FormState()
        state.ageText = "99"

        let cards = OnboardingPersonalizationSummaryBuilder.recapCards(
            for: state,
            usesV4Steps: true,
            referenceDate: referenceDate
        )

        let expectedAge = BirthDateAgeResolver.age(
            from: try XCTUnwrap(state.birthDate),
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertEqual(cards.first { $0.id == "age" }?.value, String(expectedAge))
        XCTAssertNotEqual(cards.first { $0.id == "age" }?.value, "99")
    }

    func testV4ValidationUsesRequiredV4StepsOnly() throws {
        var state = try validV4FormState()
        state.ageText = ""
        state.averageStepsText = ""
        state.trainingFrequencyPerWeekText = ""
        state.selectedMotivations = []

        XCTAssertTrue(OnboardingPersonalizationSummaryBuilder.isReadyToGenerate(for: state, usesV4Steps: true))
        XCTAssertNil(OnboardingPersonalizationSummaryBuilder.validationMessage(for: state, usesV4Steps: true))
    }

    func testV4ValidationRoutesToBirthdayWhenMissing() {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &state)
        state.sex = .female
        state.activityLevel = .moderatelyActive

        XCTAssertEqual(
            OnboardingPersonalizationSummaryBuilder.firstInvalidRequiredStep(for: state, usesV4Steps: true),
            OnboardingV4DraftBridge.persistedLegacyStep(for: .birthday, formState: state)
        )
    }

    func testDraftRoundTripAtReviewPreservesBirthDateForRestore() throws {
        let birthDate = calendar.date(from: DateComponents(year: 1992, month: 11, day: 8))!
        var formState = try validV4FormState(birthDate: birthDate)

        let draft = OnboardingDraft(
            formState: formState,
            currentStep: OnboardingV4DraftBridge.persistedLegacyStep(for: .review, formState: formState)
        )
        let restored = draft.makeFormState()

        XCTAssertEqual(restored.birthDate, birthDate)
        XCTAssertEqual(restored.sex, .female)
        XCTAssertEqual(
            try restored.resolvedAge(referenceDate: referenceDate),
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar)
        )
    }

    // MARK: - Helpers

    private func validV4FormState(
        birthDate: Date? = nil
    ) throws -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &state)
        if let birthDate {
            state.birthDate = birthDate
        } else {
            OnboardingV4BirthdayValues.applyDefaultsIfNeeded(to: &state)
        }
        state.sex = .female
        state.activityLevel = .moderatelyActive
        OnboardingV4ActivityLevelValues.applyDefaultsIfNeeded(to: &state)
        return state
    }
}

@MainActor
final class OnboardingV4CompletionPathTests: XCTestCase {

    private var v2FlagPrevious = false
    private var v3FlagPrevious: Bool?
    private var v4FlagPrevious: Bool?
    private var draftSuiteName: String!
    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private var analytics: CapturingOnboardingV4CompletionAnalyticsLogger!

    private let calendar = Calendar(identifier: .gregorian)
    private let referenceDate = FormaCalculationTestFixtures.referenceDate

    override func setUp() async throws {
        try await super.setUp()
        v2FlagPrevious = UserDefaults.standard.bool(forKey: OnboardingV2FeatureFlag.enabledKey)
        v3FlagPrevious = UserDefaults.standard.object(forKey: OnboardingV3FeatureFlag.enabledKey) as? Bool
        v4FlagPrevious = UserDefaults.standard.object(forKey: OnboardingV4FeatureFlag.enabledKey) as? Bool

        UserDefaults.standard.set(true, forKey: OnboardingV2FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV3FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV4FeatureFlag.enabledKey)

        draftSuiteName = "OnboardingV4CompletionPathTests.\(UUID().uuidString)"
        draftDefaults = UserDefaults(suiteName: draftSuiteName)!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
        draftStore.clearDraft()
        analytics = CapturingOnboardingV4CompletionAnalyticsLogger()
    }

    override func tearDown() async throws {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftSuiteName)
        UserDefaults.standard.set(v2FlagPrevious, forKey: OnboardingV2FeatureFlag.enabledKey)
        if let v3FlagPrevious {
            UserDefaults.standard.set(v3FlagPrevious, forKey: OnboardingV3FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV3FeatureFlag.enabledKey)
        }
        if let v4FlagPrevious {
            UserDefaults.standard.set(v4FlagPrevious, forKey: OnboardingV4FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV4FeatureFlag.enabledKey)
        }
        try await super.tearDown()
    }

    func testFormaProofRoutesThroughFullTailToSavePlan() async throws {
        let container = try AppContainer(inMemory: true)
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeV4Model(container: container, integration: integration)
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 6, day: 15))!

        seedValidV4Form(&model.formState, birthDate: birthDate)
        try await advanceModelToFormaProof(model)

        model.goNext()
        XCTAssertEqual(model.currentV4Step, .review)
        XCTAssertFalse(model.hasCommittedLocalProfile)
        XCTAssertNil(try container.userProfileService.getCurrentProfile())

        model.goNext()
        try await waitForPlanReveal(model)

        XCTAssertEqual(model.currentV4Step, .planReveal)
        XCTAssertNotNil(model.generatedPlan)
        XCTAssertFalse(model.hasCommittedLocalProfile)
        XCTAssertNil(try container.userProfileService.getCurrentProfile())

        let input = try model.formState.makeCalorieTargetInput(referenceDate: referenceDate)
        XCTAssertEqual(
            input.age,
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar)
        )
        XCTAssertEqual(input.activityLevel, model.formState.activityLevel)
        XCTAssertNotNil(input.goalWeightKg)

        model.goNext()
        XCTAssertEqual(model.currentV4Step, .savePlan)
        XCTAssertTrue(model.hasCommittedLocalProfile)
        XCTAssertNotNil(try container.userProfileService.getCurrentProfile())

        let profile = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertEqual(profile.birthDate, birthDate)
        XCTAssertEqual(
            profile.age,
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar)
        )
        XCTAssertNil(draftStore.loadDraft())

        model.goNext()
        XCTAssertEqual(model.pendingCompletionIntent, .signIn)
        XCTAssertNotNil(model.generatedPlan)
    }

    func testReviewGenerationUsesTrainingDefaultsWithoutManualRhythmFields() async throws {
        let container = try AppContainer(inMemory: true)
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeV4Model(container: container, integration: integration)
        let birthDate = calendar.date(from: DateComponents(year: 1995, month: 3, day: 20))!

        seedValidV4Form(&model.formState, birthDate: birthDate)
        model.formState.averageStepsText = ""
        model.formState.trainingFrequencyPerWeekText = ""
        try await advanceModelToReview(model)

        model.goNext()
        try await waitForPlanReveal(model)

        let input = try model.formState.makeCalorieTargetInput(referenceDate: referenceDate)
        XCTAssertGreaterThan(input.trainingFrequencyPerWeek, 0)
        XCTAssertGreaterThan(input.averageSteps, 0)
        XCTAssertEqual(
            input.age,
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar)
        )
    }

    func testReviewLogsAnalyticsAndGenerationEvents() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeV4Model(integration: integration)

        seedValidV4Form(&model.formState)
        try await advanceModelToReview(model)

        model.goNext()
        try await waitForPlanReveal(model)

        XCTAssertTrue(analytics.contains(.stepCompleted, step: "review"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "generatingPlan"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "planReveal"))
        XCTAssertTrue(analytics.contains(.planGenerated))
        XCTAssertTrue(analytics.contains(.planRevealed))
    }

    // MARK: - Helpers

    private func makeV4Model(
        container: AppContainer? = nil,
        integration: TrainingIntegrationProviding
    ) throws -> OnboardingModel {
        let resolvedContainer = try container ?? AppContainer(inMemory: true)
        return OnboardingModel(
            userProfileService: resolvedContainer.userProfileService,
            targetService: resolvedContainer.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsLogger: analytics,
            analyticsEntry: .preAuth,
            flowScope: .v2Full,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: integration
        )
    }

    private func advanceModelToReview(_ model: OnboardingModel) async throws {
        try await advanceModelToFormaProof(model)
        model.goNext()
        XCTAssertEqual(model.currentV4Step, .review)
    }

    private func advanceModelToFormaProof(_ model: OnboardingModel) async throws {
        try await advanceModelToAlmostThere(model)
        model.goNext()
        XCTAssertEqual(model.currentV4Step, .formaProof)
    }

    private func advanceModelToAlmostThere(_ model: OnboardingModel) async throws {
        model.goNext() // introProof -> heightWeight
        model.goNext() // heightWeight
        model.goNext() // targetWeight
        model.goNext() // targetEncouragement
        model.goNext() // birthday
        model.goNext() // activityLevel
        model.goNext() // appleHealth

        for _ in 0..<50 {
            if model.currentV4Step == .almostThere { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(model.currentV4Step, .almostThere)
    }

    private func waitForPlanReveal(_ model: OnboardingModel) async throws {
        XCTAssertEqual(model.currentV4Step, .generatingPlan)

        for _ in 0..<100 {
            if model.currentV4Step == .planReveal { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(model.currentV4Step, .planReveal)
    }

    private func seedValidV4Form(
        _ formState: inout OnboardingFormState,
        birthDate: Date? = nil
    ) {
        OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        if let birthDate {
            formState.birthDate = birthDate
            formState.syncAgeTextFromBirthDate(referenceDate: referenceDate)
        } else {
            OnboardingV4BirthdayValues.applyDefaultsIfNeeded(to: &formState)
        }
        formState.sex = .female
        formState.activityLevel = .moderatelyActive
        OnboardingV4ActivityLevelValues.applyDefaultsIfNeeded(to: &formState)
    }
}

private final class CapturingOnboardingV4CompletionAnalyticsLogger: OnboardingAnalyticsLogging, @unchecked Sendable {

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

    func contains(_ event: OnboardingAnalyticsEvent, step: String? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return records.contains { record in
            guard record.event == event else { return false }
            if let step, record.properties.step != step { return false }
            return true
        }
    }
}
