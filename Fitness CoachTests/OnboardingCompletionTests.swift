//
//  OnboardingCompletionTests.swift
//  Fitness CoachTests
//
//  Forma — review tail, plan generation, and save-plan completion tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingPersonalizationSummaryTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let referenceDate = FormaCalculationTestFixtures.referenceDate

    func testReviewStepUsesDedicatedCopy() {
        XCTAssertEqual(
            OnboardingStep.review.title,
            FormaProductCopy.Onboarding.Flow.Summary.title
        )
        XCTAssertEqual(
            OnboardingStep.review.subtitle,
            FormaProductCopy.Onboarding.Flow.Summary.subtitle
        )
    }

    func testRecapCardsShowRequiredFieldsOnly() throws {
        let state = try validOnboardingFormState()
        let cards = OnboardingPersonalizationSummaryBuilder.recapCards(
            for: state,
            referenceDate: referenceDate
        )

        XCTAssertEqual(cards.count, 6)
        XCTAssertEqual(cards.map(\.id), ["height", "currentWeight", "targetWeight", "age", "sex", "activity"])

        let copy = FormaProductCopy.Onboarding.Flow.Summary.self
        XCTAssertEqual(cards[0].title, copy.heightLabel)
        XCTAssertEqual(cards[1].title, copy.currentWeightLabel)
        XCTAssertEqual(cards[2].title, copy.targetWeightLabel)
        XCTAssertEqual(cards[3].title, copy.ageLabel)
        XCTAssertEqual(cards[4].title, copy.sexLabel)
        XCTAssertEqual(cards[5].title, copy.activityLabel)

        XCTAssertFalse(cards.contains { $0.title == "Pace" })
        XCTAssertFalse(cards.contains { $0.title == "Preferences" })
        XCTAssertFalse(cards.contains { $0.title == "Motivation" })
        XCTAssertFalse(cards[5].value.contains("training days"))
        XCTAssertFalse(cards[5].value.contains("steps"))
    }

    func testRecapAgeUsesBirthDateNotManualAgeText() throws {
        var state = try validOnboardingFormState()
        state.ageText = "99"

        let cards = OnboardingPersonalizationSummaryBuilder.recapCards(
            for: state,
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

    func testValidationUsesRequiredStepsOnly() throws {
        var state = try validOnboardingFormState()
        state.ageText = ""
        state.averageStepsText = ""
        state.trainingFrequencyPerWeekText = ""
        state.selectedMotivations = []

        XCTAssertTrue(OnboardingPersonalizationSummaryBuilder.isReadyToGenerate(for: state))
        XCTAssertNil(OnboardingPersonalizationSummaryBuilder.validationMessage(for: state))
    }

    func testValidationRoutesToBirthdayWhenMissing() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
        state.sex = .female
        state.activityLevel = .moderatelyActive

        XCTAssertEqual(
            OnboardingPersonalizationSummaryBuilder.firstInvalidRequiredStep(for: state),
            .birthday
        )
    }

    func testDraftRoundTripAtReviewPreservesBirthDateForRestore() throws {
        let birthDate = calendar.date(from: DateComponents(year: 1992, month: 11, day: 8))!
        var formState = try validOnboardingFormState(birthDate: birthDate)

        let draft = OnboardingDraft(
            formState: formState,
            step: .review
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

    private func validOnboardingFormState(
        birthDate: Date? = nil
    ) throws -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
        if let birthDate {
            state.birthDate = birthDate
        } else {
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
        }
        state.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        return state
    }
}

@MainActor
final class OnboardingCompletionPathTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private let analytics = CapturingOnboardingCompletionAnalyticsLogger()
    private let calendar = Calendar(identifier: .gregorian)
    private let referenceDate = FormaCalculationTestFixtures.referenceDate

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingCompletionPathTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testFormaProofRoutesThroughFullTailToSavePlan() async throws {
        let container = try AppContainer(inMemory: true)
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(container: container, integration: integration)
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 6, day: 15))!

        seedValidOnboardingForm(&model.formState, birthDate: birthDate)
        await OnboardingModelTestSupport.advanceTo(.formaProof, model: model, seedForm: false)

        model.goNext()
        XCTAssertEqual(model.currentStep, .review)
        XCTAssertFalse(model.hasCommittedLocalProfile)
        XCTAssertNil(try container.userProfileService.getCurrentProfile())

        model.goNext()
        await model.flushPendingGenerationForTesting()
        XCTAssertEqual(model.currentStep, .planReveal)
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
        XCTAssertEqual(model.currentStep, .savePlan)
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
        let model = try makeOnboardingModel(container: container, integration: integration)
        let birthDate = calendar.date(from: DateComponents(year: 1995, month: 3, day: 20))!

        seedValidOnboardingForm(&model.formState, birthDate: birthDate)
        model.formState.averageStepsText = ""
        model.formState.trainingFrequencyPerWeekText = ""
        await OnboardingModelTestSupport.advanceTo(.review, model: model, seedForm: false)

        model.goNext()
        await model.flushPendingGenerationForTesting()
        XCTAssertEqual(model.currentStep, .planReveal)

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
        let model = try makeOnboardingModel(integration: integration)

        seedValidOnboardingForm(&model.formState)
        await OnboardingModelTestSupport.advanceTo(.review, model: model, seedForm: false)

        model.goNext()
        await model.flushPendingGenerationForTesting()
        XCTAssertEqual(model.currentStep, .planReveal)

        XCTAssertTrue(analytics.contains(.stepCompleted, step: "review"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "generating_plan"))
        XCTAssertTrue(analytics.contains(.stepCompleted, step: "generating_plan"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "plan_reveal"))
        XCTAssertTrue(analytics.contains(.planGenerated))
        XCTAssertTrue(analytics.contains(.planRevealed))
    }

    // MARK: - Helpers

    private func makeOnboardingModel(
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
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: integration
        )
    }

    private func seedValidOnboardingForm(
        _ formState: inout OnboardingFormState,
        birthDate: Date? = nil
    ) {
        OnboardingModelTestSupport.seedCanonicalForm(&formState, birthDate: birthDate)
    }
}

private final class CapturingOnboardingCompletionAnalyticsLogger: OnboardingAnalyticsLogging, @unchecked Sendable {

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
