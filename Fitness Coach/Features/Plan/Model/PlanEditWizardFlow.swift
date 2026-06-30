//
//  PlanEditWizardFlow.swift
//  Fitness Coach
//
//  Forma — Step ordering for the plan edit wizard.
//

import Foundation

enum PlanEditWizardStep: String, CaseIterable, Equatable, Sendable {
    case goalAndTargetWeight
    case birthdayAndSex
    case heightAndWeight
    case activityLevel
    case reviewChanges
    case confirmTargets

    var title: String {
        switch self {
        case .goalAndTargetWeight:
            return "Goal"
        case .birthdayAndSex:
            return "About you"
        case .heightAndWeight:
            return "Body"
        case .activityLevel:
            return "Activity"
        case .reviewChanges:
            return "Review"
        case .confirmTargets:
            return "Targets"
        }
    }
}

enum PlanEditWizardFlow {

    static func steps(for formState: PlanFormState) -> [PlanEditWizardStep] {
        var steps: [PlanEditWizardStep] = [.goalAndTargetWeight]
        if needsBirthdayAndSexStep(formState) {
            steps.append(.birthdayAndSex)
        }
        steps += [.heightAndWeight, .activityLevel, .reviewChanges, .confirmTargets]
        return steps
    }

    static func needsBirthdayAndSexStep(_ formState: PlanFormState) -> Bool {
        formState.birthDate == nil || formState.sex == .preferNotToSay
    }

    static func index(of step: PlanEditWizardStep, formState: PlanFormState) -> Int? {
        steps(for: formState).firstIndex(of: step)
    }

    static func step(at index: Int, formState: PlanFormState) -> PlanEditWizardStep? {
        let flow = steps(for: formState)
        guard flow.indices.contains(index) else { return nil }
        return flow[index]
    }
}
