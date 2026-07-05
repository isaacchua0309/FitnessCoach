//
//  FormaAbTestProductionCriticalFlagsTests.swift
//  Fitness CoachTests
//
//  Forma — Guards production-critical feature flags and documented ship intent.
//

import XCTest
@testable import Fitness_Coach

final class FormaAbTestProductionCriticalFlagsTests: XCTestCase {

    override func tearDown() {
        FormaAbTest.testOverride = nil
        super.tearDown()
    }

    // MARK: - Runtime resolver (no silent production wiring)

    func testRuntimeResolverUsesAllEnabledByDefault() {
        XCTAssertEqual(FormaAbTest.snapshot(), FormaAbTestSnapshot.allEnabled)
    }

    func testProductionSnapshotDiffersFromRuntimeOnHealthIntelligenceGates() {
        let production = FormaAbTestSnapshot.production
        let runtime = FormaAbTestSnapshot.allEnabled

        XCTAssertTrue(runtime.uiEnabled)
        XCTAssertFalse(production.uiEnabled)

        XCTAssertTrue(runtime.weeklyReviewEnabled)
        XCTAssertFalse(production.weeklyReviewEnabled)

        XCTAssertTrue(runtime.remoteSummarySyncEnabled)
        XCTAssertFalse(production.remoteSummarySyncEnabled)
    }

    // MARK: - Account persistence (compile-time)

    func testAccountPersistenceFlagsRemainEnabledForProduction() {
        XCTAssertTrue(AccountPersistenceFeatureFlags.cloudSchemaEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.syncEngineEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.restoreOnLoginEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.foregroundCrossDeviceRefreshEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.realtimeCrossDeviceSyncEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.manualRefreshEnabled)
    }

    func testPullRecentDataRemainsIntentionallyOff() {
        XCTAssertFalse(AccountPersistenceFeatureFlags.pullRecentDataEnabled)
    }

    func testFormaAbTestAccountPersistenceReadThroughMatchesCompileTimeFlags() {
        XCTAssertEqual(
            FormaAbTest.AccountPersistence.syncEngineEnabled,
            AccountPersistenceFeatureFlags.syncEngineEnabled
        )
        XCTAssertEqual(
            FormaAbTest.AccountPersistence.restoreOnLoginEnabled,
            AccountPersistenceFeatureFlags.restoreOnLoginEnabled
        )
        XCTAssertEqual(
            FormaAbTest.AccountPersistence.foregroundCrossDeviceRefreshEnabled,
            AccountPersistenceFeatureFlags.foregroundCrossDeviceRefreshEnabled
        )
    }

    // MARK: - Account deletion visibility

    func testAccountDeletionCapabilityEnabledAtRuntime() {
        XCTAssertTrue(SettingsDataDeletionCapability.isImplemented)
        XCTAssertTrue(SettingsDataDeletionCapability.isLocalDeviceOnlyEnabled)
    }

    func testProductionIntentKeepsDeletionEnabled() {
        XCTAssertTrue(FormaAbTestSnapshot.production.dataDeletionEnabled)
    }

    func testDeletionRowsVisibleWhenCapabilityEnabled() {
        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false,
                accountDeletionWiring: SettingsAccountDeletionWiring(
                    featureAvailability: .production,
                    hasCoordinator: true
                )
            )
        )

        XCTAssertTrue(state.visibleRowIDs.contains(.deleteAccount))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteLocalDeviceData))
    }

    func testDeletionRowsDisabledWhenCoordinatorMissing() {
        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false,
                accountDeletionWiring: SettingsAccountDeletionWiring(
                    featureAvailability: .production,
                    hasCoordinator: false
                )
            )
        )

        XCTAssertTrue(state.visibleRowIDs.contains(.deleteAccount))
        let deleteAccountRow = state.privacyData.rows.first(where: { $0.id == .deleteAccount })
        XCTAssertNil(deleteAccountRow?.destination)
        XCTAssertFalse(deleteAccountRow?.isEnabled ?? true)
        XCTAssertEqual(
            deleteAccountRow?.status,
            FormaProductCopy.Settings.PrivacyData.deletionCoordinatorUnavailableStatus
        )
    }

    func testDeletionRowsHiddenWhenFlagDisabled() {
        var snapshot = FormaAbTestSnapshot.allEnabled
        snapshot.dataDeletionEnabled = false
        FormaAbTest.testOverride = snapshot

        XCTAssertFalse(SettingsDataDeletionCapability.isImplemented)

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: SettingsFeatureAvailability(
                    isDataExportEnabled: SettingsDataExportCapability.isImplemented,
                    isDeleteAccountEnabled: SettingsDataDeletionCapability.isImplemented,
                    isDeleteLocalDeviceDataEnabled: SettingsDataDeletionCapability.isLocalDeviceOnlyEnabled
                ),
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertFalse(state.visibleRowIDs.contains(.deleteAccount))
        XCTAssertFalse(state.visibleRowIDs.contains(.deleteLocalDeviceData))
    }

    // MARK: - Health Intelligence gating (production intent)

    func testProductionIntentHealthIntelligenceGating() {
        FormaAbTest.testOverride = .production

        let flags = HealthIntelligenceFeatureFlags.snapshot()

        XCTAssertTrue(flags.healthIntelligenceEnabled)
        XCTAssertTrue(flags.healthIntelligenceEnginesEnabled)
        XCTAssertFalse(flags.healthIntelligenceUIEnabled)
        XCTAssertTrue(flags.healthIntelligenceCoachContextEnabled)
        XCTAssertFalse(flags.healthIntelligenceWeeklyReviewEnabled)
        XCTAssertFalse(flags.healthSummaryRemoteSyncEnabled)
        XCTAssertTrue(flags.isSyncEnabled)
        XCTAssertTrue(flags.shouldCoachLoadHealthIntelligence)
        XCTAssertFalse(flags.shouldTodayModelLoadHealthIntelligence)
    }

    // MARK: - Analytics logger selection

    @MainActor
    func testDefaultAnalyticsLoggerSelectionMatchesBuildConfiguration() throws {
        let container = try AppContainer(inMemory: true)

        #if DEBUG
        XCTAssertTrue(container.todayAnalyticsLogger is OSLogTodayAnalyticsLogger)
        XCTAssertTrue(container.settingsAnalyticsLogger is OSLogSettingsAnalyticsLogger)
        XCTAssertTrue(container.onboardingAnalyticsLogger is OSLogOnboardingAnalyticsLogger)
        #else
        XCTAssertTrue(container.todayAnalyticsLogger is NoOpTodayAnalyticsLogger)
        XCTAssertTrue(container.settingsAnalyticsLogger is NoOpSettingsAnalyticsLogger)
        XCTAssertTrue(container.onboardingAnalyticsLogger is NoOpOnboardingAnalyticsLogger)
        #endif
    }
}
