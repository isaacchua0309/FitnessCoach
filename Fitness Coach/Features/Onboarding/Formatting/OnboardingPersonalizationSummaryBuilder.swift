//
//  OnboardingPersonalizationSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Recap lines for onboarding review (display only).
//

import Foundation

struct OnboardingPersonalizationSummaryRecap: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let value: String
}

enum OnboardingPersonalizationSummaryBuilder {

    static func recapCards(
        for formState: OnboardingFormState,
        referenceDate: Date = Date()
    ) -> [OnboardingPersonalizationSummaryRecap] {
        let copy = FormaProductCopy.Onboarding.Flow.Summary.self
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

    static func firstInvalidRequiredStep(
        for formState: OnboardingFormState
    ) -> OnboardingStep? {
        OnboardingFormState.firstInvalidRequiredStep(for: formState)
    }

    static func validationMessage(for formState: OnboardingFormState) -> String? {
        guard let step = OnboardingFormState.firstInvalidRequiredStep(for: formState) else {
            return nil
        }
        return formState.validationMessage(for: step)
            ?? FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
    }

    static func isReadyToGenerate(for formState: OnboardingFormState) -> Bool {
        OnboardingFormState.firstInvalidRequiredStep(for: formState) == nil
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
        guard OnboardingBirthdayValues.isSelectedSexValidForCalorieCalculation(formState.sex) else {
            return "—"
        }
        return OnboardingFormatter.sex(formState.sex)
    }
}
