//
//  OnboardingBirthdayValues.swift
//  Fitness Coach
//
//  Forma — Birthday, derived age, and biological sex validation for onboarding.
//

import Foundation

enum OnboardingBirthdayValues {

    static func applyDefaultsIfNeeded(
        to formState: inout OnboardingFormState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        if formState.birthDate == nil {
            formState.birthDate = BirthDateAgeResolver.syntheticBirthDate(
                fromAge: OnboardingPickerDefaults.defaultAge,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        formState.syncAgeTextFromBirthDate(referenceDate: referenceDate)
    }

    static func isSelectedSexValidForCalorieCalculation(_ sex: Sex) -> Bool {
        sex == .male || sex == .female
    }

    static func derivedAge(
        from formState: OnboardingFormState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let birthDate = formState.birthDate else { return nil }
        return BirthDateAgeResolver.age(
            from: birthDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func validate(
        formState: OnboardingFormState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        guard let birthDate = formState.birthDate else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.Flow.Birthday.birthDateRequiredMessage
            )
        }

        guard BirthDateAgeResolver.isValidBirthDate(
            birthDate,
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.Flow.Birthday.ageOutOfRangeMessage
            )
        }

        guard isSelectedSexValidForCalorieCalculation(formState.sex) else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.Flow.Birthday.sexRequiredMessage
            )
        }
    }
}
