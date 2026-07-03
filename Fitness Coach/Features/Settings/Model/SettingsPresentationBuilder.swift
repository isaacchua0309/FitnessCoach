//
//  SettingsPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds Settings hub presentation state from runtime inputs.
//

import Foundation

enum SettingsPresentationBuilder {

    static func build(input: SettingsPresentationInput) -> SettingsPresentationState {
        SettingsPresentationState(
            account: accountSection(),
            preferences: preferencesSection(),
            integrations: integrationsSection(integrationState: input.integrationState),
            privacyData: privacyDataSection(featureAvailability: input.featureAvailability),
            support: supportSection(),
            about: aboutSection(appVersionDisplay: input.appVersionDisplay),
            developer: developerSection(isDebugOrInternalBuild: input.isDebugOrInternalBuild),
            isDebugOrInternalBuild: input.isDebugOrInternalBuild
        )
    }

    // MARK: - Sections

    private static func accountSection() -> SettingsAccountSectionState {
        SettingsAccountSectionState(
            title: FormaProductCopy.Settings.Hub.accountSectionTitle,
            rows: [
                row(
                    id: .account,
                    title: FormaProductCopy.Settings.Rows.account,
                    destination: .account
                )
            ]
        )
    }

    private static func preferencesSection() -> SettingsPreferencesSectionState {
        SettingsPreferencesSectionState(
            title: FormaProductCopy.Settings.Hub.preferencesSectionTitle,
            rows: [
                row(
                    id: .units,
                    title: FormaProductCopy.Settings.Rows.units,
                    destination: .units
                ),
                row(
                    id: .bodyAndStats,
                    title: FormaProductCopy.PlanCalculation.bodyDetailsSettingsTitle,
                    destination: .bodyAndStats
                ),
                row(
                    id: .theme,
                    title: FormaProductCopy.Settings.Theme.navigationRowTitle,
                    destination: .theme
                )
            ]
        )
    }

    private static func integrationsSection(
        integrationState: TrainingIntegrationState
    ) -> SettingsIntegrationsSectionState {
        SettingsIntegrationsSectionState(
            title: FormaProductCopy.Settings.Hub.integrationsSectionTitle,
            rows: [
                row(
                    id: .appleHealth,
                    title: FormaProductCopy.Settings.Rows.appleHealth,
                    status: TrainingIntegrationCopy.settingsStatusLabel(for: integrationState),
                    destination: .appleHealthIntegration
                )
            ]
        )
    }

    private static func privacyDataSection(
        featureAvailability: SettingsFeatureAvailability
    ) -> SettingsPrivacyDataSectionState {
        var rows: [SettingsRowPresentation] = [
            row(
                id: .privacyPolicy,
                title: FormaProductCopy.Settings.Rows.privacyPolicy,
                destination: .legalDocument(.privacyPolicy)
            )
        ]

        if featureAvailability.isDataExportEnabled {
            rows.append(
                row(
                    id: .exportData,
                    title: FormaProductCopy.Settings.Rows.exportData,
                    destination: nil
                )
            )
        }

        if featureAvailability.isDeleteDataEnabled {
            rows.append(
                row(
                    id: .deleteData,
                    title: FormaProductCopy.Settings.Rows.deleteData,
                    destination: nil
                )
            )
        }

        return SettingsPrivacyDataSectionState(
            title: FormaProductCopy.Settings.Hub.privacyDataSectionTitle,
            rows: rows
        )
    }

    private static func supportSection() -> SettingsSupportSectionState {
        SettingsSupportSectionState(
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
            ]
        )
    }

    private static func aboutSection(appVersionDisplay: String) -> SettingsAboutSectionState {
        SettingsAboutSectionState(
            title: FormaProductCopy.Settings.Hub.aboutSectionTitle,
            rows: [
                SettingsRowPresentation(
                    id: .appVersion,
                    title: FormaProductCopy.Settings.Rows.appVersion,
                    subtitle: appVersionDisplay,
                    status: nil,
                    destination: nil,
                    isEnabled: false
                ),
                row(
                    id: .termsOfService,
                    title: FormaProductCopy.Settings.Rows.termsOfService,
                    destination: .legalDocument(.terms)
                )
            ]
        )
    }

    private static func developerSection(
        isDebugOrInternalBuild: Bool
    ) -> SettingsDeveloperSectionState? {
        guard isDebugOrInternalBuild else {
            return nil
        }

        return SettingsDeveloperSectionState(
            title: FormaProductCopy.Settings.Hub.developerSectionTitle,
            rows: [
                row(
                    id: .authDiagnostics,
                    title: FormaProductCopy.Settings.Rows.authDiagnostics,
                    destination: .authDiagnostics
                ),
                row(
                    id: .pipelineTraces,
                    title: FormaProductCopy.Settings.Rows.pipelineTraces,
                    destination: .pipelineTraces
                )
            ],
            footer: FormaProductCopy.Settings.Hub.developerSectionFooter
        )
    }

    // MARK: - Row factory

    private static func row(
        id: SettingsRowID,
        title: String,
        subtitle: String? = nil,
        status: String? = nil,
        destination: SettingsRowDestination?
    ) -> SettingsRowPresentation {
        SettingsRowPresentation(
            id: id,
            title: title,
            subtitle: subtitle,
            status: status,
            destination: destination,
            isEnabled: destination != nil
        )
    }
}
