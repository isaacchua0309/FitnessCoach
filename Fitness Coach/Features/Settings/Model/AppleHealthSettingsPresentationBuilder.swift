//
//  AppleHealthSettingsPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds Apple Health settings presentation from integration and permission state.
//

import Foundation

enum AppleHealthSettingsPresentationBuilder {

    static func build(
        input: AppleHealthSettingsPresentationInput,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> AppleHealthSettingsPresentation {
        let copy = FormaProductCopy.Settings.AppleHealth.self
        let permissionRows = permissionRows(from: input.permissionStatus)
        let connectionStatus = overallConnectionStatus(
            integrationState: input.integrationState,
            permissionStatus: input.permissionStatus,
            isHealthDataAvailable: input.isHealthDataAvailable
        )
        let heroShowsConnected = connectionStatus.isConnectedLike

        return AppleHealthSettingsPresentation(
            screenTitle: copy.screenTitle,
            heroStatus: connectionStatus.label,
            heroShowsConnected: heroShowsConnected,
            privacyBullets: HealthPrivacyCopy.Principles.overviewBullets,
            healthDataDetailsTitle: copy.healthDataDetailsTitle,
            healthDataDetailRows: healthDataDetailRows(
                input: input,
                connectionStatus: connectionStatus.label,
                now: now,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            ),
            permissionsSectionTitle: copy.permissionsSectionTitle,
            permissionRows: permissionRows,
            actions: actions(for: input),
            showsLoadingState: input.loadPhase == .loading || input.loadPhase == .idle,
            errorMessage: errorMessage(for: input.loadPhase),
            emptyStateMessage: emptyStateMessage(for: input),
            showsRemoteSyncDestination: input.isRemoteSyncCapabilityEnabled && input.isHealthDataAvailable
        )
    }

    static func buildRemoteSyncSettings(
        input: AppleHealthSettingsPresentationInput,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> AppleHealthRemoteSyncSettingsPresentation {
        let copy = FormaProductCopy.Settings.AppleHealth.RemoteSync.self
        let consentCopy = FormaProductCopy.Settings.AppleHealth.RemoteSync.Consent.self

        return AppleHealthRemoteSyncSettingsPresentation(
            screenTitle: copy.screenTitle,
            intro: copy.intro,
            consentTitle: consentCopy.toggleTitle,
            consentDescription: consentCopy.toggleDescription,
            isConsentToggleOn: input.isRemoteSyncUserEnabled,
            isConsentToggleEnabled: input.loadPhase == .loaded && !input.isDeletingRemoteSummaries,
            consentStatusLabel: consentStatusLabel(for: input.remoteSyncConsent),
            detailRows: remoteSyncDetailRows(
                remoteSyncState: input.remoteSyncState,
                now: now,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            ),
            showsSyncDetails: input.isRemoteSyncActive,
            syncNowActionTitle: input.remoteSyncState.isSyncing
                ? copy.syncingAction
                : copy.syncNowAction,
            isSyncNowEnabled: input.isRemoteSyncActive
                && !input.remoteSyncState.isSyncing
                && input.loadPhase == .loaded,
            deleteActionTitle: copy.deleteRemoteSummariesAction,
            isDeleteEnabled: input.isRemoteSyncCapabilityEnabled
                && input.isRemoteSyncUserEnabled
                && !input.remoteSyncState.isSyncing
                && !input.isDeletingRemoteSummaries
                && input.loadPhase == .loaded,
            enableConfirmationTitle: consentCopy.enableTitle,
            enableConfirmationMessage: consentCopy.enableMessage,
            enableConfirmActionTitle: consentCopy.enableConfirmAction,
            disableConfirmationTitle: consentCopy.disableTitle,
            disableConfirmationMessage: consentCopy.disableMessage,
            disableConfirmActionTitle: consentCopy.disableConfirmAction,
            disableAndDeleteActionTitle: consentCopy.disableAndDeleteAction,
            deleteConfirmationTitle: copy.deleteConfirmationTitle,
            deleteConfirmationMessage: copy.deleteConfirmationMessage,
            deleteConfirmActionTitle: copy.deleteConfirmActionTitle
        )
    }

    // MARK: - Health data details

    private static func healthDataDetailRows(
        input: AppleHealthSettingsPresentationInput,
        connectionStatus: String,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> [AppleHealthSettingsConnectionRow] {
        let copy = FormaProductCopy.Settings.AppleHealth.self
        var rows: [AppleHealthSettingsConnectionRow] = [
            AppleHealthSettingsConnectionRow(
                id: "connection-status",
                label: copy.statusLabel,
                value: connectionStatus
            )
        ]

        rows.append(
            AppleHealthSettingsConnectionRow(
                id: "last-local-sync",
                label: copy.lastLocalSyncLabel,
                value: formattedSyncDate(
                    input.localSyncState.lastSuccessfulSyncAt,
                    unavailableLabel: copy.lastSyncNever,
                    now: now,
                    calendar: calendar,
                    locale: locale,
                    timeZone: timeZone
                )
            )
        )

        if input.isRemoteSyncCapabilityEnabled {
            rows.append(
                AppleHealthSettingsConnectionRow(
                    id: "remote-sync-consent",
                    label: copy.remoteSummarySyncLabel,
                    value: consentStatusLabel(for: input.remoteSyncConsent)
                )
            )
        }

        if input.isRemoteSyncActive {
            rows.append(
                AppleHealthSettingsConnectionRow(
                    id: "last-remote-sync",
                    label: copy.lastRemoteSyncLabel,
                    value: formattedSyncDate(
                        input.remoteSyncState.lastSuccessfulRemoteSyncAt,
                        unavailableLabel: copy.lastSyncNever,
                        now: now,
                        calendar: calendar,
                        locale: locale,
                        timeZone: timeZone
                    )
                )
            )
        }

        return rows
    }

    private static func consentStatusLabel(
        for consent: HealthSummarySyncConsentState
    ) -> String {
        let copy = FormaProductCopy.Settings.AppleHealth.RemoteSync.Consent.self
        switch consent.decision {
        case .optedIn:
            return copy.statusOn
        case .optedOut:
            return copy.statusOff
        case .notDetermined:
            return copy.statusNotSet
        }
    }

    private static func remoteSyncDetailRows(
        remoteSyncState: HealthSummaryRemoteSyncState,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> [AppleHealthSettingsConnectionRow] {
        let copy = FormaProductCopy.Settings.AppleHealth.RemoteSync.self

        return [
            AppleHealthSettingsConnectionRow(
                id: "remote-status",
                label: copy.statusLabel,
                value: remoteSyncStatusLabel(for: remoteSyncState)
            ),
            AppleHealthSettingsConnectionRow(
                id: "remote-last-sync",
                label: copy.lastSyncLabel,
                value: formattedSyncDate(
                    remoteSyncState.lastSuccessfulRemoteSyncAt,
                    unavailableLabel: copy.lastSyncNever,
                    now: now,
                    calendar: calendar,
                    locale: locale,
                    timeZone: timeZone
                )
            )
        ]
    }

    // MARK: - Permissions

    static func permissionRows(
        from permissionStatus: HealthPermissionStatus?
    ) -> [AppleHealthSettingsPermissionRow] {
        guard let permissionStatus else {
            return HealthPermissionCategory.displayCategories.map { category in
                let definition = HealthPrivacyCopy.definition(for: category)
                return AppleHealthSettingsPermissionRow(
                    id: category.rawValue,
                    title: definition.title,
                    statusLabel: HealthPrivacyCopy.SettingsStatus.label(for: .unknown),
                    status: .unknown
                )
            }
        }

        return HealthPermissionDisplayModelBuilder.makeAll(from: permissionStatus).map { model in
            let displayStatus = settingsPermissionStatus(from: model.status)
            return AppleHealthSettingsPermissionRow(
                id: model.category.rawValue,
                title: model.title,
                statusLabel: HealthPrivacyCopy.SettingsStatus.label(for: model.status),
                status: displayStatus
            )
        }
    }

    static func settingsPermissionStatus(
        from displayStatus: HealthPermissionDisplayStatus
    ) -> AppleHealthSettingsPermissionDisplayStatus {
        switch displayStatus {
        case .connected:
            return .connected
        case .notDetermined:
            return .notShared
        case .denied:
            return .denied
        case .unavailable:
            return .unavailable
        case .unknown:
            return .unknown
        }
    }

    // MARK: - Actions

    private static func actions(
        for input: AppleHealthSettingsPresentationInput
    ) -> [AppleHealthSettingsActionModel] {
        let copy = FormaProductCopy.Settings.AppleHealth.self
        var models: [AppleHealthSettingsActionModel] = []

        if shouldShowConnectAction(for: input) {
            models.append(
                AppleHealthSettingsActionModel(
                    id: "connect",
                    kind: .connectAppleHealth,
                    title: input.integrationState.isRequestingPermission
                        ? copy.connectingAction
                        : copy.connectAction,
                    isEnabled: canConnect(for: input),
                    isDestructive: false,
                    accessibilityHint: copy.connectAccessibilityHint
                )
            )
        }

        if input.isHealthDataAvailable, HealthIntelligenceFeatureFlags.isSyncEnabled {
            models.append(
                AppleHealthSettingsActionModel(
                    id: "refresh",
                    kind: .refreshHealthData,
                    title: input.isRefreshingHealthData
                        ? copy.refreshingHealthDataAction
                        : copy.refreshHealthDataAction,
                    isEnabled: canRefreshHealthData(for: input),
                    isDestructive: false,
                    accessibilityHint: copy.refreshHealthDataAccessibilityHint
                )
            )
        }

        if input.isHealthDataAvailable {
            models.append(
                AppleHealthSettingsActionModel(
                    id: "manage-health-app",
                    kind: .manageInAppleHealth,
                    title: copy.openHealthAppAction,
                    isEnabled: input.loadPhase == .loaded && !input.integrationState.isRequestingPermission,
                    isDestructive: false,
                    accessibilityHint: copy.openHealthAccessibilityHint
                )
            )
        }

        if input.isRemoteSyncCapabilityEnabled, input.isHealthDataAvailable {
            models.append(
                AppleHealthSettingsActionModel(
                    id: "manage-remote-sync",
                    kind: .manageHealthDataSync,
                    title: copy.manageHealthDataSyncAction,
                    isEnabled: input.loadPhase == .loaded,
                    isDestructive: false,
                    accessibilityHint: copy.manageHealthDataSyncAccessibilityHint
                )
            )
        }

        if input.isRemoteSyncActive, input.isHealthDataAvailable {
            models.append(
                AppleHealthSettingsActionModel(
                    id: "delete-remote-summaries",
                    kind: .deleteRemoteHealthSummaries,
                    title: input.isDeletingRemoteSummaries
                        ? copy.deletingRemoteSummariesAction
                        : copy.deleteRemoteSummariesAction,
                    isEnabled: canDeleteRemoteSummaries(for: input),
                    isDestructive: true,
                    accessibilityHint: copy.deleteRemoteSummariesAccessibilityHint
                )
            )
        }

        return models
    }

    // MARK: - Connection status

    struct OverallConnectionStatus: Equatable {
        let label: String
        let isConnectedLike: Bool
    }

    static func overallConnectionStatus(
        integrationState: TrainingIntegrationState,
        permissionStatus: HealthPermissionStatus?,
        isHealthDataAvailable: Bool
    ) -> OverallConnectionStatus {
        let copy = FormaProductCopy.Settings.AppleHealth.self

        guard isHealthDataAvailable else {
            return OverallConnectionStatus(
                label: copy.statusUnavailable,
                isConnectedLike: false
            )
        }

        if let permissionStatus {
            let connectedCount = HealthPermissionCategory.displayCategories.filter {
                permissionStatus.access(for: $0.signalKind).isReadable
            }.count

            if connectedCount == HealthPermissionCategory.displayCategories.count {
                return OverallConnectionStatus(
                    label: copy.statusConnected,
                    isConnectedLike: true
                )
            }

            if connectedCount > 0 {
                return OverallConnectionStatus(
                    label: copy.statusPartiallyConnected,
                    isConnectedLike: true
                )
            }

            let hasDenied = HealthPermissionCategory.displayCategories.contains {
                permissionStatus.access(for: $0.signalKind) == .denied
            }
            if hasDenied {
                return OverallConnectionStatus(
                    label: copy.statusPermissionNeeded,
                    isConnectedLike: false
                )
            }
        }

        switch integrationState {
        case .connected:
            return OverallConnectionStatus(label: copy.statusConnected, isConnectedLike: true)
        case .denied:
            return OverallConnectionStatus(label: copy.statusPermissionNeeded, isConnectedLike: false)
        case .unavailable:
            return OverallConnectionStatus(label: copy.statusUnavailable, isConnectedLike: false)
        case .requestingPermission:
            return OverallConnectionStatus(label: copy.statusConnecting, isConnectedLike: false)
        case .notConnected, .failed:
            return OverallConnectionStatus(label: copy.statusNotConnected, isConnectedLike: false)
        }
    }

    // MARK: - Helpers

    private static func formattedSyncDate(
        _ date: Date?,
        unavailableLabel: String,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        guard let date else { return unavailableLabel }
        return AppleHealthSettingsLastSyncFormatter.format(
            date,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
    }

    private static func remoteSyncStatusLabel(
        for state: HealthSummaryRemoteSyncState
    ) -> String {
        let copy = FormaProductCopy.Settings.AppleHealth.RemoteSync.self
        switch state.phase {
        case .disabled:
            return copy.statusDisabled
        case .idle:
            return copy.statusIdle
        case .syncing:
            return copy.statusSyncing
        case .succeeded:
            return copy.statusSucceeded
        case .partialSuccess:
            return copy.statusPartialSuccess
        case .failed:
            return copy.statusFailed
        }
    }

    private static func shouldShowConnectAction(for input: AppleHealthSettingsPresentationInput) -> Bool {
        guard input.isHealthDataAvailable else { return false }

        if let permissionStatus = input.permissionStatus {
            let allConnected = HealthPermissionCategory.displayCategories.allSatisfy {
                permissionStatus.access(for: $0.signalKind).isReadable
            }
            if !allConnected {
                return true
            }
        }

        switch input.integrationState {
        case .notConnected, .denied, .failed:
            return true
        case .connected, .unavailable, .requestingPermission:
            return false
        }
    }

    private static func canConnect(for input: AppleHealthSettingsPresentationInput) -> Bool {
        input.loadPhase == .loaded && !input.integrationState.isRequestingPermission
    }

    private static func canRefreshHealthData(for input: AppleHealthSettingsPresentationInput) -> Bool {
        input.loadPhase == .loaded
            && !input.isRefreshingHealthData
            && !input.localSyncState.isSyncing
            && !input.integrationState.isRequestingPermission
    }

    private static func canDeleteRemoteSummaries(for input: AppleHealthSettingsPresentationInput) -> Bool {
        input.isRemoteSyncActive
            && input.loadPhase == .loaded
            && !input.isDeletingRemoteSummaries
            && !input.remoteSyncState.isSyncing
    }

    private static func errorMessage(for loadPhase: AppleHealthSettingsLoadPhase) -> String? {
        guard case .error(let message) = loadPhase else { return nil }
        return message
    }

    private static func emptyStateMessage(for input: AppleHealthSettingsPresentationInput) -> String? {
        if case .healthKitUnavailable = input.loadPhase {
            return FormaProductCopy.Settings.AppleHealth.healthKitUnavailableMessage
        }
        return nil
    }
}
