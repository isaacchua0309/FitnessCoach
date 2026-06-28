//
//  OnboardingPlanBlueprintBuilder.swift
//  Fitness Coach
//
//  Forma — Personalized plan-learned state for onboarding.
//

import Foundation

struct OnboardingPlanBlueprintPillar: Equatable, Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String
}

struct OnboardingPlanBlueprintState: Equatable, Sendable {
    let headline: String
    let supportingParagraph: String
    let personalizationSummary: String
    let pillars: [OnboardingPlanBlueprintPillar]
    let accessibilityLabel: String
    let isPersonalized: Bool
}

enum OnboardingPlanBlueprintBuilder {

    static func build(
        from formState: OnboardingFormState,
        referenceDate: Date = Date()
    ) -> OnboardingPlanBlueprintState {
        let copy = FormaProductCopy.Onboarding.Flow.Summary.self
        let detailRows = OnboardingPersonalizationSummaryBuilder.recapCards(
            for: formState,
            referenceDate: referenceDate
        )
        let pillars = pillars(copy: copy.Pillars.self)

        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = formState.parsedGoalWeightKg else {
            return fallbackState(copy: copy, pillars: pillars)
        }

        let direction = OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg
        )
        let bodyLine = bodyLine(from: detailRows)
        let activity = activityLine(from: detailRows)
        let journeyLine = journeyLine(
            currentKg: currentKg,
            goalKg: goalKg,
            unitSystem: formState.unitSystem
        )

        let personalizationSummary: String
        switch direction {
        case .cut:
            let goalChange = OnboardingGoalWeightBounds.changeSummary(
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem
            )
            personalizationSummary = copy.lossPersonalizationSummary(
                goalChange: goalChange,
                journeyLine: journeyLine,
                bodyLine: bodyLine,
                activity: activity
            )
        case .gain:
            let goalChange = OnboardingGoalWeightBounds.changeSummary(
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem
            )
            personalizationSummary = copy.gainPersonalizationSummary(
                goalChange: goalChange,
                journeyLine: journeyLine,
                bodyLine: bodyLine,
                activity: activity
            )
        case .maintain:
            let targetLabel = OnboardingGoalWeightBounds.weightSummary(
                valueKg: goalKg,
                unitSystem: formState.unitSystem
            )
            personalizationSummary = copy.maintainPersonalizationSummary(
                targetLabel: targetLabel,
                bodyLine: bodyLine,
                activity: activity
            )
        }

        return OnboardingPlanBlueprintState(
            headline: copy.title,
            supportingParagraph: copy.supportingParagraph,
            personalizationSummary: personalizationSummary,
            pillars: pillars,
            accessibilityLabel: accessibilityLabel(
                headline: copy.title,
                supportingParagraph: copy.supportingParagraph,
                personalizationSummary: personalizationSummary,
                pillars: pillars
            ),
            isPersonalized: true
        )
    }

    private static func fallbackState(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Type,
        pillars: [OnboardingPlanBlueprintPillar]
    ) -> OnboardingPlanBlueprintState {
        OnboardingPlanBlueprintState(
            headline: copy.title,
            supportingParagraph: copy.supportingParagraph,
            personalizationSummary: copy.fallbackPersonalizationSummary,
            pillars: pillars,
            accessibilityLabel: accessibilityLabel(
                headline: copy.title,
                supportingParagraph: copy.supportingParagraph,
                personalizationSummary: copy.fallbackPersonalizationSummary,
                pillars: pillars
            ),
            isPersonalized: false
        )
    }

    private static func pillars(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Pillars.Type
    ) -> [OnboardingPlanBlueprintPillar] {
        copy.items.map { item in
            OnboardingPlanBlueprintPillar(
                id: item.title,
                icon: item.icon,
                title: item.title
            )
        }
    }

    private static func bodyLine(
        from detailRows: [OnboardingPersonalizationSummaryRecap]
    ) -> String {
        let rowValue: (String) -> String? = { id in
            guard let value = detailRows.first(where: { $0.id == id })?.value,
                  value != "—" else {
                return nil
            }
            return value
        }

        if let height = rowValue("height"), let weight = rowValue("currentWeight") {
            return "\(height), \(weight)"
        }
        if let height = rowValue("height") {
            return height
        }
        if let weight = rowValue("currentWeight") {
            return weight
        }
        return "Your body"
    }

    private static func activityLine(
        from detailRows: [OnboardingPersonalizationSummaryRecap]
    ) -> String {
        guard let activity = detailRows.first(where: { $0.id == "activity" })?.value,
              activity != "—" else {
            return "Your activity level"
        }
        return activity
    }

    private static func journeyLine(
        currentKg: Double,
        goalKg: Double,
        unitSystem: UnitSystem
    ) -> String {
        let currentLabel = OnboardingGoalWeightBounds.weightSummary(
            valueKg: currentKg,
            unitSystem: unitSystem
        )
        let goalLabel = OnboardingGoalWeightBounds.weightSummary(
            valueKg: goalKg,
            unitSystem: unitSystem
        )
        return "\(currentLabel) → \(goalLabel)"
    }

    private static func accessibilityLabel(
        headline: String,
        supportingParagraph: String,
        personalizationSummary: String,
        pillars: [OnboardingPlanBlueprintPillar]
    ) -> String {
        let spokenSummary = personalizationSummary
            .replacingOccurrences(of: " kg", with: " kilograms")
            .replacingOccurrences(of: " lb", with: " pounds")
        let pillarList = pillars.map(\.title).joined(separator: ", ")
        return "\(headline) \(supportingParagraph) Your plan: \(spokenSummary). \(pillarList)."
    }
}
