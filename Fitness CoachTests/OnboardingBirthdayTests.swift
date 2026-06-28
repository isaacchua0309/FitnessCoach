//
//  OnboardingBirthdayTests.swift
//  Fitness CoachTests
//
//  Forma — birthday validation, age derivation, sex requirement, and routing tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingBirthdayTests: XCTestCase {

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

        XCTAssertFalse(state.canAdvance(from: .birthday))
        XCTAssertEqual(
            state.validationMessage(for: .birthday),
            FormaProductCopy.Onboarding.Flow.Birthday.birthDateRequiredMessage
        )
    }

    func testBirthdayValidationRejectsDerivedAgeBelowMinimum() throws {
        let birthDate = calendar.date(from: DateComponents(year: 2010, month: 12, day: 31))!
        var state = validFormState(birthDate: birthDate)

        XCTAssertEqual(
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar),
            15
        )
        XCTAssertFalse(state.canAdvance(from: .birthday))
        XCTAssertEqual(
            state.validationMessage(for: .birthday),
            FormaProductCopy.Onboarding.Flow.Birthday.ageOutOfRangeMessage
        )
    }

    func testBirthdayValidationRejectsDerivedAgeAboveMaximum() throws {
        let birthDate = calendar.date(from: DateComponents(year: 1935, month: 1, day: 1))!
        var state = validFormState(birthDate: birthDate)

        XCTAssertEqual(
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar),
            91
        )
        XCTAssertFalse(state.canAdvance(from: .birthday))
        XCTAssertEqual(
            state.validationMessage(for: .birthday),
            FormaProductCopy.Onboarding.Flow.Birthday.ageOutOfRangeMessage
        )
    }

    func testAgeDerivedWhenBirthdayNotYetReachedThisYear() {
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 12, day: 15))!

        XCTAssertEqual(
            OnboardingBirthdayValues.derivedAge(
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
            OnboardingBirthdayValues.derivedAge(
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
            OnboardingBirthdayValues.derivedAge(
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

    func testSexRequiredForBirthdayStep() {
        let birthDate = calendar.date(from: DateComponents(year: 1995, month: 7, day: 4))!
        var state = validFormState(birthDate: birthDate, sex: .preferNotToSay)

        XCTAssertFalse(state.canAdvance(from: .birthday))
        XCTAssertEqual(
            state.validationMessage(for: .birthday),
            FormaProductCopy.Onboarding.Flow.Birthday.sexRequiredMessage
        )

        state.sex = .other
        XCTAssertFalse(state.canAdvance(from: .birthday))
        XCTAssertEqual(
            state.validationMessage(for: .birthday),
            FormaProductCopy.Onboarding.Flow.Birthday.sexRequiredMessage
        )
    }

    func testBirthdayValidationAcceptsMaleOrFemaleWithValidAge() {
        let birthDate = calendar.date(from: DateComponents(year: 1995, month: 7, day: 4))!

        XCTAssertTrue(validFormState(birthDate: birthDate, sex: .male).canAdvance(from: .birthday))
        XCTAssertTrue(validFormState(birthDate: birthDate, sex: .female).canAdvance(from: .birthday))
    }

    func testApplyDefaultsSetsBirthDateAndDerivedAgeText() {
        var state = OnboardingFormState()
        OnboardingBirthdayValues.applyDefaultsIfNeeded(
            to: &state,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertNotNil(state.birthDate)
        XCTAssertFalse(state.ageText.isEmpty)
        XCTAssertEqual(try state.resolvedAge(referenceDate: referenceDate), OnboardingPickerDefaults.defaultAge)
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

        let draft = OnboardingDraft(formState: formState, step: .birthday)
        let restored = draft.makeFormState()

        XCTAssertEqual(restored.birthDate, birthDate)
        XCTAssertEqual(restored.sex, .male)
        XCTAssertEqual(restored.sex.rawValue, draft.form.sexRawValue)
        XCTAssertEqual(try restored.resolvedAge(referenceDate: referenceDate), 33)
    }

    func testBirthdayRoutesNextToActivityLevel() {
        let flow = OnboardingStep.flow
        XCTAssertEqual(OnboardingStep.birthday.next(in: flow), .activityLevel)
    }

    func testDraftRestoreReturnsBirthdayWhenSexMissing() {
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 5, day: 12))!
        var formState = OnboardingFormState()
        formState.birthDate = birthDate
        formState.heightCmText = "170"
        formState.currentWeightKgText = "70"
        formState.goalWeightKgText = "65"
        formState.syncAgeTextFromBirthDate(referenceDate: referenceDate)

        let restoredStep = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.body.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restoredStep, .birthday)
    }

    func testHeightWeightRequiresHeightAndWeight() {
        var state = OnboardingFormState()
        state.currentWeightKgText = "70"

        XCTAssertFalse(state.canAdvance(from: .heightWeight))
        XCTAssertNotNil(state.validationMessage(for: .heightWeight))

        state.heightCmText = "170"
        XCTAssertTrue(state.canAdvance(from: .heightWeight))
    }

    func testFirstInvalidRequiredStepIncludesBirthdayBeforeActivity() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(
            OnboardingFormState.firstInvalidRequiredStep(for: state),
            .birthday
        )
    }
}
