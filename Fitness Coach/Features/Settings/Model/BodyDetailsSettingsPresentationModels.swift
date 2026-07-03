//
//  BodyDetailsSettingsPresentationModels.swift
//  Fitness Coach
//
//  Forma — Body & stats settings presentation models.
//

import Foundation

struct BodyDetailsSettingsPresentationInput: Equatable, Sendable {
    let formState: PlanFormState
    let startingWeightKg: Double?
    let currentWeightKg: Double?

    init(
        formState: PlanFormState,
        startingWeightKg: Double? = nil,
        currentWeightKg: Double? = nil
    ) {
        self.formState = formState
        self.startingWeightKg = startingWeightKg
        self.currentWeightKg = currentWeightKg
    }
}

struct BodyDetailsSettingsDetailRow: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
}

struct BodyDetailsSettingsPresentation: Equatable, Sendable {
    let screenTitle: String
    let profileDetailsSectionTitle: String
    let introCopy: String
    let detailRows: [BodyDetailsSettingsDetailRow]
    let updateInPlanCTA: String
    let updateInPlanAccessibilityHint: String
    let isReadOnly: Bool
}
