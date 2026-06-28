//
//  OnboardingFormaProofBuilder.swift
//  Fitness Coach
//
//  Forma — Goal-aware proof state for forma proof onboarding.
//

import Foundation

enum OnboardingFormaProofPathStyle: Equatable, Sendable {
    case loss
    case gain
    case maintain
    case fallback
}

struct OnboardingFormaProofComparisonState: Equatable, Sendable {
    let withoutTitle: String
    let withoutHeadline: String
    let withoutBullets: [String]
    let withTitle: String
    let withHeadline: String
    let withBullets: [String]
    let accessibilityLabel: String
}

struct OnboardingFormaProofState: Equatable, Sendable {
    let title: String
    let subtitle: String
    let heroMetric: String
    let heroSupporting: String
    let journeyLine: String?
    let comparison: OnboardingFormaProofComparisonState
    let trustStrip: String
    let pathStyle: OnboardingFormaProofPathStyle
    let accessibilityLabel: String
    let isPersonalized: Bool
}

enum OnboardingFormaProofBuilder {

    static func build(from formState: OnboardingFormState) -> OnboardingFormaProofState {
        let shared = FormaProductCopy.Onboarding.Flow.FormaProof.self
        let comparisonCopy = shared.Comparison.self

        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = formState.parsedGoalWeightKg else {
            return fallbackState(shared: shared, comparisonCopy: comparisonCopy)
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

        let comparison = comparisonState(
            direction: direction,
            shared: shared,
            comparisonCopy: comparisonCopy
        )

        switch direction {
        case .cut:
            let targetLabel = OnboardingGoalWeightBounds.weightSummary(
                valueKg: goalKg,
                unitSystem: formState.unitSystem
            )
            let heroMetric = shared.lossHero(targetWeightLabel: targetLabel)
            return OnboardingFormaProofState(
                title: shared.Loss.title,
                subtitle: shared.Loss.subtitle,
                heroMetric: heroMetric,
                heroSupporting: shared.Loss.heroSupporting,
                journeyLine: journeyLine,
                comparison: comparison,
                trustStrip: shared.Trust.personalized,
                pathStyle: .loss,
                accessibilityLabel: accessibilityLabel(
                    title: shared.Loss.title,
                    heroMetric: heroMetric,
                    currentKg: currentKg,
                    goalKg: goalKg,
                    unitSystem: formState.unitSystem
                ),
                isPersonalized: true
            )
        case .gain:
            let targetLabel = OnboardingGoalWeightBounds.weightSummary(
                valueKg: goalKg,
                unitSystem: formState.unitSystem
            )
            let heroMetric = shared.gainHero(targetWeightLabel: targetLabel)
            return OnboardingFormaProofState(
                title: shared.Gain.title,
                subtitle: shared.Gain.subtitle,
                heroMetric: heroMetric,
                heroSupporting: shared.Gain.heroSupporting,
                journeyLine: journeyLine,
                comparison: comparison,
                trustStrip: shared.Trust.personalized,
                pathStyle: .gain,
                accessibilityLabel: accessibilityLabel(
                    title: shared.Gain.title,
                    heroMetric: heroMetric,
                    currentKg: currentKg,
                    goalKg: goalKg,
                    unitSystem: formState.unitSystem
                ),
                isPersonalized: true
            )
        case .maintain:
            let targetLabel = OnboardingGoalWeightBounds.weightSummary(
                valueKg: goalKg,
                unitSystem: formState.unitSystem
            )
            let heroMetric = shared.maintainHero(targetWeightLabel: targetLabel)
            return OnboardingFormaProofState(
                title: shared.Maintain.title,
                subtitle: shared.Maintain.subtitle,
                heroMetric: heroMetric,
                heroSupporting: shared.Maintain.heroSupporting,
                journeyLine: journeyLine,
                comparison: comparison,
                trustStrip: shared.Trust.personalized,
                pathStyle: .maintain,
                accessibilityLabel: accessibilityLabel(
                    title: shared.Maintain.title,
                    heroMetric: heroMetric,
                    currentKg: currentKg,
                    goalKg: goalKg,
                    unitSystem: formState.unitSystem
                ),
                isPersonalized: true
            )
        }
    }

    private static func fallbackState(
        shared: FormaProductCopy.Onboarding.Flow.FormaProof.Type,
        comparisonCopy: FormaProductCopy.Onboarding.Flow.FormaProof.Comparison.Type
    ) -> OnboardingFormaProofState {
        OnboardingFormaProofState(
            title: shared.Fallback.title,
            subtitle: shared.Fallback.subtitle,
            heroMetric: shared.Fallback.heroMetric,
            heroSupporting: shared.Fallback.heroSupporting,
            journeyLine: nil,
            comparison: comparisonState(
                direction: nil,
                shared: shared,
                comparisonCopy: comparisonCopy
            ),
            trustStrip: shared.Fallback.trustNote,
            pathStyle: .fallback,
            accessibilityLabel: "\(shared.Fallback.title). \(shared.Fallback.subtitle)",
            isPersonalized: false
        )
    }

    private static func comparisonState(
        direction: OnboardingGoalDirection?,
        shared: FormaProductCopy.Onboarding.Flow.FormaProof.Type,
        comparisonCopy: FormaProductCopy.Onboarding.Flow.FormaProof.Comparison.Type
    ) -> OnboardingFormaProofComparisonState {
        let withoutHeadline: String
        let withHeadline: String

        switch direction {
        case .cut:
            withoutHeadline = shared.Loss.withoutHeadline
            withHeadline = shared.Loss.withHeadline
        case .gain:
            withoutHeadline = shared.Gain.withoutHeadline
            withHeadline = shared.Gain.withHeadline
        case .maintain:
            withoutHeadline = shared.Maintain.withoutHeadline
            withHeadline = shared.Maintain.withHeadline
        case nil:
            withoutHeadline = comparisonCopy.withoutBullets[0]
            withHeadline = comparisonCopy.withFormaBullets[0]
        }

        let accessibility = [
            comparisonCopy.withoutStructureTitle,
            withoutHeadline,
            comparisonCopy.withoutBullets.joined(separator: ". "),
            comparisonCopy.withFormaTitle,
            withHeadline,
            comparisonCopy.withFormaBullets.joined(separator: ". ")
        ].joined(separator: ". ")

        return OnboardingFormaProofComparisonState(
            withoutTitle: comparisonCopy.withoutStructureTitle,
            withoutHeadline: withoutHeadline,
            withoutBullets: comparisonCopy.withoutBullets,
            withTitle: comparisonCopy.withFormaTitle,
            withHeadline: withHeadline,
            withBullets: comparisonCopy.withFormaBullets,
            accessibilityLabel: accessibility
        )
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
        title: String,
        heroMetric: String,
        currentKg: Double,
        goalKg: Double,
        unitSystem: UnitSystem
    ) -> String {
        let currentSpoken = spokenWeight(valueKg: currentKg, unitSystem: unitSystem)
        let goalSpoken = spokenWeight(valueKg: goalKg, unitSystem: unitSystem)
        let heroSpoken = heroMetric
            .replacingOccurrences(of: " kg", with: " kilograms")
            .replacingOccurrences(of: " lb", with: " pounds")
        return "\(title). \(heroSpoken). Current weight \(currentSpoken). Target weight \(goalSpoken)."
    }

    private static func spokenWeight(valueKg: Double, unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            let formatted = valueKg.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(valueKg.rounded()))"
                : String(format: "%.1f", valueKg)
            return "\(formatted) kilograms"
        case .imperial:
            let pounds = valueKg * OnboardingFormState.poundsPerKilogram
            let formatted = pounds.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(pounds.rounded()))"
                : String(format: "%.1f", pounds)
            return "\(formatted) pounds"
        }
    }
}
