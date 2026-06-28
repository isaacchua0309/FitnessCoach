//
//  OnboardingFormaProofBuilder.swift
//  Fitness Coach
//
//  Forma — Goal-aware future-vision state for forma proof onboarding.
//

import Foundation

enum OnboardingFormaProofPathStyle: Equatable, Sendable {
    case loss
    case gain
    case maintain
    case fallback
}

struct OnboardingFormaProofBenefit: Equatable, Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String

    init(icon: String, title: String) {
        self.id = title
        self.icon = icon
        self.title = title
    }
}

struct OnboardingFormaProofState: Equatable, Sendable {
    let visionHeadline: String
    let visionSupporting: String
    let goalIntentLabel: String
    let targetWeightLabel: String
    let benefits: [OnboardingFormaProofBenefit]
    let benefitsAccessibilityLabel: String
    let trustFooter: String
    let pathStyle: OnboardingFormaProofPathStyle
    let ringProgress: Double
    let accessibilityLabel: String
    let isPersonalized: Bool
}

enum OnboardingFormaProofBuilder {

    static func build(from formState: OnboardingFormState) -> OnboardingFormaProofState {
        let shared = FormaProductCopy.Onboarding.Flow.FormaProof.self

        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = formState.parsedGoalWeightKg else {
            return fallbackState(shared: shared)
        }

        let direction = OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg
        )
        let targetLabel = OnboardingGoalWeightBounds.weightSummary(
            valueKg: goalKg,
            unitSystem: formState.unitSystem
        )

        switch direction {
        case .cut:
            return visionState(
                shared: shared,
                intentLabel: shared.Loss.intentLabel,
                targetLabel: targetLabel,
                supporting: shared.Loss.supporting(targetWeightLabel: targetLabel),
                benefits: benefits(from: shared.Loss.benefits),
                pathStyle: .loss,
                ringProgress: ringProgress(currentKg: currentKg, goalKg: goalKg, direction: .cut),
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem,
                isPersonalized: true
            )
        case .gain:
            return visionState(
                shared: shared,
                intentLabel: shared.Gain.intentLabel,
                targetLabel: targetLabel,
                supporting: shared.Gain.supporting(targetWeightLabel: targetLabel),
                benefits: benefits(from: shared.Gain.benefits),
                pathStyle: .gain,
                ringProgress: ringProgress(currentKg: currentKg, goalKg: goalKg, direction: .gain),
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem,
                isPersonalized: true
            )
        case .maintain:
            return visionState(
                shared: shared,
                intentLabel: shared.Maintain.intentLabel,
                targetLabel: targetLabel,
                supporting: shared.Maintain.supporting(targetWeightLabel: targetLabel),
                benefits: benefits(from: shared.Maintain.benefits),
                pathStyle: .maintain,
                ringProgress: 1,
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: formState.unitSystem,
                isPersonalized: true
            )
        }
    }

    private static func fallbackState(
        shared: FormaProductCopy.Onboarding.Flow.FormaProof.Type
    ) -> OnboardingFormaProofState {
        let fallback = shared.Fallback.self
        let benefits = benefits(from: fallback.benefits)
        return OnboardingFormaProofState(
            visionHeadline: shared.visionHeadline,
            visionSupporting: fallback.supporting,
            goalIntentLabel: fallback.intentLabel,
            targetWeightLabel: fallback.targetWeightPlaceholder,
            benefits: benefits,
            benefitsAccessibilityLabel: benefitsAccessibilityLabel(for: benefits),
            trustFooter: fallback.trustNote,
            pathStyle: .fallback,
            ringProgress: 0.75,
            accessibilityLabel: [
                shared.visionHeadline,
                fallback.supporting,
                fallback.trustNote
            ].joined(separator: ". "),
            isPersonalized: false
        )
    }

    private static func visionState(
        shared: FormaProductCopy.Onboarding.Flow.FormaProof.Type,
        intentLabel: String,
        targetLabel: String,
        supporting: String,
        benefits: [OnboardingFormaProofBenefit],
        pathStyle: OnboardingFormaProofPathStyle,
        ringProgress: Double,
        currentKg: Double,
        goalKg: Double,
        unitSystem: UnitSystem,
        isPersonalized: Bool
    ) -> OnboardingFormaProofState {
        OnboardingFormaProofState(
            visionHeadline: shared.visionHeadline,
            visionSupporting: supporting,
            goalIntentLabel: intentLabel,
            targetWeightLabel: targetLabel,
            benefits: benefits,
            benefitsAccessibilityLabel: benefitsAccessibilityLabel(for: benefits),
            trustFooter: shared.Trust.personalized,
            pathStyle: pathStyle,
            ringProgress: ringProgress,
            accessibilityLabel: accessibilityLabel(
                headline: shared.visionHeadline,
                supporting: supporting,
                intentLabel: intentLabel,
                targetLabel: targetLabel,
                currentKg: currentKg,
                goalKg: goalKg,
                unitSystem: unitSystem,
                benefits: benefits,
                trustFooter: shared.Trust.personalized
            ),
            isPersonalized: isPersonalized
        )
    }

    private static func benefits(
        from items: [(icon: String, title: String)]
    ) -> [OnboardingFormaProofBenefit] {
        items.map { OnboardingFormaProofBenefit(icon: $0.icon, title: $0.title) }
    }

    private static func benefitsAccessibilityLabel(
        for benefits: [OnboardingFormaProofBenefit]
    ) -> String {
        let titles = benefits.map(\.title).joined(separator: ". ")
        return "What changes: \(titles)."
    }

    private static func ringProgress(
        currentKg: Double,
        goalKg: Double,
        direction: OnboardingGoalDirection
    ) -> Double {
        switch direction {
        case .maintain:
            return 1
        case .cut, .gain:
            let delta = abs(currentKg - goalKg)
            guard delta > 0 else { return 1 }
            let ratio = min(delta / max(currentKg, goalKg), 1)
            return min(0.88, max(0.62, 1 - (ratio * 0.35)))
        }
    }

    private static func accessibilityLabel(
        headline: String,
        supporting: String,
        intentLabel: String,
        targetLabel: String,
        currentKg: Double,
        goalKg: Double,
        unitSystem: UnitSystem,
        benefits: [OnboardingFormaProofBenefit],
        trustFooter: String
    ) -> String {
        let currentSpoken = spokenWeight(valueKg: currentKg, unitSystem: unitSystem)
        let goalSpoken = spokenWeight(valueKg: goalKg, unitSystem: unitSystem)
        let benefitSpoken = benefits.map(\.title).joined(separator: ". ")
        return [
            headline,
            supporting,
            "\(intentLabel) target \(targetLabel)",
            "Current weight \(currentSpoken)",
            "Target weight \(goalSpoken)",
            benefitSpoken,
            trustFooter
        ].joined(separator: ". ")
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
