//
//  AppleHealthSettingsPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Apple Health settings presentation tests.
//

import XCTest
@testable import Fitness_Coach

final class AppleHealthSettingsPresentationBuilderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var locale: Locale {
        Locale(identifier: "en_US_POSIX")
    }

    private var timeZone: TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }

    func testConnectedStateShowsHealthDataDetailsAndPermissions() {
        let presentation = build(
            integrationState: .connected,
            permissionStatus: uniformPermission(.available)
        )

        XCTAssertEqual(presentation.heroStatus, FormaProductCopy.Settings.AppleHealth.statusConnected)
        XCTAssertTrue(presentation.heroShowsConnected)
        XCTAssertEqual(presentation.healthDataDetailRows.first?.value, FormaProductCopy.Settings.AppleHealth.statusConnected)
        XCTAssertEqual(presentation.permissionRows.count, 8)
        XCTAssertTrue(presentation.permissionRows.allSatisfy { $0.statusLabel == "Connected" })
        XCTAssertFalse(presentation.showsLoadingState)
    }

    func testPartialPermissionsShowPartiallyConnectedStatus() {
        var access = Dictionary(
            uniqueKeysWithValues: HealthSignalKind.allCases.map { ($0, HealthSignalAccess.denied) }
        )
        access[.stepCount] = .available
        access[.workout] = .available

        let presentation = build(
            integrationState: .connected,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: access,
                resolvedAt: Date()
            )
        )

        XCTAssertEqual(
            presentation.heroStatus,
            FormaProductCopy.Settings.AppleHealth.statusPartiallyConnected
        )
        XCTAssertTrue(presentation.heroShowsConnected)

        let steps = presentation.permissionRows.first(where: { $0.id == HealthPermissionCategory.steps.rawValue })
        let sleep = presentation.permissionRows.first(where: { $0.id == HealthPermissionCategory.sleep.rawValue })
        XCTAssertEqual(steps?.statusLabel, "Connected")
        XCTAssertEqual(sleep?.statusLabel, "Denied")
    }

    func testDisconnectedStateOffersConnectAction() {
        let presentation = build(integrationState: .notConnected)

        XCTAssertEqual(presentation.heroStatus, FormaProductCopy.Settings.AppleHealth.statusNotConnected)
        XCTAssertFalse(presentation.heroShowsConnected)
        XCTAssertTrue(presentation.actions.contains(where: { $0.kind == .connectAppleHealth }))
        XCTAssertEqual(
            presentation.actions.first(where: { $0.kind == .connectAppleHealth })?.title,
            FormaProductCopy.Settings.AppleHealth.connectAction
        )
    }

    func testDeniedStateOffersManageInHealthApp() {
        let presentation = build(integrationState: .denied)

        XCTAssertEqual(presentation.heroStatus, FormaProductCopy.Settings.AppleHealth.statusPermissionNeeded)
        XCTAssertTrue(presentation.actions.contains(where: { $0.kind == .manageInAppleHealth }))
    }

    func testLastLocalSyncFormattedWhenAvailable() {
        let syncDate = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 2,
            hour: 14,
            minute: 30
        ))!
        let localState = HealthSyncState(
            phase: .succeeded,
            trigger: .manual,
            progress: .zero,
            signalResults: [],
            lastSuccessfulSyncAt: syncDate,
            lastError: nil,
            updatedAt: syncDate
        )

        let presentation = build(
            integrationState: .connected,
            localSyncState: localState,
            now: syncDate
        )

        XCTAssertEqual(
            rowValue("last-local-sync", in: presentation.healthDataDetailRows),
            AppleHealthSettingsLastSyncFormatter.format(
                syncDate,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )
        )
    }

    func testRemoteSyncCapabilityShowsConsentRowButNotLastSyncWithoutOptIn() {
        let presentation = build(
            integrationState: .connected,
            isRemoteSyncCapabilityEnabled: true,
            remoteSyncConsent: .default
        )

        XCTAssertEqual(
            rowValue("remote-sync-consent", in: presentation.healthDataDetailRows),
            FormaProductCopy.Settings.AppleHealth.RemoteSync.Consent.statusNotSet
        )
        XCTAssertNil(rowValue("last-remote-sync", in: presentation.healthDataDetailRows))
        XCTAssertTrue(presentation.showsRemoteSyncDestination)
        XCTAssertTrue(presentation.actions.contains(where: { $0.kind == .manageHealthDataSync }))
        XCTAssertFalse(presentation.actions.contains(where: { $0.kind == .deleteRemoteHealthSummaries }))
    }

    func testRemoteSyncLastSyncShownWhenUserOptedIn() {
        let remoteDate = Date()
        let presentation = build(
            integrationState: .connected,
            isRemoteSyncCapabilityEnabled: true,
            remoteSyncConsent: HealthSummarySyncConsentState(decision: .optedIn, updatedAt: remoteDate),
            remoteSyncState: HealthSummaryRemoteSyncState(
                phase: .succeeded,
                trigger: .manual,
                lastSuccessfulRemoteSyncAt: remoteDate,
                lastAttemptedRemoteSyncAt: remoteDate,
                lastError: nil,
                failedPayloadKinds: [],
                backoffUntil: nil,
                updatedAt: remoteDate
            ),
            now: remoteDate
        )

        XCTAssertNotNil(rowValue("last-remote-sync", in: presentation.healthDataDetailRows))
        XCTAssertTrue(presentation.actions.contains(where: { $0.kind == .deleteRemoteHealthSummaries }))
    }

    func testRemoteSyncActionsHiddenWhenCapabilityDisabled() {
        let presentation = build(
            integrationState: .connected,
            isRemoteSyncCapabilityEnabled: false
        )

        XCTAssertNil(rowValue("remote-sync-consent", in: presentation.healthDataDetailRows))
        XCTAssertFalse(presentation.actions.contains(where: { $0.kind == .manageHealthDataSync }))
        XCTAssertFalse(presentation.actions.contains(where: { $0.kind == .deleteRemoteHealthSummaries }))
    }

    func testRemoteSyncSettingsIncludeConsentConfirmationCopy() {
        let remote = AppleHealthSettingsPresentationBuilder.buildRemoteSyncSettings(
            input: buildInput(
                integrationState: .connected,
                isRemoteSyncCapabilityEnabled: true
            )
        )

        XCTAssertEqual(
            remote.enableConfirmationMessage,
            FormaProductCopy.Settings.AppleHealth.RemoteSync.Consent.enableMessage
        )
        XCTAssertFalse(remote.isConsentToggleOn)
        XCTAssertFalse(remote.showsSyncDetails)
    }

    func testPrivacyBulletsUseProductionCopy() {
        let presentation = build(integrationState: .connected)

        XCTAssertEqual(presentation.privacyBullets, HealthPrivacyCopy.Principles.overviewBullets)
    }

    func testHealthKitUnavailableShowsEmptyState() {
        let presentation = build(
            integrationState: .unavailable,
            isHealthDataAvailable: false,
            loadPhase: .healthKitUnavailable
        )

        XCTAssertEqual(
            presentation.emptyStateMessage,
            FormaProductCopy.Settings.AppleHealth.healthKitUnavailableMessage
        )
        XCTAssertFalse(presentation.actions.contains(where: { $0.kind == .connectAppleHealth }))
    }

    func testPermissionStatusLabelsMatchSettingsSpec() {
        let rows = AppleHealthSettingsPresentationBuilder.permissionRows(
            from: uniformPermission(.notDetermined)
        )

        XCTAssertEqual(rows.first?.statusLabel, "Not shared")

        let deniedRows = AppleHealthSettingsPresentationBuilder.permissionRows(
            from: uniformPermission(.denied)
        )
        XCTAssertEqual(deniedRows.first?.statusLabel, "Denied")
    }

    func testLoadingState() {
        let presentation = build(
            integrationState: .notConnected,
            loadPhase: .loading
        )

        XCTAssertTrue(presentation.showsLoadingState)
        XCTAssertFalse(
            presentation.actions.first(where: { $0.kind == .connectAppleHealth })?.isEnabled ?? true
        )
    }

    private func build(
        integrationState: TrainingIntegrationState,
        permissionStatus: HealthPermissionStatus? = nil,
        localSyncState: HealthSyncState = .idle,
        remoteSyncState: HealthSummaryRemoteSyncState = .disabled,
        isRemoteSyncCapabilityEnabled: Bool = false,
        remoteSyncConsent: HealthSummarySyncConsentState = .default,
        isHealthDataAvailable: Bool = true,
        loadPhase: AppleHealthSettingsLoadPhase = .loaded,
        now: Date = Date()
    ) -> AppleHealthSettingsPresentation {
        AppleHealthSettingsPresentationBuilder.build(
            input: buildInput(
                integrationState: integrationState,
                permissionStatus: permissionStatus,
                localSyncState: localSyncState,
                remoteSyncState: remoteSyncState,
                isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
                remoteSyncConsent: remoteSyncConsent,
                isHealthDataAvailable: isHealthDataAvailable,
                loadPhase: loadPhase
            ),
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
    }

    private func buildInput(
        integrationState: TrainingIntegrationState,
        permissionStatus: HealthPermissionStatus? = nil,
        localSyncState: HealthSyncState = .idle,
        remoteSyncState: HealthSummaryRemoteSyncState = .disabled,
        isRemoteSyncCapabilityEnabled: Bool = false,
        remoteSyncConsent: HealthSummarySyncConsentState = .default,
        isHealthDataAvailable: Bool = true,
        loadPhase: AppleHealthSettingsLoadPhase = .loaded
    ) -> AppleHealthSettingsPresentationInput {
        AppleHealthSettingsPresentationInput(
            integrationState: integrationState,
            permissionStatus: permissionStatus ?? uniformPermission(.available),
            localSyncState: localSyncState,
            remoteSyncState: remoteSyncState,
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
            remoteSyncConsent: remoteSyncConsent,
            isHealthDataAvailable: isHealthDataAvailable,
            loadPhase: loadPhase,
            isRefreshingHealthData: false,
            isDeletingRemoteSummaries: false
        )
    }

    private func uniformPermission(_ access: HealthSignalAccess) -> HealthPermissionStatus {
        HealthPermissionStatus.uniform(access, isHealthDataAvailable: true)
    }

    private func rowValue(
        _ id: String,
        in rows: [AppleHealthSettingsConnectionRow]
    ) -> String? {
        rows.first(where: { $0.id == id })?.value
    }
}

final class AppleHealthSettingsActionHandlerTests: XCTestCase {

    func testConnectActionOnlyConnects() async {
        var openedHealthApp = false
        var connected = false
        var refreshed = false

        await AppleHealthSettingsActionHandler.perform(
            action: .connectAppleHealth,
            openHealthApp: { openedHealthApp = true },
            connect: { connected = true },
            refreshHealthData: { refreshed = true },
            syncRemoteSummaries: {},
            deleteRemoteSummaries: {}
        )

        XCTAssertTrue(connected)
        XCTAssertFalse(openedHealthApp)
        XCTAssertFalse(refreshed)
    }

    func testManageInHealthAppAction() async {
        var openedHealthApp = false

        await AppleHealthSettingsActionHandler.perform(
            action: .manageInAppleHealth,
            openHealthApp: { openedHealthApp = true },
            connect: {},
            refreshHealthData: {},
            syncRemoteSummaries: {},
            deleteRemoteSummaries: {}
        )

        XCTAssertTrue(openedHealthApp)
    }
}
