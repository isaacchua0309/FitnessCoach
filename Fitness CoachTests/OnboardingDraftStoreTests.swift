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

    func testDraftSaveLoadRoundTripPreservesCanonicalFlowFields() throws {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &formState)
        formState.sex = .female
        formState.name = "Alex"
        formState.selectPaceChoice(.moderate)
        formState.activityLevel = .moderatelyActive
        OnboardingActivityLevelValues.applyDefaultsIfNeeded(to: &formState)

        let plan = OnboardingPreviewData.generatedPlan
        let draft = OnboardingDraft(
            formState: formState,
            step: .targetWeight,
            generatedPlan: plan
        )

        store.saveDraft(draft)
        let loaded = try XCTUnwrap(store.loadDraft())

        XCTAssertEqual(loaded.draftVersion, OnboardingDraft.currentDraftVersion)
        XCTAssertEqual(loaded.step, .targetWeight)
        let restored = loaded.makeFormState()
        XCTAssertEqual(restored.birthDate, formState.birthDate)
        XCTAssertEqual(restored.sex, formState.sex)
        XCTAssertEqual(restored.heightCmText, formState.heightCmText)
        XCTAssertEqual(restored.currentWeightKgText, formState.currentWeightKgText)
        XCTAssertEqual(restored.goalWeightKgText, formState.goalWeightKgText)
        XCTAssertEqual(restored.name, formState.name)
        XCTAssertEqual(restored.weightLossPaceChoice, formState.weightLossPaceChoice)
        XCTAssertEqual(restored.activityLevel, formState.activityLevel)
        XCTAssertEqual(loaded.makeGeneratedPlan(), plan)
    }

    func testDraftClear() {
        let draft = OnboardingDraft(
            formState: OnboardingFormState(),
            step: .introProof
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

    func testUnsupportedVersionFallback() throws {
        let draft = OnboardingDraft(
            draftVersion: 99,
            currentStepRawValue: OnboardingStep.heightWeight.rawValue,
            form: OnboardingDraftFormFields(formState: OnboardingFormState())
        )

        let data = try JSONEncoder().encode(draft)
        userDefaults.set(data, forKey: OnboardingDraftStore.userDefaultsKey)

        XCTAssertNil(store.loadDraft())
        XCTAssertNil(userDefaults.data(forKey: OnboardingDraftStore.userDefaultsKey))
    }

    func testInvalidStepRawValueFallback() throws {
        let draft = OnboardingDraft(
            draftVersion: OnboardingDraft.currentDraftVersion,
            currentStepRawValue: 999,
            form: OnboardingDraftFormFields(formState: OnboardingFormState())
        )

        let data = try JSONEncoder().encode(draft)
        userDefaults.set(data, forKey: OnboardingDraftStore.userDefaultsKey)

        XCTAssertNil(store.loadDraft())
        XCTAssertNil(userDefaults.data(forKey: OnboardingDraftStore.userDefaultsKey))
    }

    func testSaveLoadRoundTripIncludesOptionalCoachingContextFields() throws {
        var formState = OnboardingFormState()
        formState.selectedMotivations = [.health, .energy]
        formState.loggingPreferences = [.quickTaps, .noPressure]
        formState.dietPreference = "Vegetarian"

        let draft = OnboardingDraft(formState: formState, step: .review)

        store.saveDraft(draft)
        let loaded = try XCTUnwrap(store.loadDraft())
        let restored = loaded.makeFormState()

        XCTAssertEqual(loaded.step, .review)
        XCTAssertEqual(restored.selectedMotivations, formState.selectedMotivations)
        XCTAssertEqual(restored.loggingPreferences, formState.loggingPreferences)
        XCTAssertEqual(restored.dietPreference, "Vegetarian")
    }
}
