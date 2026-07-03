//
//  BodyDetailsSettingsPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds Body & stats settings presentation from profile form state.
//

import Foundation

enum BodyDetailsSettingsPresentationBuilder {

    static func build(input: BodyDetailsSettingsPresentationInput) -> BodyDetailsSettingsPresentation {
        let copy = FormaProductCopy.Settings.BodyDetails.self
        let formState = input.formState
        let unitSystem = formState.unitSystem
        let profileWeightKg = parsedPositiveDouble(formState.currentWeightKgText)
        let startingWeightKg = input.startingWeightKg ?? profileWeightKg
        let currentWeightKg = input.currentWeightKg ?? startingWeightKg ?? profileWeightKg

        let rows: [BodyDetailsSettingsDetailRow] = [
            row(
                id: "age",
                label: FormaProductCopy.ProfileForm.age,
                value: formatAge(ageText: formState.ageText, birthDate: formState.birthDate)
            ),
            row(
                id: "height",
                label: FormaProductCopy.ProfileForm.height,
                value: formatHeight(cmText: formState.heightCmText, unitSystem: unitSystem)
            ),
            row(
                id: "sex",
                label: FormaProductCopy.ProfileForm.sex,
                value: formatSex(formState.sex)
            ),
            row(
                id: "starting-weight",
                label: copy.startingWeightLabel,
                value: formatWeight(kg: startingWeightKg, unitSystem: unitSystem)
            ),
            row(
                id: "current-weight",
                label: copy.currentWeightLabel,
                value: formatWeight(kg: currentWeightKg, unitSystem: unitSystem)
            ),
            row(
                id: "unit-system",
                label: FormaProductCopy.ProfileForm.unitSystem,
                value: SettingsUnitsDisplayFormatter.unitSystemSummary(unitSystem)
            )
        ]

        return BodyDetailsSettingsPresentation(
            screenTitle: FormaProductCopy.PlanCalculation.bodyDetailsSettingsTitle,
            profileDetailsSectionTitle: copy.profileDetailsSectionTitle,
            introCopy: copy.introCopy,
            detailRows: rows,
            updateInPlanCTA: copy.updateInPlanCTA,
            updateInPlanAccessibilityHint: copy.updateInPlanAccessibilityHint,
            isReadOnly: true
        )
    }

    // MARK: - Formatting

    static func formatAge(ageText: String, birthDate: Date?) -> String {
        let trimmed = ageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let age = Int(trimmed), age > 0 else {
            return FormaProductCopy.Settings.BodyDetails.notSetValue
        }
        _ = birthDate
        return "\(age) years"
    }

    static func formatHeight(cmText: String, unitSystem: UnitSystem) -> String {
        let trimmed = cmText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard parsedPositiveDouble(trimmed) != nil else {
            return FormaProductCopy.Settings.BodyDetails.notSetValue
        }
        return SettingsUnitsDisplayFormatter.formatHeight(
            fromMetricCmText: trimmed,
            unitSystem: unitSystem
        )
    }

    static func formatSex(_ sex: Sex) -> String {
        switch sex {
        case .preferNotToSay:
            return FormaProductCopy.Settings.BodyDetails.notSetValue
        default:
            return PlanFormatter.sex(sex)
        }
    }

    static func formatWeight(kg: Double?, unitSystem: UnitSystem) -> String {
        guard let kg, kg > 0 else {
            return FormaProductCopy.Settings.BodyDetails.notSetValue
        }
        return SettingsUnitsDisplayFormatter.formatWeight(
            fromMetricKgText: String(kg),
            unitSystem: unitSystem
        )
    }

    // MARK: - Private

    private static func row(id: String, label: String, value: String) -> BodyDetailsSettingsDetailRow {
        BodyDetailsSettingsDetailRow(id: id, label: label, value: value)
    }

    private static func parsedPositiveDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }
}
