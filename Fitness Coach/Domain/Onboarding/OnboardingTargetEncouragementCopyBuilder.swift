//
//  OnboardingTargetEncouragementCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Dynamic, conservative copy for target encouragement.
//

import Foundation

struct OnboardingTargetEncouragementDisplayCopy: Equatable, Sendable {
    enum Headline: Equatable, Sendable {
        case lossAmount(prefix: String, amount: String, suffix: String)
        case fallback(String)
    }

    let headline: Headline
    let subtitle: String
    let accessibilityHeadline: String

    var usesAccentAmount: Bool {
        if case .lossAmount = headline { return true }
        return false
    }
}

enum OnboardingTargetEncouragementCopyBuilder {

    static func build(from formState: OnboardingFormState) -> OnboardingTargetEncouragementDisplayCopy {
        let copy = FormaProductCopy.Onboarding.Flow.TargetEncouragement.self

        if let amount = formattedLossAmount(from: formState) {
            return OnboardingTargetEncouragementDisplayCopy(
                headline: .lossAmount(
                    prefix: copy.lossTitlePrefix,
                    amount: amount,
                    suffix: copy.lossTitleSuffix
                ),
                subtitle: copy.subtitle,
                accessibilityHeadline: copy.lossTitle(amount: amount)
            )
        }

        return OnboardingTargetEncouragementDisplayCopy(
            headline: .fallback(copy.fallbackTitle),
            subtitle: copy.subtitle,
            accessibilityHeadline: copy.fallbackTitle
        )
    }

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
}
