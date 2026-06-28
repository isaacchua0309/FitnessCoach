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

    private static let requiredSteps: [OnboardingStep] = [.body, .goal, .activity]

    static func recapCards(
        for formState: OnboardingFormState,
        usesV4Steps: Bool = false,
        referenceDate: Date = Date()
    ) -> [OnboardingPersonalizationSummaryRecap] {
        if usesV4Steps {
            return OnboardingV4PersonalizationSummaryBuilder.recapCards(
                for: formState,
                referenceDate: referenceDate
            )
        }

        let copy = FormaProductCopy.Onboarding.V2.Summary.self
        return [
            OnboardingPersonalizationSummaryRecap(
                id: "goal",
                title: copy.goalLabel,
                value: goalLine(for: formState)
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "pace",
                title: copy.paceLabel,
                value: paceLine(for: formState)
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "activity",
                title: copy.activityLabel,
                value: activityLine(for: formState)
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "preferences",
                title: copy.preferencesLabel,
                value: preferencesLine(for: formState)
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "motivation",
                title: copy.motivationLabel,
                value: motivationLine(for: formState)
            )
        ]
    }

    static func firstInvalidRequiredStep(
        for formState: OnboardingFormState,
        usesV4Steps: Bool = false
    ) -> OnboardingStep? {
        if usesV4Steps {
            guard let v4Step = OnboardingFormState.firstInvalidRequiredV4Step(for: formState) else {
                return nil
            }
            return OnboardingV4DraftBridge.persistedLegacyStep(for: v4Step, formState: formState)
        }

        return requiredSteps.first { formState.validationMessage(for: $0) != nil }
    }

    static func validationMessage(
        for formState: OnboardingFormState,
        usesV4Steps: Bool = false
    ) -> String? {
        if usesV4Steps {
            return OnboardingV4PersonalizationSummaryBuilder.validationMessage(for: formState)
        }

        guard let step = firstInvalidRequiredStep(for: formState, usesV4Steps: false) else { return nil }
        return formState.validationMessage(for: step)
            ?? FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
    }

    static func isReadyToGenerate(
        for formState: OnboardingFormState,
        usesV4Steps: Bool = false
    ) -> Bool {
        if usesV4Steps {
            return OnboardingV4PersonalizationSummaryBuilder.isReadyToGenerate(for: formState)
        }

        return firstInvalidRequiredStep(for: formState, usesV4Steps: false) == nil
    }

    // MARK: - Lines

    private static func goalLine(for formState: OnboardingFormState) -> String {
        let unit = OnboardingFormatter.weightUnitAbbreviation(for: formState.unitSystem)
        let current = formattedWeight(formState.displayText(for: .currentWeight), unit: unit)
        let goal = formattedWeight(formState.displayText(for: .goalWeight), unit: unit)

        guard current != "—", goal != "—" else {
            return "—"
        }
        return "\(current) → \(goal)"
    }

    private static func paceLine(for formState: OnboardingFormState) -> String {
        let copy = FormaProductCopy.Onboarding.V2.Summary.self
        guard formState.isPaceApplicable() else {
            return copy.maintenancePaceSummary
        }

        let paceName = OnboardingFormatter.paceChoiceTitle(formState.weightLossPaceChoice)
        let preview = formState.pacePreview()
        guard let weeklyKg = preview.weeklyLossKg else {
            return paceName
        }

        return "\(paceName) · \(weeklyPacePhrase(weeklyKg))"
    }

    private static func activityLine(for formState: OnboardingFormState) -> String {
        let activity = OnboardingFormatter.activityLevel(formState.activityLevel)
        let trainingDays = formState.trainingFrequencyPerWeekText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trainingDays.isEmpty else {
            return activity
        }
        return "\(activity) · \(trainingDays) training days/week"
    }

    private static func preferencesLine(for formState: OnboardingFormState) -> String {
        let copy = FormaProductCopy.Onboarding.V2.Summary.self

        if formState.selectedDietChips.contains(.addLater) {
            return OnboardingDietPreferenceChip.addLater.title
        }

        var parts: [String] = OnboardingDietPreferenceChip.multiSelectOptions
            .filter { formState.selectedDietChips.contains($0) }
            .map(\.title)

        let custom = formState.customDietPreferenceText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            parts.append(custom)
        }

        if parts.isEmpty {
            return copy.noPreferencesAdded
        }

        return parts.joined(separator: " · ")
    }

    private static func motivationLine(for formState: OnboardingFormState) -> String {
        let copy = FormaProductCopy.Onboarding.V2.Summary.self
        guard !formState.selectedMotivations.isEmpty else {
            return copy.motivationDefault
        }

        return OnboardingMotivation.allCases
            .filter { formState.selectedMotivations.contains($0) }
            .map(\.recapLabel)
            .joined(separator: ", ")
    }

    private static func formattedWeight(_ text: String, unit: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        return "\(trimmed) \(unit)"
    }

    private static func weeklyPacePhrase(_ weeklyKg: Double) -> String {
        let amount: String
        if weeklyKg.truncatingRemainder(dividingBy: 1) == 0 {
            amount = "\(Int(weeklyKg))"
        } else if (weeklyKg * 100).truncatingRemainder(dividingBy: 10) == 0 {
            amount = String(format: "%.1f", weeklyKg)
        } else {
            amount = String(format: "%.2f", weeklyKg)
        }
        return "about \(amount) kg/week"
    }
}
