//
//  UnitsSettingsPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds Units settings presentation from unit system state.
//

import Foundation

enum UnitsSettingsPresentationBuilder {

    static func build(input: UnitsSettingsPresentationInput) -> UnitsSettingsPresentation {
        let copy = FormaProductCopy.Settings.Units.self
        let showsImperialFootnote = input.unitSystem == .imperial

        return UnitsSettingsPresentation(
            screenTitle: copy.screenTitle,
            unitSystemSectionTitle: copy.unitSystemSectionTitle,
            examplesSectionTitle: copy.examplesSectionTitle,
            unitSystemOptions: UnitSystem.allCases,
            selectedUnitSystem: input.unitSystem,
            exampleRows: SettingsUnitsDisplayFormatter.exampleRows(for: input.unitSystem),
            storageFootnote: copy.storageFootnote,
            imperialDisplayOnlyFootnote: showsImperialFootnote ? copy.imperialDisplayOnlyFootnote : nil,
            showsImperialDisplayOnlyFootnote: showsImperialFootnote
        )
    }
}
