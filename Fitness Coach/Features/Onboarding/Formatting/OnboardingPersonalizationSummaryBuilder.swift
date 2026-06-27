//
//  OnboardingPersonalizationSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Recap lines for onboarding personalization summary (display only).
//

import Foundation

struct OnboardingPersonalizationSummaryRecap: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let value: String
}

enum OnboardingPersonalizationSummaryBuilder {

    private static let requiredSteps: [OnboardingStep] = [.body, .goal, .activity]

    static func recapCards(for formState: OnboardingFormState) -> [OnboardingPersonalizationSummaryRecap] {
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
                id: "logging",
                title: copy.loggingLabel,
                value: loggingLine(for: formState)
            ),
            OnboardingPersonalizationSummaryRecap(
                id: "motivation",
                title: copy.motivationLabel,
                value: motivationLine(for: formState)
            )
        ]
    }

    static func firstInvalidRequiredStep(for formState: OnboardingFormState) -> OnboardingStep? {
        requiredSteps.first { formState.validationMessage(for: $0) != nil }
    }

    static func validationMessage(for formState: OnboardingFormState) -> String? {
        guard let step = firstInvalidRequiredStep(for: formState) else { return nil }
        return formState.validationMessage(for: step)
            ?? FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
    }

    static func isReadyToGenerate(for formState: OnboardingFormState) -> Bool {
        firstInvalidRequiredStep(for: formState) == nil
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
        let dayLabel = trainingDays == "1" ? "day" : "days"
        return "\(activity) · \(trainingDays) training \(dayLabel)/week"
    }

    private static func loggingLine(for formState: OnboardingFormState) -> String {
        let copy = FormaProductCopy.Onboarding.V2.Summary.self
        guard !formState.loggingPreferences.isEmpty else {
            return copy.loggingDefault
        }

        let labels = OnboardingLoggingPreference.allCases
            .filter { formState.loggingPreferences.contains($0) }
            .map(\.title)

        if labels.count == 1 {
            return labels[0]
        }
        return labels.joined(separator: " or ")
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
        let amount = weeklyKg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weeklyKg))"
            : String(format: "%.1f", weeklyKg)
        return "about \(amount) kg/week"
    }
}
