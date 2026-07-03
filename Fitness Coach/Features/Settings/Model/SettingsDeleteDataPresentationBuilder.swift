//
//  SettingsDeleteDataPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds delete data confirmation copy for Settings.
//

import Foundation

enum SettingsDeleteDataPresentationBuilder {

    static func build() -> SettingsDeleteDataPresentation {
        let copy = FormaProductCopy.Settings.PrivacyData.self
        return SettingsDeleteDataPresentation(
            confirmationTitle: copy.deleteConfirmationTitle,
            confirmationMessage: copy.deleteConfirmationMessage,
            confirmActionTitle: copy.deleteConfirmActionTitle,
            unavailableTitle: copy.deleteUnavailableTitle,
            unavailableMessage: copy.deleteUnavailableMessage
        )
    }
}
