//
//  OnboardingTargetWeightGuidanceBuilder.swift
//  Fitness Coach
//
//  Forma — Live guidance for target weight onboarding.
//

import Foundation

struct OnboardingTargetWeightGuidanceState: Equatable, Sendable {
    let title: String
    let body: String
    let paceLine: String?
    let showsWarning: Bool
    let accessibilityLabel: String
}

enum OnboardingTargetWeightGuidanceBuilder {

    static func guidanceState(for formState: OnboardingFormState) -> OnboardingTargetWeightGuidanceState? {
        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = OnboardingTargetWeightValues.resolvedGoalKg(from: formState) else {
            return nil
        }

        let copy = FormaProductCopy.Onboarding.Flow.TargetWeight.self
        let direction = OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg
        )
        let showsWarning = formState.parsedHeightCm.map {
            OnboardingGoalProjectionBuilder.isGoalBMITooLow(goalWeightKg: goalKg, heightCm: $0)
        } ?? false

        let title: String
        let body: String
        let paceLine: String?

        switch direction {
        case .maintain:
            title = copy.maintainGoalTitle
            body = copy.maintainGoalBody
            paceLine = nil
        case .cut:
            title = copy.realisticTargetTitle
            body = showsWarning
                ? FormaProductCopy.Onboarding.V2.Goal.bmiWarning
                : copy.realisticTargetBody
            paceLine = expectedWeeklyPaceLine(
                currentWeightKg: currentKg,
                unitSystem: formState.unitSystem
            )
        case .gain:
            title = copy.gainGoalTitle
            body = showsWarning
                ? FormaProductCopy.Onboarding.V2.Goal.bmiWarning
                : copy.gainGoalBody
            paceLine = nil
        }

        var accessibilityParts = [title, body]
        if let paceLine {
            accessibilityParts.append(paceLine)
        }

        return OnboardingTargetWeightGuidanceState(
            title: title,
            body: body,
            paceLine: paceLine,
            showsWarning: showsWarning,
            accessibilityLabel: accessibilityParts.joined(separator: ". ")
        )
    }

    private static func expectedWeeklyPaceLine(
        currentWeightKg: Double,
        unitSystem: UnitSystem
    ) -> String {
        let gentleKg = currentWeightKg * FormaCalculationConstants.presetGentleWeeklyLossFraction
        let moderateKg = currentWeightKg * FormaCalculationConstants.presetModerateWeeklyLossFraction
        let low = formattedWeeklyPace(gentleKg, unitSystem: unitSystem)
        let high = formattedWeeklyPace(moderateKg, unitSystem: unitSystem)
        return FormaProductCopy.Onboarding.Flow.TargetWeight.expectedWeeklyPaceRange(
            low: low,
            high: high
        )
    }

    private static func formattedWeeklyPace(_ weeklyKg: Double, unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return weeklyKg.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(weeklyKg.rounded())) kg/week"
                : String(format: "%.1f kg/week", weeklyKg)
        case .imperial:
            let weeklyLb = weeklyKg * OnboardingFormState.poundsPerKilogram
            return weeklyLb.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(weeklyLb.rounded())) lb/week"
                : String(format: "%.1f lb/week", weeklyLb)
        }
    }
}
