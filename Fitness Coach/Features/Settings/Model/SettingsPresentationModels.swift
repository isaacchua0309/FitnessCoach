//
//  SettingsPresentationModels.swift
//  Fitness Coach
//
//  Forma — Presentation models for the Settings hub.
//

import Foundation

// MARK: - Row identity

enum SettingsRowID: String, Hashable, CaseIterable, Sendable {
    case account
    case units
    case bodyAndStats
    case theme
    case appleHealth
    case privacyPolicy
    case exportData
    case deleteData
    case sendFeedback
    case contactSupport
    case reportProblem
    case appVersion
    case termsOfService
    case authDiagnostics
    case pipelineTraces
    case healthIntelligenceSnapshot
}

enum SettingsRowDestination: Equatable, Sendable {
    case account
    case units
    case bodyAndStats
    case theme
    case appleHealthIntegration
    case legalDocument(FormaLegalDocument)
    case exportData
    case deleteData
    case supportMail(SettingsSupportMailTopic)
    case authDiagnostics
    case pipelineTraces
    case healthIntelligenceSnapshot
}

enum SettingsSupportMailTopic: String, CaseIterable, Sendable, Identifiable {
    case feedback
    case contactSupport
    case reportProblem

    var id: String { rawValue }
}

// MARK: - Rows and sections

struct SettingsRowPresentation: Equatable, Identifiable, Sendable {
    let id: SettingsRowID
    let title: String
    let status: String?
    let destination: SettingsRowDestination?
    let isEnabled: Bool

    var isNavigable: Bool {
        destination != nil && isEnabled
    }
}

struct SettingsAccountSectionState: Equatable, Sendable {
    let title: String
    let rows: [SettingsRowPresentation]
}

struct SettingsPreferencesSectionState: Equatable, Sendable {
    let title: String
    let rows: [SettingsRowPresentation]
}

struct SettingsIntegrationsSectionState: Equatable, Sendable {
    let title: String
    let rows: [SettingsRowPresentation]
}

struct SettingsPrivacyDataSectionState: Equatable, Sendable {
    let title: String
    let rows: [SettingsRowPresentation]
    let footer: String?
}

struct SettingsSupportSectionState: Equatable, Sendable {
    let title: String
    let rows: [SettingsRowPresentation]
    let footer: String?
}

struct SettingsAboutSectionState: Equatable, Sendable {
    let title: String
    let rows: [SettingsRowPresentation]
}

struct SettingsDeveloperSectionState: Equatable, Sendable {
    let title: String
    let rows: [SettingsRowPresentation]
    let footer: String?
}

// MARK: - Hub state

struct SettingsPresentationInput: Equatable, Sendable {
    let integrationState: TrainingIntegrationState
    let unitSystem: UnitSystem
    let themePalette: AppThemePalette
    let appVersion: String
    let featureAvailability: SettingsFeatureAvailability
    let legalAvailability: SettingsLegalAvailability
    let supportConfiguration: SettingsSupportConfiguration
    let isDebugOrInternalBuild: Bool
}

struct SettingsPresentationState: Equatable, Sendable {
    let account: SettingsAccountSectionState
    let preferences: SettingsPreferencesSectionState
    let integrations: SettingsIntegrationsSectionState
    let privacyData: SettingsPrivacyDataSectionState
    let support: SettingsSupportSectionState?
    let about: SettingsAboutSectionState
    let developer: SettingsDeveloperSectionState?
    let legalAvailability: SettingsLegalAvailability
    let isDebugOrInternalBuild: Bool

    func externalURL(for document: FormaLegalDocument) -> URL? {
        legalAvailability.externalURL(for: document)
    }

    var visibleRowIDs: [SettingsRowID] {
        var rows: [SettingsRowID] = []
        rows += account.rows.map(\.id)
        rows += preferences.rows.map(\.id)
        rows += integrations.rows.map(\.id)
        rows += privacyData.rows.map(\.id)
        if let support {
            rows += support.rows.map(\.id)
        }
        rows += about.rows.map(\.id)
        if let developer {
            rows += developer.rows.map(\.id)
        }
        return rows
    }
}
