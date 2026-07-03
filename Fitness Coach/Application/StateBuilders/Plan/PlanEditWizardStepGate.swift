//
//  PlanEditWizardStepGate.swift
//  Fitness Coach
//
//  Forma — Step advancement and save eligibility for Edit Plan wizard.
//

import Foundation

enum PlanEditWizardStepGate {

    static func canAdvance(
        from step: PlanEditWizardStep?,
        formState: PlanFormState,
        goalType: PlanGoalType,
        goalWeightValidationMessage: String?,
        pacePreview: WeightLossPacePreviewModel
    ) -> Bool {
        switch step {
        case .goalAndTargetWeight:
            guard goalWeightValidationMessage == nil else { return false }
            guard goalType == .loseFat else { return true }
            return pacePreview.isSaveable
        case .birthdayAndSex:
            guard let birthDate = formState.birthDate else { return false }
            return BirthDateAgeResolver.isValidBirthDate(birthDate)
                && formState.sex != .preferNotToSay
        case .heightAndWeight:
            return PlanBodyBaselineValidationBuilder.validate(
                heightText: formState.heightCmText,
                weightText: formState.currentWeightKgText
            ).isValid
        case .activityLevel, .reviewChanges:
            return true
        case .confirmTargets:
            return true
        case .none:
            return false
        }
    }

    static func canSave(
        targetPreview: CalorieTargetResult?,
        reviewHasChanges: Bool,
        isSaving: Bool
    ) -> Bool {
        targetPreview != nil && reviewHasChanges && !isSaving
    }

    static func hasUnsavedChanges(
        baseline: UserProfile,
        formState: PlanFormState
    ) -> Bool {
        PlanEditReviewBuilder.build(baseline: baseline, formState: formState).hasChanges
    }

    static func shouldWarnCustomPaceAfterActivityChange(
        formState: PlanFormState
    ) -> Bool {
        guard formState.weightLossPaceChoice == .advanced,
              let captured = formState.customPaceActivityLevel else {
            return false
        }
        return captured != formState.activityLevel
    }

    static func nonCutPaceNotice(goalType: PlanGoalType, formState: PlanFormState) -> String? {
        guard goalType != .loseFat else { return nil }
        guard formState.weightLossPaceChoice == .advanced else { return nil }

        switch goalType {
        case .gainMuscle:
            return FormaProductCopy.PlanEditPace.gainGoalIgnoresCutPace
        case .maintain:
            return FormaProductCopy.PlanEditPace.maintainGoalIgnoresCutPace
        case .loseFat:
            return nil
        }
    }
}
