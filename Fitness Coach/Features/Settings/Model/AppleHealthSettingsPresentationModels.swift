//
//  AppleHealthSettingsPresentationModels.swift
//  Fitness Coach
//
//  Forma — Presentation models for Settings → Apple Health.
//

import Foundation

enum AppleHealthSettingsLoadPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case error(String)
    case healthKitUnavailable
}

enum AppleHealthSettingsActionKind: Equatable, Sendable {
    case connectAppleHealth
    case refreshHealthData
    case manageInAppleHealth
    case manageHealthDataSync
    case deleteRemoteHealthSummaries
}

enum AppleHealthSettingsPermissionDisplayStatus: String, Equatable, Sendable {
    case connected
    case notShared
    case denied
    case unavailable
    case unknown
}

struct AppleHealthSettingsConnectionRow: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
}

struct AppleHealthSettingsPermissionRow: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let statusLabel: String
    let status: AppleHealthSettingsPermissionDisplayStatus
}

struct AppleHealthSettingsActionModel: Equatable, Identifiable, Sendable {
    let id: String
    let kind: AppleHealthSettingsActionKind
    let title: String
    let isEnabled: Bool
    let isDestructive: Bool
    let accessibilityHint: String?
}

struct AppleHealthSettingsPresentationInput: Equatable, Sendable {
    let integrationState: TrainingIntegrationState
    let permissionStatus: HealthPermissionStatus?
    let localSyncState: HealthSyncState
    let remoteSyncState: HealthSummaryRemoteSyncState
    let isRemoteSyncCapabilityEnabled: Bool
    let remoteSyncConsent: HealthSummarySyncConsentState
    let isHealthDataAvailable: Bool
    let loadPhase: AppleHealthSettingsLoadPhase
    let isRefreshingHealthData: Bool
    let isDeletingRemoteSummaries: Bool

    var isRemoteSyncUserEnabled: Bool {
        remoteSyncConsent.isRemoteSyncAllowed
    }

    var isRemoteSyncActive: Bool {
        HealthSummaryRemoteSyncGate.isActive(
            consent: remoteSyncConsent,
            featureFlagEnabled: isRemoteSyncCapabilityEnabled
        )
    }
}

struct AppleHealthSettingsPresentation: Equatable, Sendable {
    let screenTitle: String
    let heroStatus: String
    let heroShowsConnected: Bool
    let privacyBullets: [String]
    let healthDataDetailsTitle: String
    let healthDataDetailRows: [AppleHealthSettingsConnectionRow]
    let permissionsSectionTitle: String
    let permissionRows: [AppleHealthSettingsPermissionRow]
    let actions: [AppleHealthSettingsActionModel]
    let showsLoadingState: Bool
    let errorMessage: String?
    let emptyStateMessage: String?
    let showsRemoteSyncDestination: Bool
}

struct AppleHealthRemoteSyncSettingsPresentation: Equatable, Sendable {
    let screenTitle: String
    let intro: String
    let consentTitle: String
    let consentDescription: String
    let isConsentToggleOn: Bool
    let isConsentToggleEnabled: Bool
    let consentStatusLabel: String
    let detailRows: [AppleHealthSettingsConnectionRow]
    let showsSyncDetails: Bool
    let syncNowActionTitle: String
    let isSyncNowEnabled: Bool
    let deleteActionTitle: String
    let isDeleteEnabled: Bool
    let enableConfirmationTitle: String
    let enableConfirmationMessage: String
    let enableConfirmActionTitle: String
    let disableConfirmationTitle: String
    let disableConfirmationMessage: String
    let disableConfirmActionTitle: String
    let disableAndDeleteActionTitle: String
    let deleteConfirmationTitle: String
    let deleteConfirmationMessage: String
    let deleteConfirmActionTitle: String
}
