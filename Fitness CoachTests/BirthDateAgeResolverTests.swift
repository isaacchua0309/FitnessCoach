//
//  BirthDateAgeResolverTests.swift
//  Fitness CoachTests
//
//  Forma — Birthday-derived age and legacy fallback tests.
//

import XCTest
@testable import Fitness_Coach

final class BirthDateAgeResolverTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!
    }

    func testAgeDerivedFromBirthDateBeforeBirthday() {
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 12, day: 15))!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!

        XCTAssertEqual(
            BirthDateAgeResolver.age(from: birthDate, referenceDate: reference, calendar: calendar),
            35
        )
    }

    func testAgeDerivedFromBirthDateAfterBirthday() {
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 3, day: 10))!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!

        XCTAssertEqual(
            BirthDateAgeResolver.age(from: birthDate, referenceDate: reference, calendar: calendar),
            36
        )
    }

    func testAgeDerivedOnBirthday() {
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 6, day: 28))!

        XCTAssertEqual(
            BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate, calendar: calendar),
            36
        )
    }

    func testResolvedAgePrefersBirthDateOverLegacyAge() {
        let birthDate = calendar.date(from: DateComponents(year: 1998, month: 1, day: 1))!

        XCTAssertEqual(
            BirthDateAgeResolver.resolvedAge(
                birthDate: birthDate,
                legacyAge: 99,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            28
        )
    }

    func testResolvedAgeFallsBackToLegacyAgeWhenBirthDateMissing() {
        XCTAssertEqual(
            BirthDateAgeResolver.resolvedAge(
                birthDate: nil,
                legacyAge: 42,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            42
        )
    }

    func testSyntheticBirthDateClampsToSupportedRange() {
        let young = BirthDateAgeResolver.syntheticBirthDate(
            fromAge: 5,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let old = BirthDateAgeResolver.syntheticBirthDate(
            fromAge: 120,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(
            BirthDateAgeResolver.age(from: young, referenceDate: referenceDate, calendar: calendar),
            BirthDateAgeResolver.minimumAge
        )
        XCTAssertEqual(
            BirthDateAgeResolver.age(from: old, referenceDate: referenceDate, calendar: calendar),
            BirthDateAgeResolver.maximumAge
        )
    }

    func testOnboardingFormStateUsesBirthDateForCalorieInput() throws {
        var state = OnboardingFormState()
        state.birthDate = calendar.date(from: DateComponents(year: 1998, month: 1, day: 1))!
        state.ageText = "99"
        state.sex = .female
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        state.goalWeightKgText = "65"
        state.trainingFrequencyPerWeekText = "3"
        state.averageStepsText = "5000"

        let input = try state.makeCalorieTargetInput(referenceDate: referenceDate)
        XCTAssertEqual(input.age, 28)
    }

    func testOnboardingFormStateFallsBackToAgeTextWhenBirthDateMissing() throws {
        var state = OnboardingFormState()
        state.ageText = "31"
        state.sex = .female
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        state.goalWeightKgText = "65"
        state.trainingFrequencyPerWeekText = "3"
        state.averageStepsText = "5000"

        let input = try state.makeCalorieTargetInput(referenceDate: referenceDate)
        XCTAssertEqual(input.age, 31)
    }

    func testLegacyDraftMigrationSynthesizesBirthDateFromAgeText() throws {
        let legacy = OnboardingDraftV1(
            draftVersion: 1,
            currentStepRawValue: OnboardingLegacyPersistedStep.body.rawValue,
            form: OnboardingDraftV1FormFields(
                name: "",
                ageText: "30",
                birthDateISO8601: nil,
                sexRawValue: Sex.female.rawValue,
                heightCmText: "170",
                currentWeightKgText: "70",
                goalWeightKgText: "65",
                estimatedBodyFatPercentageText: "",
                activityLevelRawValue: ActivityLevel.moderatelyActive.rawValue,
                trainingFrequencyPerWeekText: "3",
                averageStepsText: "5000",
                dietPreference: "",
                unitSystemRawValue: UnitSystem.metric.rawValue,
                aggressivenessRawValue: CalorieAggressiveness.moderate.rawValue,
                weightLossPaceChoiceRawValue: WeightLossPaceChoice.moderate.rawValue,
                advancedPacePeriodRawValue: WeightLossAdvancedPaceDraft.default.period.rawValue,
                advancedPaceAmountText: ""
            ),
            generatedPlan: nil,
            savedAt: referenceDate
        )

        let restored = OnboardingDraftMigration.upgrade(from: legacy).makeFormState()

        XCTAssertNotNil(restored.birthDate)
        XCTAssertEqual(try restored.resolvedAge(referenceDate: referenceDate), 30)
    }

    func testDraftRoundTripPersistsBirthDate() throws {
        var formState = OnboardingFormState()
        formState.birthDate = calendar.date(from: DateComponents(year: 1995, month: 7, day: 4))!
        formState.syncAgeTextFromBirthDate(referenceDate: referenceDate)
        formState.heightCmText = "170"
        formState.currentWeightKgText = "70"
        formState.goalWeightKgText = "65"

        let draft = OnboardingDraft(formState: formState, step: .birthday)
        let restored = draft.makeFormState()

        XCTAssertEqual(restored.birthDate, formState.birthDate)
        XCTAssertEqual(try restored.resolvedAge(referenceDate: referenceDate), 30)
    }

    func testLegacyAgeOnlyProfileUsesFallbackAge() throws {
        let profile = UserProfile(
            id: UUID(),
            name: "Legacy",
            birthDate: nil,
            age: 45,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 6000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: ProfileTestFixtures.sampleTargets,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let input = PlanCalculationBridge.planInput(from: profile, referenceDate: referenceDate)
        XCTAssertEqual(input.ageYears, 45)
    }

    func testProfileWithBirthDateUsesDerivedAgeForPlanInput() {
        let profile = UserProfile(
            id: UUID(),
            name: "Birthday",
            birthDate: calendar.date(from: DateComponents(year: 1998, month: 1, day: 1))!,
            age: 99,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 6000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: ProfileTestFixtures.sampleTargets,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let input = PlanCalculationBridge.planInput(from: profile, referenceDate: referenceDate)
        XCTAssertEqual(input.ageYears, 28)
    }

    func testCloudDocumentRoundTripPreservesBirthDate() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.birthDate = calendar.date(from: DateComponents(year: 1994, month: 5, day: 20))!

        let document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )
        let restored = document.makeUserProfile()

        XCTAssertEqual(restored.birthDate, profile.birthDate)
        XCTAssertEqual(document.age, profile.resolvedAge(referenceDate: referenceDate))
        XCTAssertEqual(restored.age, document.age)
    }

    func testCloudDocumentWithoutBirthDateRestoresLegacyAge() {
        let profile = ProfileTestFixtures.sampleProfile
        let document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )
        let restored = document.makeUserProfile()

        XCTAssertNil(restored.birthDate)
        XCTAssertEqual(restored.age, profile.age)
        XCTAssertEqual(restored.resolvedAge(referenceDate: referenceDate), profile.age)
    }
}
