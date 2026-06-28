//
//  OnboardingAlmostThereValues.swift
//  Fitness Coach
//
//  Forma — Almost-there milestone copy and feature mapping.
//

import Foundation

enum OnboardingAlmostThereValues {

    static var features: [OnboardingFeatureBullet] {
        FormaProductCopy.Onboarding.Flow.AlmostThereFeatures.bullets.map { bullet in
            OnboardingFeatureBullet(
                icon: bullet.icon,
                title: bullet.title,
                subtitle: bullet.subtitle
            )
        }
    }

    static var valueRows: [String] {
        FormaProductCopy.Onboarding.Flow.AlmostThereFeatures.bullets.map(\.title)
    }

    static var valueSectionAccessibilityLabel: String {
        FormaProductCopy.Onboarding.Flow.AlmostThere.valueSectionAccessibilityLabel
    }

    static var accessibilitySummary: String {
        FormaProductCopy.Onboarding.Flow.AlmostThere.accessibilitySummary
    }
}
