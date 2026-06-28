//
//  OnboardingV4TargetEncouragementCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Dynamic, conservative copy for v4 target encouragement.
//

import Foundation

struct OnboardingV4TargetEncouragementDisplayCopy: Equatable, Sendable {
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

enum OnboardingV4TargetEncouragementCopyBuilder {

    static func build(from formState: OnboardingFormState) -> OnboardingV4TargetEncouragementDisplayCopy {
        let copy = FormaProductCopy.Onboarding.V4.TargetEncouragement.self

        if let amount = formattedLossAmount(from: formState) {
            return OnboardingV4TargetEncouragementDisplayCopy(
                headline: .lossAmount(
                    prefix: copy.lossTitlePrefix,
                    amount: amount,
                    suffix: copy.lossTitleSuffix
                ),
                subtitle: copy.subtitle,
                accessibilityHeadline: copy.lossTitle(amount: amount)
            )
        }

        return OnboardingV4TargetEncouragementDisplayCopy(
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
