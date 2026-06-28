//
//  OnboardingV4BirthdayTests.swift
//  Fitness CoachTests
//
//  Forma — V4 birthday validation, age derivation, sex requirement, and routing tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV4BirthdayTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!
    }

    private func validFormState(
        birthDate: Date,
        sex: Sex = .female
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        state.birthDate = birthDate
        state.sex = sex
        state.heightCmText = "170"
        state.currentWeightKgText = "70"
        state.goalWeightKgText = "65"
        state.syncAgeTextFromBirthDate(referenceDate: referenceDate)
        return state
    }

    func testBirthdayValidationRequiresBirthDate() {
        var state = OnboardingFormState()
        state.sex = .male

        XCTAssertFalse(state.canAdvanceV4(from: .birthday))
        XCTAssertEqual(
            state.validationMessageV4(for: .birthday),
            FormaProductCopy.Onboarding.V4.Birthday.birthDateRequiredMessage
        )
    }

    func testBirthdayValidationRejectsDerivedAgeBelowMinimum() throws {
        let birthDate = calendar.date(from: DateComponents(year: 2010, month: 12, day: 31))!
        var state = validFormState(birthDate: birthDate)

        XCTAssertEqual(
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar),
            15
        )
        XCTAssertFalse(state.canAdvanceV4(from: .birthday))
        XCTAssertEqual(
            state.validationMessageV4(for: .birthday),
            FormaProductCopy.Onboarding.V4.Birthday.ageOutOfRangeMessage
        )
    }

    func testBirthdayValidationRejectsDerivedAgeAboveMaximum() throws {
        let birthDate = calendar.date(from: DateComponents(year: 1935, month: 1, day: 1))!
        var state = validFormState(birthDate: birthDate)

        XCTAssertEqual(
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar),
            91
        )
        XCTAssertFalse(state.canAdvanceV4(from: .birthday))
        XCTAssertEqual(
            state.validationMessageV4(for: .birthday),
            FormaProductCopy.Onboarding.V4.Birthday.ageOutOfRangeMessage
        )
    }

    func testAgeDerivedWhenBirthdayNotYetReachedThisYear() {
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 12, day: 15))!

        XCTAssertEqual(
            OnboardingV4BirthdayValues.derivedAge(
                from: validFormState(birthDate: birthDate),
                referenceDate: referenceDate,
                calendar: calendar
            ),
            35
        )
    }

    func testAgeDerivedAfterBirthdayThisYear() {
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 3, day: 10))!

        XCTAssertEqual(
            OnboardingV4BirthdayValues.derivedAge(
                from: validFormState(birthDate: birthDate),
                referenceDate: referenceDate,
                calendar: calendar
            ),
            36
        )
    }

    func testAgeDerivedOnLeapYearBirthday() {
        let birthDate = calendar.date(from: DateComponents(year: 2000, month: 2, day: 29))!
        let reference = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1))!

        XCTAssertEqual(
            OnboardingV4BirthdayValues.derivedAge(
                from: validFormState(birthDate: birthDate),
                referenceDate: reference,
                calendar: calendar
            ),
            24
        )
        XCTAssertTrue(
            BirthDateAgeResolver.isValidBirthDate(
                birthDate,
                referenceDate: reference,
                calendar: calendar
            )
        )
    }

    func testSexRequiredForV4BirthdayStep() {
        let birthDate = calendar.date(from: DateComponents(year: 1995, month: 7, day: 4))!
        var state = validFormState(birthDate: birthDate, sex: .preferNotToSay)

        XCTAssertFalse(state.canAdvanceV4(from: .birthday))
        XCTAssertEqual(
            state.validationMessageV4(for: .birthday),
            FormaProductCopy.Onboarding.V4.Birthday.sexRequiredMessage
        )

        state.sex = .other
        XCTAssertFalse(state.canAdvanceV4(from: .birthday))
        XCTAssertEqual(
            state.validationMessageV4(for: .birthday),
            FormaProductCopy.Onboarding.V4.Birthday.sexRequiredMessage
        )
    }

    func testBirthdayValidationAcceptsMaleOrFemaleWithValidAge() {
        let birthDate = calendar.date(from: DateComponents(year: 1995, month: 7, day: 4))!

        XCTAssertTrue(validFormState(birthDate: birthDate, sex: .male).canAdvanceV4(from: .birthday))
        XCTAssertTrue(validFormState(birthDate: birthDate, sex: .female).canAdvanceV4(from: .birthday))
    }

    func testApplyDefaultsSetsBirthDateAndDerivedAgeText() {
        var state = OnboardingFormState()
        OnboardingV4BirthdayValues.applyDefaultsIfNeeded(
            to: &state,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertNotNil(state.birthDate)
        XCTAssertFalse(state.ageText.isEmpty)
        XCTAssertEqual(try state.resolvedAge(referenceDate: referenceDate), OnboardingV3PickerDefaults.defaultAge)
    }

    func testCalorieInputUsesDerivedAgeFromBirthDate() throws {
        let birthDate = calendar.date(from: DateComponents(year: 1998, month: 1, day: 1))!
        var state = validFormState(birthDate: birthDate)
        state.ageText = "99"
        state.trainingFrequencyPerWeekText = "3"
        state.averageStepsText = "5000"

        let input = try state.makeCalorieTargetInput(referenceDate: referenceDate)
        XCTAssertEqual(input.age, 28)
        XCTAssertEqual(input.sex, .female)
    }

    func testDraftRoundTripPersistsBirthDateAndSexRawValue() {
        let birthDate = calendar.date(from: DateComponents(year: 1992, month: 11, day: 8))!
        var formState = validFormState(birthDate: birthDate, sex: .male)

        let draft = OnboardingDraft(formState: formState, currentStep: .body)
        let restored = draft.makeFormState()

        XCTAssertEqual(restored.birthDate, birthDate)
        XCTAssertEqual(restored.sex, .male)
        XCTAssertEqual(restored.sex.rawValue, draft.form.sexRawValue)
        XCTAssertEqual(try restored.resolvedAge(referenceDate: referenceDate), 33)
    }

    func testBirthdayRoutesNextToActivityLevel() {
        let flow = OnboardingV4Step.fullFlow
        XCTAssertEqual(OnboardingV4Step.birthday.next(in: flow), .activityLevel)
    }

    func testDraftRestoreReturnsBirthdayWhenSexMissing() {
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 5, day: 12))!
        var formState = OnboardingFormState()
        formState.birthDate = birthDate
        formState.heightCmText = "170"
        formState.currentWeightKgText = "70"
        formState.goalWeightKgText = "65"
        formState.syncAgeTextFromBirthDate(referenceDate: referenceDate)

        let restoredStep = OnboardingV4DraftBridge.restoredV4Step(
            legacyStep: .body,
            formState: formState,
            flow: OnboardingV4Step.fullFlow
        )

        XCTAssertEqual(restoredStep, .birthday)
    }

    func testV3BodyBasicsStillValidatesManualAgeText() {
        var state = OnboardingFormState()
        state.heightCmText = "170"
        state.currentWeightKgText = "70"

        XCTAssertFalse(state.canAdvanceV3(from: .bodyBasics))
        XCTAssertEqual(
            state.validationMessageV3(for: .bodyBasics),
            FormaProductCopy.Onboarding.Validation.age
        )

        state.ageText = "30"
        XCTAssertTrue(state.canAdvanceV3(from: .bodyBasics))
    }

    func testFirstInvalidRequiredV4StepIncludesBirthdayBeforeActivity() {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(
            OnboardingFormState.firstInvalidRequiredV4Step(for: state),
            .birthday
        )
    }
}
