//
//  SettingsSupportPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds Support settings section presentation.
//

import Foundation

enum SettingsSupportPresentationBuilder {

    static func buildSection(
        configuration: SettingsSupportConfiguration
    ) -> SettingsSupportSectionState? {
        guard configuration.isConfigured else { return nil }

        return SettingsSupportSectionState(
            title: FormaProductCopy.Settings.Hub.supportSectionTitle,
            rows: [
                row(
                    id: .sendFeedback,
                    title: FormaProductCopy.Settings.Rows.sendFeedback,
                    destination: .supportMail(.feedback)
                ),
                row(
                    id: .contactSupport,
                    title: FormaProductCopy.Settings.Rows.contactSupport,
                    destination: .supportMail(.contactSupport)
                ),
                row(
                    id: .reportProblem,
                    title: FormaProductCopy.Settings.Rows.reportProblem,
                    destination: .supportMail(.reportProblem)
                )
            ],
            footer: FormaProductCopy.Settings.Support.sectionFooter
        )
    }

    private static func row(
        id: SettingsRowID,
        title: String,
        destination: SettingsRowDestination
    ) -> SettingsRowPresentation {
        SettingsRowPresentation(
            id: id,
            title: title,
            status: nil,
            destination: destination,
            isEnabled: true
        )
    }
}
