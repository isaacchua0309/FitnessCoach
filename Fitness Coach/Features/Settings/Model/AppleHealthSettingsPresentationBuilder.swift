//
//  AppleHealthSettingsPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds Apple Health settings presentation from integration state.
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
        let heroShowsConnected = input.integrationState.isConnected
        let primaryAction = primaryAction(for: input.integrationState)

        return AppleHealthSettingsPresentation(
            screenTitle: copy.screenTitle,
            heroStatus: heroShowsConnected ? copy.heroConnected : copy.heroNotConnected,
            heroShowsConnected: heroShowsConnected,
            trustCopy: [copy.readsWorkoutsCopy, copy.doesNotWriteCopy],
            connectionCardTitle: copy.connectionCardTitle,
            connectionRows: connectionRows(
                integrationState: input.integrationState,
                lastSyncDate: input.lastSyncDate,
                now: now,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            ),
            primaryAction: primaryAction,
            primaryActionTitle: primaryActionTitle(
                for: primaryAction,
                integrationState: input.integrationState
            ),
            isPrimaryActionEnabled: isPrimaryActionEnabled(for: input.integrationState),
            primaryActionAccessibilityHint: primaryActionAccessibilityHint(
                for: primaryAction,
                integrationState: input.integrationState
            )
        )
    }

    // MARK: - Connection rows

    private static func connectionRows(
        integrationState: TrainingIntegrationState,
        lastSyncDate: Date?,
        now: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> [AppleHealthSettingsConnectionRow] {
        let copy = FormaProductCopy.Settings.AppleHealth.self
        var rows: [AppleHealthSettingsConnectionRow] = [
            AppleHealthSettingsConnectionRow(
                id: "status",
                label: copy.statusLabel,
                value: connectionStatus(for: integrationState)
            )
        ]

        if let lastSyncDate {
            rows.append(
                AppleHealthSettingsConnectionRow(
                    id: "last-sync",
                    label: copy.lastSyncLabel,
                    value: AppleHealthSettingsLastSyncFormatter.format(
                        lastSyncDate,
                        calendar: calendar,
                        locale: locale,
                        timeZone: timeZone
                    )
                )
            )
        }

        rows.append(
            contentsOf: [
                AppleHealthSettingsConnectionRow(
                    id: "permissions",
                    label: copy.permissionsLabel,
                    value: copy.permissionsWorkouts
                ),
                AppleHealthSettingsConnectionRow(
                    id: "access",
                    label: copy.accessLabel,
                    value: copy.accessManagedInHealthApp
                )
            ]
        )

        return rows
    }

    static func connectionStatus(for state: TrainingIntegrationState) -> String {
        let copy = FormaProductCopy.Settings.AppleHealth.self
        switch state {
        case .connected:
            return copy.statusConnected
        case .denied:
            return copy.statusPermissionNeeded
        case .notConnected, .unavailable, .requestingPermission, .failed:
            return copy.statusNotConnected
        }
    }

    // MARK: - Primary action

    static func primaryAction(
        for state: TrainingIntegrationState
    ) -> AppleHealthSettingsPrimaryAction {
        switch state {
        case .connected, .denied:
            return .openHealthApp
        case .notConnected, .failed:
            return .connectAppleHealth
        case .unavailable, .requestingPermission:
            return .none
        }
    }

    private static func primaryActionTitle(
        for action: AppleHealthSettingsPrimaryAction,
        integrationState: TrainingIntegrationState
    ) -> String? {
        let copy = FormaProductCopy.Settings.AppleHealth.self
        switch action {
        case .openHealthApp:
            return copy.openHealthAppAction
        case .connectAppleHealth:
            if integrationState.isRequestingPermission {
                return copy.connectingAction
            }
            return copy.connectAction
        case .none:
            return nil
        }
    }

    private static func isPrimaryActionEnabled(
        for state: TrainingIntegrationState
    ) -> Bool {
        switch state {
        case .connected, .denied, .notConnected, .failed:
            return !state.isRequestingPermission
        case .unavailable, .requestingPermission:
            return false
        }
    }

    private static func primaryActionAccessibilityHint(
        for action: AppleHealthSettingsPrimaryAction,
        integrationState: TrainingIntegrationState
    ) -> String? {
        let copy = FormaProductCopy.Settings.AppleHealth.self
        if integrationState.isRequestingPermission {
            return copy.connectingAccessibilityHint
        }

        switch action {
        case .openHealthApp:
            return copy.openHealthAccessibilityHint
        case .connectAppleHealth:
            return copy.connectAccessibilityHint
        case .none:
            return nil
        }
    }
}
