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
            preferences: preferencesSection(
                unitSystem: input.unitSystem,
                themePalette: input.themePalette
            ),
            integrations: integrationsSection(integrationState: input.integrationState),
            privacyData: SettingsPrivacyDataPresentationBuilder.buildSection(
                input: SettingsPrivacyDataPresentationInput(
                    status: input.privacyDataStatus,
                    featureAvailability: input.featureAvailability,
                    legalAvailability: input.legalAvailability,
                    accountDeletionWiring: input.accountDeletionWiring
                )
            ),
            support: SettingsSupportPresentationBuilder.buildSection(
                configuration: input.supportConfiguration
            ),
            about: SettingsAboutPresentationBuilder.buildSection(
                input: SettingsAboutPresentationInput(
                    appVersionDisplay: input.appVersion,
                    legalAvailability: input.legalAvailability,
                    privacyPolicyShownInPrivacySection: input.legalAvailability.isPrivacyPolicyAvailable
                )
            ),
            developer: SettingsDeveloperPresentationBuilder.buildSection(
                isVisible: FormaAbTest.Settings.developerSectionVisible && input.isDebugOrInternalBuild
            ),
            legalAvailability: input.legalAvailability,
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

    private static func preferencesSection(
        unitSystem: UnitSystem,
        themePalette: AppThemePalette
    ) -> SettingsPreferencesSectionState {
        SettingsPreferencesSectionState(
            title: FormaProductCopy.Settings.Hub.preferencesSectionTitle,
            rows: [
                row(
                    id: .units,
                    title: FormaProductCopy.Settings.Rows.units,
                    status: SettingsRowStatusFormatter.unitSystem(unitSystem),
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
                    status: SettingsRowStatusFormatter.themePalette(themePalette),
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
                    status: SettingsRowStatusFormatter.appleHealth(integrationState),
                    destination: .appleHealthIntegration
                )
            ]
        )
    }

    // MARK: - Row factory

    private static func row(
        id: SettingsRowID,
        title: String,
        status: String? = nil,
        destination: SettingsRowDestination?
    ) -> SettingsRowPresentation {
        SettingsRowPresentation(
            id: id,
            title: title,
            status: status,
            destination: destination,
            isEnabled: destination != nil
        )
    }
}
