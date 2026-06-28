//
//  OnboardingPlanBlueprintBuilder.swift
//  Fitness Coach
//
//  Forma — Goal-aware plan blueprint state for onboarding review.
//

import Foundation

struct OnboardingPlanBlueprintBasisItem: Equatable, Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String
}

struct OnboardingPlanBlueprintState: Equatable, Sendable {
    let screenTitle: String
    let screenSubtitle: String
    let goalSectionTitle: String
    let goalHero: String
    let goalSubtitle: String
    let insight: String
    let basisTitle: String
    let basisItems: [OnboardingPlanBlueprintBasisItem]
    let detailRows: [OnboardingPersonalizationSummaryRecap]
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
        let basisItems = basisItems(copy: copy.Basis.self)

        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = formState.parsedGoalWeightKg else {
            return fallbackState(copy: copy, detailRows: detailRows, basisItems: basisItems)
        }

        let direction = OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg
        )
        let journeyLine = journeyLine(
            currentKg: currentKg,
            goalKg: goalKg,
            unitSystem: formState.unitSystem
        )

        switch direction {
        case .cut:
            let hero = OnboardingGoalWeightBounds.changeSummary(
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem
            )
            return OnboardingPlanBlueprintState(
                screenTitle: copy.title,
                screenSubtitle: copy.subtitle,
                goalSectionTitle: copy.goalSectionTitle,
                goalHero: hero,
                goalSubtitle: journeyLine,
                insight: copy.Insight.loss,
                basisTitle: copy.Basis.title,
                basisItems: basisItems,
                detailRows: detailRows,
                accessibilityLabel: accessibilityLabel(
                    screenTitle: copy.title,
                    goalHero: hero,
                    goalSubtitle: journeyLine,
                    basisTitle: copy.Basis.title
                ),
                isPersonalized: true
            )
        case .gain:
            let hero = OnboardingGoalWeightBounds.changeSummary(
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem
            )
            return OnboardingPlanBlueprintState(
                screenTitle: copy.title,
                screenSubtitle: copy.subtitle,
                goalSectionTitle: copy.goalSectionTitle,
                goalHero: hero,
                goalSubtitle: journeyLine,
                insight: copy.Insight.gain,
                basisTitle: copy.Basis.title,
                basisItems: basisItems,
                detailRows: detailRows,
                accessibilityLabel: accessibilityLabel(
                    screenTitle: copy.title,
                    goalHero: hero,
                    goalSubtitle: journeyLine,
                    basisTitle: copy.Basis.title
                ),
                isPersonalized: true
            )
        case .maintain:
            let targetLabel = OnboardingGoalWeightBounds.weightSummary(
                valueKg: goalKg,
                unitSystem: formState.unitSystem
            )
            let hero = FormaProductCopy.Onboarding.Flow.FormaProof.maintainHero(
                targetWeightLabel: targetLabel
            )
            return OnboardingPlanBlueprintState(
                screenTitle: copy.title,
                screenSubtitle: copy.subtitle,
                goalSectionTitle: copy.goalSectionTitle,
                goalHero: hero,
                goalSubtitle: copy.maintainGoalSubtitle,
                insight: copy.Insight.maintain,
                basisTitle: copy.Basis.title,
                basisItems: basisItems,
                detailRows: detailRows,
                accessibilityLabel: accessibilityLabel(
                    screenTitle: copy.title,
                    goalHero: hero,
                    goalSubtitle: copy.maintainGoalSubtitle,
                    basisTitle: copy.Basis.title
                ),
                isPersonalized: true
            )
        }
    }

    private static func fallbackState(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Type,
        detailRows: [OnboardingPersonalizationSummaryRecap],
        basisItems: [OnboardingPlanBlueprintBasisItem]
    ) -> OnboardingPlanBlueprintState {
        OnboardingPlanBlueprintState(
            screenTitle: copy.title,
            screenSubtitle: copy.subtitle,
            goalSectionTitle: copy.goalSectionTitle,
            goalHero: copy.goalFallbackHero,
            goalSubtitle: copy.goalFallbackSubtitle,
            insight: copy.Insight.fallback,
            basisTitle: copy.Basis.title,
            basisItems: basisItems,
            detailRows: detailRows,
            accessibilityLabel: "\(copy.title). \(copy.goalFallbackHero). \(copy.Basis.title).",
            isPersonalized: false
        )
    }

    private static func basisItems(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Basis.Type
    ) -> [OnboardingPlanBlueprintBasisItem] {
        [
            OnboardingPlanBlueprintBasisItem(
                id: "measurements",
                icon: "ruler",
                title: copy.bodyMeasurements
            ),
            OnboardingPlanBlueprintBasisItem(
                id: "age",
                icon: "calendar",
                title: copy.age
            ),
            OnboardingPlanBlueprintBasisItem(
                id: "sex",
                icon: "person.fill",
                title: copy.sex
            ),
            OnboardingPlanBlueprintBasisItem(
                id: "activity",
                icon: "figure.walk",
                title: copy.activity
            ),
            OnboardingPlanBlueprintBasisItem(
                id: "target",
                icon: "scope",
                title: copy.targetWeight
            )
        ]
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
        return "From \(currentLabel) to \(goalLabel)"
    }

    private static func accessibilityLabel(
        screenTitle: String,
        goalHero: String,
        goalSubtitle: String,
        basisTitle: String
    ) -> String {
        let spokenHero = goalHero
            .replacingOccurrences(of: " kg", with: " kilograms")
            .replacingOccurrences(of: " lb", with: " pounds")
        let spokenSubtitle = goalSubtitle
            .replacingOccurrences(of: " kg", with: " kilograms")
            .replacingOccurrences(of: " lb", with: " pounds")
        return "\(screenTitle). Your goal is \(spokenHero). \(spokenSubtitle). \(basisTitle)."
    }
}
