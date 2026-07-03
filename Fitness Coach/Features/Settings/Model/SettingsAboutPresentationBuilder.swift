//
//  SettingsAboutPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds About settings section presentation.
//

import Foundation

struct SettingsAboutPresentationInput: Equatable, Sendable {
    let appVersionDisplay: String
    let legalAvailability: SettingsLegalAvailability
    let privacyPolicyShownInPrivacySection: Bool
}

enum SettingsAboutPresentationBuilder {

    static func buildSection(input: SettingsAboutPresentationInput) -> SettingsAboutSectionState {
        var rows: [SettingsRowPresentation] = [
            versionRow(display: input.appVersionDisplay)
        ]

        if input.legalAvailability.isTermsAvailable {
            rows.append(
                legalRow(
                    id: .termsOfService,
                    title: FormaProductCopy.Settings.Rows.termsOfService,
                    document: .terms
                )
            )
        }

        if !input.privacyPolicyShownInPrivacySection,
           input.legalAvailability.isPrivacyPolicyAvailable {
            rows.append(
                legalRow(
                    id: .privacyPolicy,
                    title: FormaProductCopy.Settings.Rows.privacyPolicy,
                    document: .privacyPolicy
                )
            )
        }

        return SettingsAboutSectionState(
            title: FormaProductCopy.Settings.Hub.aboutSectionTitle,
            rows: rows
        )
    }

    private static func versionRow(display: String) -> SettingsRowPresentation {
        SettingsRowPresentation(
            id: .appVersion,
            title: FormaProductCopy.Settings.Rows.appVersion,
            subtitle: nil,
            status: display,
            destination: nil,
            isEnabled: false
        )
    }

    private static func legalRow(
        id: SettingsRowID,
        title: String,
        document: FormaLegalDocument
    ) -> SettingsRowPresentation {
        SettingsRowPresentation(
            id: id,
            title: title,
            subtitle: nil,
            status: nil,
            destination: .legalDocument(document),
            isEnabled: true
        )
    }
}
