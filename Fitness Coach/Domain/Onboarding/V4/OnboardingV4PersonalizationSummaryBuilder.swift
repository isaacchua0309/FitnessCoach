//
//  OnboardingV4PersonalizationSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — V4 onboarding review recap (body, goal, birthday, activity only).
//

import Foundation

enum OnboardingV4PersonalizationSummaryBuilder {

    static func recapCards(
        for formState: OnboardingFormState,
        referenceDate: Date = Date()
    ) -> [OnboardingPersonalizationSummaryRecap] {
        let copy = FormaProductCopy.Onboarding.V4.Summary.self
        return [
            OnboardingPersonalizationSummaryRecap(
                id: "height",
                title: copy.heightLabel,
                value: metricLine(
                    formState.displayText(for: .height),
                    unit: OnboardingFormatter.heightUnitLabel(for: formState.unitSystem)
                )
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "currentWeight",
                title: copy.currentWeightLabel,
                value: metricLine(
                    formState.displayText(for: .currentWeight),
                    unit: OnboardingFormatter.weightUnitAbbreviation(for: formState.unitSystem)
                )
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "targetWeight",
                title: copy.targetWeightLabel,
                value: metricLine(
                    formState.displayText(for: .goalWeight),
                    unit: OnboardingFormatter.weightUnitAbbreviation(for: formState.unitSystem)
                )
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "age",
                title: copy.ageLabel,
                value: ageLine(for: formState, referenceDate: referenceDate)
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "sex",
                title: copy.sexLabel,
                value: sexLine(for: formState)
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "activity",
                title: copy.activityLabel,
                value: OnboardingFormatter.activityLevel(formState.activityLevel)
            )
        ]
    }

    static func validationMessage(for formState: OnboardingFormState) -> String? {
        guard let step = OnboardingFormState.firstInvalidRequiredV4Step(for: formState) else {
            return nil
        }
        return formState.validationMessageV4(for: step)
            ?? FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
    }

    static func isReadyToGenerate(for formState: OnboardingFormState) -> Bool {
        OnboardingFormState.firstInvalidRequiredV4Step(for: formState) == nil
    }

    private static func metricLine(_ value: String, unit: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "—" else { return "—" }
        return "\(trimmed) \(unit)"
    }

    private static func ageLine(
        for formState: OnboardingFormState,
        referenceDate: Date
    ) -> String {
        if let birthDate = formState.birthDate {
            let age = BirthDateAgeResolver.age(from: birthDate, referenceDate: referenceDate)
            return String(age)
        }

        if let age = try? formState.resolvedAge(referenceDate: referenceDate) {
            return String(age)
        }

        return "—"
    }

    private static func sexLine(for formState: OnboardingFormState) -> String {
        guard OnboardingV4BirthdayValues.isSelectedSexValidForCalorieCalculation(formState.sex) else {
            return "—"
        }
        return OnboardingFormatter.sex(formState.sex)
    }
}
