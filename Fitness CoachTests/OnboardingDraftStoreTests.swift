//
//  OnboardingDraftStoreTests.swift
//  Fitness CoachTests
//
//  Forma — Onboarding draft UserDefaults persistence tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingDraftStoreTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        suiteName = "OnboardingDraftStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        store = OnboardingDraftStore(userDefaults: userDefaults)
    }

    override func tearDown() {
        store.clearDraft()
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        store = nil
        suiteName = nil
        super.tearDown()
    }

    func testDraftSaveLoadRoundTrip() throws {
        var formState = OnboardingFormState()
        formState.ageText = "30"
        formState.sex = .female
        formState.heightCmText = "170"
        formState.currentWeightKgText = "82.5"
        formState.goalWeightKgText = "75"
        formState.name = "Alex"
        formState.selectPaceChoice(.moderate)

        let plan = OnboardingPreviewData.generatedPlan
        let draft = OnboardingDraft(
            formState: formState,
            currentStep: .goal,
            generatedPlan: plan
        )

        store.saveDraft(draft)
        let loaded = try XCTUnwrap(store.loadDraft())

        XCTAssertEqual(loaded.draftVersion, OnboardingDraft.currentDraftVersion)
        XCTAssertEqual(loaded.currentStep, .goal)
        XCTAssertEqual(loaded.makeFormState(), formState)
        XCTAssertEqual(loaded.makeGeneratedPlan(), plan)
    }

    func testDraftClear() {
        let draft = OnboardingDraft(
            formState: OnboardingFormState(),
            currentStep: .welcome
        )

        store.saveDraft(draft)
        XCTAssertNotNil(store.loadDraft())

        store.clearDraft()
        XCTAssertNil(store.loadDraft())
        XCTAssertFalse(store.hasDraft)
    }

    func testCorruptDraftFallback() {
        userDefaults.set(Data("not-valid-json".utf8), forKey: OnboardingDraftStore.userDefaultsKey)

        XCTAssertNil(store.loadDraft())
        XCTAssertNil(userDefaults.data(forKey: OnboardingDraftStore.userDefaultsKey))
    }

    func testVersionMismatchFallback() {
        let draft = OnboardingDraft(
            draftVersion: 99,
            currentStepRawValue: OnboardingStep.body.rawValue,
            form: OnboardingDraftFormFields(formState: OnboardingFormState())
        )

        store.saveDraft(draft)
        XCTAssertNil(store.loadDraft())
        XCTAssertNil(userDefaults.data(forKey: OnboardingDraftStore.userDefaultsKey))
    }

    func testInvalidStepRawValueFallback() {
        let draft = OnboardingDraft(
            draftVersion: OnboardingDraft.currentDraftVersion,
            currentStepRawValue: 999,
            form: OnboardingDraftFormFields(formState: OnboardingFormState())
        )

        store.saveDraft(draft)
        XCTAssertNil(store.loadDraft())
        XCTAssertNil(userDefaults.data(forKey: OnboardingDraftStore.userDefaultsKey))
    }

    func testSaveLoadRoundTripIncludesV2OptionalFields() throws {
        var formState = OnboardingFormState()
        formState.selectedMotivations = [.health, .energy]
        formState.loggingPreferences = [.quickTaps, .noPressure]
        formState.dietPreference = "Vegetarian"

        let draft = OnboardingDraft(
            formState: formState,
            currentStep: .motivation
        )

        store.saveDraft(draft)
        let loaded = try XCTUnwrap(store.loadDraft())
        let restored = loaded.makeFormState()

        XCTAssertEqual(loaded.currentStep, .motivation)
        XCTAssertEqual(restored.selectedMotivations, formState.selectedMotivations)
        XCTAssertEqual(restored.loggingPreferences, formState.loggingPreferences)
        XCTAssertEqual(restored.dietPreference, "Vegetarian")
    }
}
