//
//  OnboardingTargetEncouragementCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Dynamic goal confirmation state for target encouragement.
//

import Foundation

struct OnboardingTargetEncouragementState: Equatable, Sendable {
    let title: String
    let heroMetric: String
    let journeyLine: String?
    let reassuranceTitle: String
    let reassuranceBody: String
    let benefits: [OnboardingFeatureBullet]
    let accessibilityLabel: String
    let usesPersonalizedGoal: Bool
}

enum OnboardingTargetEncouragementCopyBuilder {

    static func build(from formState: OnboardingFormState) -> OnboardingTargetEncouragementState {
        let copy = FormaProductCopy.Onboarding.Flow.TargetEncouragement.self
        let benefits = copy.benefits.map { bullet in
            OnboardingFeatureBullet(
                icon: bullet.icon,
                title: bullet.title,
                subtitle: bullet.subtitle
            )
        }

        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = formState.parsedGoalWeightKg else {
            return fallbackState(copy: copy, benefits: benefits)
        }

        let direction = OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg
        )
        let heroMetric = heroMetric(
            direction: direction,
            currentKg: currentKg,
            goalKg: goalKg,
            unitSystem: formState.unitSystem,
            copy: copy
        )
        let journeyLine = journeyLine(
            currentKg: currentKg,
            goalKg: goalKg,
            unitSystem: formState.unitSystem
        )

        return OnboardingTargetEncouragementState(
            title: copy.title,
            heroMetric: heroMetric,
            journeyLine: journeyLine,
            reassuranceTitle: copy.reassuranceTitle,
            reassuranceBody: copy.reassuranceBody,
            benefits: benefits,
            accessibilityLabel: accessibilityLabel(
                title: copy.title,
                heroMetric: heroMetric,
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem
            ),
            usesPersonalizedGoal: direction != .maintain || journeyLine != nil
        )
    }

    // MARK: - Legacy helpers (tests / migration)

    static func formattedLossAmount(from formState: OnboardingFormState) -> String? {
        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = formState.parsedGoalWeightKg else {
            return nil
        }

        let lossKg = currentKg - goalKg
        guard lossKg > FormaCalculationConstants.goalDirectionEpsilonKg else {
            return nil
        }

        return OnboardingGoalWeightBounds.weightSummary(
            valueKg: lossKg,
            unitSystem: formState.unitSystem
        )
    }

    private static func fallbackState(
        copy: FormaProductCopy.Onboarding.Flow.TargetEncouragement.Type,
        benefits: [OnboardingFeatureBullet]
    ) -> OnboardingTargetEncouragementState {
        OnboardingTargetEncouragementState(
            title: copy.title,
            heroMetric: copy.fallbackHero,
            journeyLine: nil,
            reassuranceTitle: copy.reassuranceTitle,
            reassuranceBody: copy.reassuranceBody,
            benefits: benefits,
            accessibilityLabel: "\(copy.title). \(copy.fallbackHero)",
            usesPersonalizedGoal: false
        )
    }

    private static func heroMetric(
        direction: OnboardingGoalDirection,
        currentKg: Double,
        goalKg: Double,
        unitSystem: UnitSystem,
        copy: FormaProductCopy.Onboarding.Flow.TargetEncouragement.Type
    ) -> String {
        switch direction {
        case .maintain:
            return copy.maintainHero
        case .cut, .gain:
            return OnboardingGoalWeightBounds.changeSummary(
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: unitSystem
            )
        }
    }

    private static func journeyLine(
        currentKg: Double,
        goalKg: Double,
        unitSystem: UnitSystem
    ) -> String? {
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
        let currentSpoken = accessibilityWeightLabel(valueKg: currentKg, unitSystem: unitSystem)
        let goalSpoken = accessibilityWeightLabel(valueKg: goalKg, unitSystem: unitSystem)
        let heroSpoken = accessibilityHeroMetric(heroMetric, unitSystem: unitSystem)
        return "\(title). \(heroSpoken). Current weight \(currentSpoken). Target weight \(goalSpoken)."
    }

    private static func accessibilityWeightLabel(valueKg: Double, unitSystem: UnitSystem) -> String {
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

    private static func accessibilityHeroMetric(_ heroMetric: String, unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return heroMetric.replacingOccurrences(of: " kg", with: " kilograms")
        case .imperial:
            return heroMetric.replacingOccurrences(of: " lb", with: " pounds")
        }
    }
}
