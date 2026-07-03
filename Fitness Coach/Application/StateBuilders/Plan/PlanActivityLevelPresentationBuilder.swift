//
//  PlanActivityLevelPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Activity level card presentations for Edit Plan.
//

import Foundation

struct PlanActivityLevelPresentation: Equatable, Identifiable, Sendable {
    var id: ActivityLevel { level }
    let level: ActivityLevel
    let title: String
    let description: String
    let exampleBehavior: String
    let maintenanceImpactLabel: String?
    let iconSystemName: String
}

enum PlanActivityLevelPresentationBuilder {

    static func options(formState: PlanFormState) -> [PlanActivityLevelPresentation] {
        OnboardingActivityLevelValues.orderedLevels.map { level in
            presentation(for: level, formState: formState)
        }
    }

    static func presentation(
        for level: ActivityLevel,
        formState: PlanFormState
    ) -> PlanActivityLevelPresentation {
        let copy = activityCopy(for: level)
        let maintenanceImpact = maintenanceImpactLabel(
            for: level,
            formState: formState
        )

        return PlanActivityLevelPresentation(
            level: level,
            title: PlanFormatter.activityLevel(level),
            description: copy.description,
            exampleBehavior: copy.example,
            maintenanceImpactLabel: maintenanceImpact,
            iconSystemName: OnboardingActivityLevelValues.icon(for: level)
        )
    }

    private static func maintenanceImpactLabel(
        for level: ActivityLevel,
        formState: PlanFormState
    ) -> String? {
        guard let maintenance = PlanBodyBaselineMaintenanceEstimator.previewMaintenanceKcal(
            for: level,
            formState: formState
        ) else {
            return nil
        }
        return FormaProductCopy.PlanEditActivity.maintenanceImpact(
            PlanDisplayFormatter.formatKcalPerDay(maintenance)
        )
    }

    private static func activityCopy(for level: ActivityLevel) -> (description: String, example: String) {
        let copy = FormaProductCopy.PlanEditActivity.self
        switch level {
        case .sedentary:
            return (copy.sedentaryDescription, copy.sedentaryExample)
        case .lightlyActive:
            return (copy.lightlyActiveDescription, copy.lightlyActiveExample)
        case .moderatelyActive:
            return (copy.moderatelyActiveDescription, copy.moderatelyActiveExample)
        case .veryActive:
            return (copy.veryActiveDescription, copy.veryActiveExample)
        case .athlete:
            return (copy.athleteDescription, copy.athleteExample)
        }
    }
}
