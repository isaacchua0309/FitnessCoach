//
//  OnboardingBirthdayAgePreviewBuilder.swift
//  Fitness Coach
//
//  Forma — Live age preview for birthday onboarding.
//

import Foundation

struct OnboardingBirthdayAgePreviewState: Equatable, Sendable {
    let headline: String
    let supportingCopy: String
    let isPlaceholder: Bool
    let accessibilityLabel: String
}

enum OnboardingBirthdayAgePreviewBuilder {

    static func build(
        from formState: OnboardingFormState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> OnboardingBirthdayAgePreviewState {
        let copy = FormaProductCopy.Onboarding.Flow.Birthday.self

        guard let birthDate = formState.birthDate else {
            return OnboardingBirthdayAgePreviewState(
                headline: copy.agePreviewPlaceholder,
                supportingCopy: copy.ageExplanation,
                isPlaceholder: true,
                accessibilityLabel: copy.agePreviewPlaceholder
            )
        }

        guard BirthDateAgeResolver.isValidBirthDate(
            birthDate,
            referenceDate: referenceDate,
            calendar: calendar
        ),
            let age = OnboardingBirthdayValues.derivedAge(
                from: formState,
                referenceDate: referenceDate,
                calendar: calendar
            ) else {
            return OnboardingBirthdayAgePreviewState(
                headline: copy.ageOutOfRangeMessage,
                supportingCopy: copy.ageExplanation,
                isPlaceholder: true,
                accessibilityLabel: copy.ageOutOfRangeMessage
            )
        }

        let formattedDate = formattedBirthDate(birthDate, calendar: calendar)
        return OnboardingBirthdayAgePreviewState(
            headline: copy.agePreview(age: age),
            supportingCopy: copy.ageExplanation,
            isPlaceholder: false,
            accessibilityLabel: "Birthday selected, \(formattedDate). Age \(age)."
        )
    }

    static func voiceOverSummary(
        from formState: OnboardingFormState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let ageState = build(from: formState, referenceDate: referenceDate, calendar: calendar)
        let sexCopy = FormaProductCopy.Onboarding.Flow.Birthday.sexSectionTitle
        let sexStatus: String
        if OnboardingBirthdayValues.isSelectedSexValidForCalorieCalculation(formState.sex) {
            sexStatus = "\(OnboardingFormatter.sex(formState.sex)) selected"
        } else {
            sexStatus = "not selected"
        }
        return "\(ageState.accessibilityLabel) \(sexCopy), \(sexStatus)."
    }

    private static func formattedBirthDate(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
