//
//  OnboardingAlmostThereValues.swift
//  Fitness Coach
//
//  Forma — Almost-there milestone copy and benefit mapping.
//

import Foundation

struct OnboardingAlmostThereBenefit: Equatable, Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String

    init(icon: String, title: String) {
        self.id = title
        self.icon = icon
        self.title = title
    }
}

enum OnboardingAlmostThereValues {

    static var benefits: [OnboardingAlmostThereBenefit] {
        FormaProductCopy.Onboarding.Flow.AlmostThereBenefits.items.map { item in
            OnboardingAlmostThereBenefit(icon: item.icon, title: item.title)
        }
    }

    static var benefitsAccessibilityLabel: String {
        FormaProductCopy.Onboarding.Flow.AlmostThere.benefitsAccessibilityLabel
    }

    static var accessibilitySummary: String {
        FormaProductCopy.Onboarding.Flow.AlmostThere.accessibilitySummary
    }
}
