//
//  FormaAbTestProductionSnapshotTests.swift
//  Fitness CoachTests
//
//  Forma — Production-intent snapshot guardrails (PHASE_20 / FeatureFlagRegistry).
//  Update this file and Docs/Architecture/FeatureFlagRegistry.md when adding flags.
//

import XCTest
@testable import Fitness_Coach

final class FormaAbTestProductionSnapshotTests: XCTestCase {

    /// Mirror-backed count of `FormaAbTestSnapshot` boolean gates.
    /// Increment when adding a new flag property to `FormaAbTestSnapshot`.
    private static let expectedFormaAbTestSnapshotPropertyCount = 44

    private var production: FormaAbTestSnapshot {
        FormaAbTest.resolvedSnapshot(for: .productionIntent)
    }

    // MARK: - Resolver wiring

    func testProductionIntentUsesProductionSnapshotNotRuntimeDefault() {
        XCTAssertEqual(production, FormaAbTestSnapshot.production)
        XCTAssertNotEqual(production, FormaAbTestSnapshot.allEnabled)
        XCTAssertNotEqual(
            FormaAbTest.resolvedSnapshot(for: .release),
            production
        )
    }

    // MARK: - Flag inventory parity

    func testAllEnabledAndProductionExposeSameFlagCount() {
        XCTAssertEqual(
            FormaAbTestSnapshotMirror.flagPropertyNames(for: .allEnabled).count,
            FormaAbTestSnapshotMirror.flagPropertyNames(for: .production).count
        )
    }

    func testFormaAbTestSnapshotPropertyCountMatchesInventory() {
        XCTAssertEqual(
            FormaAbTestSnapshotMirror.flagPropertyNames(for: .allEnabled).count,
            Self.expectedFormaAbTestSnapshotPropertyCount,
            """
            FormaAbTestSnapshot gained or lost a property. Update \
            expectedFormaAbTestSnapshotPropertyCount, FormaAbTestSnapshot.production, \
            Docs/Architecture/FeatureFlagRegistry.md, and PHASE_20 production tables.
            """
        )
    }

    func testRemovedDataExportEnabledNotInSnapshotInventory() {
        let names = FormaAbTestSnapshotMirror.flagPropertyNames(for: .allEnabled)
        XCTAssertFalse(
            names.contains("dataExportEnabled"),
            """
            dataExportEnabled was removed from FormaAbTest; export uses \
            AccountDataExportPolicy.isEnabled — do not reintroduce this flag.
            """
        )
    }

    // MARK: - Health Intelligence (PHASE_20 ship configuration)

    func testProductionHealthIntelligenceSafeDefaults() {
        XCTAssertTrue(production.foundationEnabled)
        XCTAssertTrue(production.enginesEnabled)
        XCTAssertFalse(production.uiEnabled)
        XCTAssertTrue(production.coachContextEnabled)
        XCTAssertFalse(production.weeklyReviewEnabled)
        XCTAssertTrue(production.syncEnabled)
        XCTAssertFalse(production.remoteSummarySyncEnabled)
        XCTAssertTrue(production.repositoryReadRoutingEnabled)
        XCTAssertFalse(production.pipelineAnalyticsEnabled)
        XCTAssertFalse(production.todayDebugFetchEnabled)
        XCTAssertFalse(production.journeyDebugFetchEnabled)
        XCTAssertFalse(production.planDebugFetchEnabled)
    }

    // MARK: - Coach / privacy / internal surfaces

    func testProductionCoachDebugAndTraceFlagsOff() {
        XCTAssertTrue(production.aiCommandParsingEnabled)
        XCTAssertTrue(production.mealPhotoPipelineReady)
        XCTAssertFalse(production.pipelineTraceEnabled)
        XCTAssertFalse(production.pipelineTraceVerbose)
        XCTAssertFalse(production.imageAnalysisDebugLog)
        XCTAssertFalse(production.foodEstimateDebugLog)
    }

    func testProductionInternalAndDeveloperSurfacesOff() {
        XCTAssertFalse(production.developerSectionVisible)
        XCTAssertFalse(production.internalBuildEnabled)
        XCTAssertFalse(production.includesDeveloperTools)
        XCTAssertFalse(production.shipsInAppLegalWithoutPublishedURL)
    }

    func testProductionDiagnosticsTracesOff() {
        XCTAssertFalse(production.todayAnalyticsTrace)
        XCTAssertFalse(production.journeyAnalyticsTrace)
        XCTAssertFalse(production.onboardingAnalyticsTrace)
        XCTAssertFalse(production.settingsAnalyticsTrace)
        XCTAssertFalse(production.themeAnalyticsTrace)
        XCTAssertFalse(production.publicEntryAnalyticsTrace)
        XCTAssertFalse(production.healthIntelligenceAnalyticsTrace)
        XCTAssertFalse(production.weeklyProgressAnalyticsTrace)
        XCTAssertFalse(production.healthTrainingTrace)
        XCTAssertFalse(production.profileBootstrapTrace)
        XCTAssertFalse(production.authSignInTrace)
        XCTAssertFalse(production.todayHydrationTrace)
        XCTAssertFalse(production.accountSyncTrace)
        XCTAssertFalse(production.accountRestoreTrace)
    }

    func testProductionPreservesShippedUserCapabilities() {
        XCTAssertTrue(production.scanFoodEnabled)
        XCTAssertTrue(production.dataDeletionEnabled)
        XCTAssertTrue(production.requiresSignInBeforeOnboarding)
        XCTAssertTrue(production.preservesLocalUserDataOnSignOut)
        XCTAssertTrue(production.clearsCloudSyncMetadataOnSignOut)
        XCTAssertFalse(production.supportsAnonymousSignIn)
        XCTAssertFalse(production.shipsLightAndSystemAppearance)
    }
}

// MARK: - Mirror support

private enum FormaAbTestSnapshotMirror {
    static func flagPropertyNames(for snapshot: FormaAbTestSnapshot) -> [String] {
        Mirror(reflecting: snapshot).children.compactMap(\.label).sorted()
    }
}
