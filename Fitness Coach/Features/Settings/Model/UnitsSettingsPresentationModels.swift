//
//  UnitsSettingsPresentationModels.swift
//  Fitness Coach
//
//  Forma — Units settings presentation models.
//

import Foundation

struct UnitsSettingsPresentationInput: Equatable, Sendable {
    let unitSystem: UnitSystem
}

struct UnitsSettingsExampleRow: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let unit: String
}

struct UnitsSettingsPresentation: Equatable, Sendable {
    let screenTitle: String
    let unitSystemSectionTitle: String
    let examplesSectionTitle: String
    let unitSystemOptions: [UnitSystem]
    let selectedUnitSystem: UnitSystem
    let exampleRows: [UnitsSettingsExampleRow]
    let storageFootnote: String
    let imperialDisplayOnlyFootnote: String?
    let showsImperialDisplayOnlyFootnote: Bool

    func pickerLabel(for unitSystem: UnitSystem) -> String {
        FormaProductCopy.Settings.Units.unitSystemPickerLabel(for: unitSystem)
    }

    func accessibilityLabel(for unitSystem: UnitSystem) -> String {
        FormaProductCopy.Settings.Units.unitSystemAccessibilityLabel(
            for: unitSystem,
            isSelected: unitSystem == selectedUnitSystem
        )
    }
}
