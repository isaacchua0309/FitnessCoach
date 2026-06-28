//
//  OnboardingAlmostThereValues.swift
//  Fitness Coach
//
//  Forma — Almost-there milestone copy and benefit mapping.
//

import Foundation

enum OnboardingAlmostThereValues {

    static var benefits: [OnboardingBenefitItem] {
        FormaProductCopy.Onboarding.Flow.AlmostThereBenefits.items.map { item in
            OnboardingBenefitItem(icon: item.icon, title: item.title)
        }
    }

    static var benefitsAccessibilityLabel: String {
        FormaProductCopy.Onboarding.Flow.AlmostThere.benefitsAccessibilityLabel
    }

    static var accessibilitySummary: String {
        FormaProductCopy.Onboarding.Flow.AlmostThere.accessibilitySummary
    }
}
