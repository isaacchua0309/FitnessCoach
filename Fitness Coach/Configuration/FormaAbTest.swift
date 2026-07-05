//
//  FormaAbTest.swift
//  Fitness Coach
//
//  Forma — Single source of truth for feature gates and rollout toggles.
//
//  ## Runtime vs production intent
//  - **Runtime default:** `FormaAbTestSnapshot.allEnabled` (internal builds and current tests).
//  - **Production intent:** `FormaAbTestSnapshot.production` — documented App Store-safe
//    defaults for release checklists and production-critical tests. Not wired as the runtime
//    resolver until an explicit release pass approves behavior changes.
//
//  Registry: `Docs/Architecture/FeatureFlagRegistry.md`
//

import Foundation

// MARK: - FormaAbTest

enum FormaAbTest {

    /// Injectable override for unit tests. Reset to `nil` in `tearDown`.
    nonisolated(unsafe) static var testOverride: FormaAbTestSnapshot?

    // MARK: Health Intelligence

    enum HealthIntelligence {
        static var foundationEnabled: Bool { resolved.foundationEnabled }

        static var enginesEnabled: Bool {
            guard foundationEnabled else { return false }
            return resolved.enginesEnabled
        }

        static var uiEnabled: Bool {
            guard foundationEnabled else { return false }
            return resolved.uiEnabled
        }

        static var coachContextEnabled: Bool {
            guard foundationEnabled else { return false }
            return resolved.coachContextEnabled
        }

        static var weeklyReviewEnabled: Bool {
            guard foundationEnabled else { return false }
            return resolved.weeklyReviewEnabled
        }

        static var syncEnabled: Bool {
            guard foundationEnabled else { return false }
            return resolved.syncEnabled
        }

        static var remoteSummarySyncEnabled: Bool {
            guard foundationEnabled, syncEnabled else { return false }
            return resolved.remoteSummarySyncEnabled
        }

        static var repositoryReadRoutingEnabled: Bool {
            guard foundationEnabled else { return false }
            return resolved.repositoryReadRoutingEnabled
        }

        static var pipelineAnalyticsEnabled: Bool {
            guard foundationEnabled else { return false }
            return resolved.pipelineAnalyticsEnabled
        }

        static var todayDebugFetchEnabled: Bool { resolved.todayDebugFetchEnabled }
        static var journeyDebugFetchEnabled: Bool { resolved.journeyDebugFetchEnabled }
        static var planDebugFetchEnabled: Bool { resolved.planDebugFetchEnabled }

        static var shouldTodayModelLoad: Bool {
            enginesEnabled && (uiEnabled || todayDebugFetchEnabled)
        }

        static var shouldCoachLoad: Bool {
            enginesEnabled && coachContextEnabled
        }

        static var shouldJourneyModelLoad: Bool {
            enginesEnabled && (uiEnabled || journeyDebugFetchEnabled)
        }

        static var shouldPlanModelLoad: Bool {
            enginesEnabled && (uiEnabled || planDebugFetchEnabled)
        }
    }

    // MARK: Coach
    //
    // Owner: Coach platform. Do not change defaults without Coach regression suite.
    // Registry: Docs/Architecture/FeatureFlagRegistry.md § Coach

    enum Coach {
        static var aiCommandParsingEnabled: Bool { resolved.aiCommandParsingEnabled }
        static var mealPhotoPipelineReady: Bool { resolved.mealPhotoPipelineReady }
        static var pipelineTraceEnabled: Bool { resolved.pipelineTraceEnabled }
        static var pipelineTraceVerbose: Bool { resolved.pipelineTraceVerbose }
        static var imageAnalysisDebugLog: Bool { resolved.imageAnalysisDebugLog }
        static var foodEstimateDebugLog: Bool { resolved.foodEstimateDebugLog }
    }

    // MARK: Today

    enum Today {
        static var scanFoodEnabled: Bool { resolved.scanFoodEnabled }
    }

    // MARK: Theme

    enum Theme {
        static var shipsLightAndSystemAppearance: Bool { resolved.shipsLightAndSystemAppearance }
        static var supportsIncreasedContrastPaletteVariants: Bool {
            resolved.supportsIncreasedContrastPaletteVariants
        }
        static var supportsReduceTransparencyCompositing: Bool {
            resolved.supportsReduceTransparencyCompositing
        }
    }

    // MARK: Settings
    //
    // Export visibility uses `AccountDataExportPolicy` / `SettingsDataExportCapability` — not FormaAbTest.

    enum Settings {
        static var dataDeletionEnabled: Bool { resolved.dataDeletionEnabled }
        static var shipsInAppLegalWithoutPublishedURL: Bool {
            resolved.shipsInAppLegalWithoutPublishedURL
        }
        static var developerSectionVisible: Bool { resolved.developerSectionVisible }
    }

    // MARK: Auth

    enum Auth {
        static var supportsAnonymousSignIn: Bool { resolved.supportsAnonymousSignIn }
        static var requiresSignInBeforeOnboarding: Bool { resolved.requiresSignInBeforeOnboarding }
        /// When true, sign-out retains on-device SwiftData (Phase 1). Reads are UID-filtered instead of wiping.
        static var preservesLocalUserDataOnSignOut: Bool { resolved.preservesLocalUserDataOnSignOut }
        static var clearsCloudSyncMetadataOnSignOut: Bool { resolved.clearsCloudSyncMetadataOnSignOut }
    }

    // MARK: Account persistence

    enum AccountPersistence {
        static var syncEngineEnabled: Bool { AccountPersistenceFeatureFlags.syncEngineEnabled }
        static var uploadPendingMutationsEnabled: Bool {
            AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled
        }
        static var pullRecentDataEnabled: Bool { AccountPersistenceFeatureFlags.pullRecentDataEnabled }
        static var restoreOnLoginEnabled: Bool { AccountPersistenceFeatureFlags.restoreOnLoginEnabled }
        static var foregroundCrossDeviceRefreshEnabled: Bool {
            AccountPersistenceFeatureFlags.foregroundCrossDeviceRefreshEnabled
        }
        static var realtimeCrossDeviceSyncEnabled: Bool {
            AccountPersistenceFeatureFlags.realtimeCrossDeviceSyncEnabled
        }
        static var manualRefreshEnabled: Bool {
            AccountPersistenceFeatureFlags.manualRefreshEnabled
        }
    }

    // MARK: Build

    enum Build {
        static var internalBuildEnabled: Bool { resolved.internalBuildEnabled }
        static var includesDeveloperTools: Bool { resolved.includesDeveloperTools }
    }

    // MARK: Diagnostics

    enum Diagnostics {
        static var todayAnalyticsTrace: Bool { resolved.todayAnalyticsTrace }
        static var journeyAnalyticsTrace: Bool { resolved.journeyAnalyticsTrace }
        static var onboardingAnalyticsTrace: Bool { resolved.onboardingAnalyticsTrace }
        static var settingsAnalyticsTrace: Bool { resolved.settingsAnalyticsTrace }
        static var themeAnalyticsTrace: Bool { resolved.themeAnalyticsTrace }
        static var publicEntryAnalyticsTrace: Bool { resolved.publicEntryAnalyticsTrace }
        static var healthIntelligenceAnalyticsTrace: Bool { resolved.healthIntelligenceAnalyticsTrace }
        static var weeklyProgressAnalyticsTrace: Bool { resolved.weeklyProgressAnalyticsTrace }
        static var healthTrainingTrace: Bool { resolved.healthTrainingTrace }
        static var profileBootstrapTrace: Bool { resolved.profileBootstrapTrace }
        static var authSignInTrace: Bool { resolved.authSignInTrace }
        static var todayHydrationTrace: Bool { resolved.todayHydrationTrace }
        static var accountSyncTrace: Bool { resolved.accountSyncTrace }
        static var accountRestoreTrace: Bool { resolved.accountRestoreTrace }
        static var accountDeletionTrace: Bool { resolved.accountDeletionTrace }
    }

    // MARK: Snapshot

    static func snapshot() -> FormaAbTestSnapshot {
        testOverride ?? .allEnabled
    }

    private static var resolved: FormaAbTestSnapshot {
        testOverride ?? .allEnabled
    }
}

// MARK: - Snapshot

struct FormaAbTestSnapshot: Equatable, Sendable {
    var foundationEnabled: Bool
    var enginesEnabled: Bool
    var uiEnabled: Bool
    var coachContextEnabled: Bool
    var weeklyReviewEnabled: Bool
    var syncEnabled: Bool
    var remoteSummarySyncEnabled: Bool
    var repositoryReadRoutingEnabled: Bool
    var pipelineAnalyticsEnabled: Bool
    var todayDebugFetchEnabled: Bool
    var journeyDebugFetchEnabled: Bool
    var planDebugFetchEnabled: Bool

    var aiCommandParsingEnabled: Bool
    var mealPhotoPipelineReady: Bool
    var pipelineTraceEnabled: Bool
    var pipelineTraceVerbose: Bool
    var imageAnalysisDebugLog: Bool
    var foodEstimateDebugLog: Bool

    var scanFoodEnabled: Bool

    var shipsLightAndSystemAppearance: Bool
    var supportsIncreasedContrastPaletteVariants: Bool
    var supportsReduceTransparencyCompositing: Bool

    var dataDeletionEnabled: Bool
    var shipsInAppLegalWithoutPublishedURL: Bool
    var developerSectionVisible: Bool

    var supportsAnonymousSignIn: Bool
    var requiresSignInBeforeOnboarding: Bool
    var preservesLocalUserDataOnSignOut: Bool
    var clearsCloudSyncMetadataOnSignOut: Bool

    var internalBuildEnabled: Bool
    var includesDeveloperTools: Bool

    var todayAnalyticsTrace: Bool
    var journeyAnalyticsTrace: Bool
    var onboardingAnalyticsTrace: Bool
    var settingsAnalyticsTrace: Bool
    var themeAnalyticsTrace: Bool
    var publicEntryAnalyticsTrace: Bool
    var healthIntelligenceAnalyticsTrace: Bool
    var weeklyProgressAnalyticsTrace: Bool
    var healthTrainingTrace: Bool
    var profileBootstrapTrace: Bool
    var authSignInTrace: Bool
    var todayHydrationTrace: Bool
    var accountSyncTrace: Bool
    var accountRestoreTrace: Bool
    var accountDeletionTrace: Bool

    static let allEnabled = FormaAbTestSnapshot(
        foundationEnabled: true,
        enginesEnabled: true,
        uiEnabled: true,
        coachContextEnabled: true,
        weeklyReviewEnabled: true,
        syncEnabled: true,
        remoteSummarySyncEnabled: true,
        repositoryReadRoutingEnabled: true,
        pipelineAnalyticsEnabled: true,
        todayDebugFetchEnabled: true,
        journeyDebugFetchEnabled: true,
        planDebugFetchEnabled: true,
        aiCommandParsingEnabled: true,
        mealPhotoPipelineReady: true,
        pipelineTraceEnabled: true,
        pipelineTraceVerbose: true,
        imageAnalysisDebugLog: true,
        foodEstimateDebugLog: true,
        scanFoodEnabled: true,
        shipsLightAndSystemAppearance: true,
        supportsIncreasedContrastPaletteVariants: true,
        supportsReduceTransparencyCompositing: true,
        dataDeletionEnabled: true,
        shipsInAppLegalWithoutPublishedURL: true,
        developerSectionVisible: true,
        supportsAnonymousSignIn: true,
        requiresSignInBeforeOnboarding: true,
        preservesLocalUserDataOnSignOut: true,
        clearsCloudSyncMetadataOnSignOut: true,
        internalBuildEnabled: true,
        includesDeveloperTools: true,
        todayAnalyticsTrace: true,
        journeyAnalyticsTrace: true,
        onboardingAnalyticsTrace: true,
        settingsAnalyticsTrace: true,
        themeAnalyticsTrace: true,
        publicEntryAnalyticsTrace: true,
        healthIntelligenceAnalyticsTrace: true,
        weeklyProgressAnalyticsTrace: true,
        healthTrainingTrace: true,
        profileBootstrapTrace: true,
        authSignInTrace: true,
        todayHydrationTrace: true,
        accountSyncTrace: true,
        accountRestoreTrace: true,
        accountDeletionTrace: true
    )

    /// Documented App Store-safe defaults. Used by release checklists and production-critical tests.
    /// Runtime still resolves `allEnabled` until an explicit release pass wires this snapshot.
    static let production = FormaAbTestSnapshot(
        foundationEnabled: true,
        enginesEnabled: true,
        uiEnabled: false,
        coachContextEnabled: true,
        weeklyReviewEnabled: false,
        syncEnabled: true,
        remoteSummarySyncEnabled: false,
        repositoryReadRoutingEnabled: true,
        pipelineAnalyticsEnabled: false,
        todayDebugFetchEnabled: false,
        journeyDebugFetchEnabled: false,
        planDebugFetchEnabled: false,
        aiCommandParsingEnabled: true,
        mealPhotoPipelineReady: true,
        pipelineTraceEnabled: false,
        pipelineTraceVerbose: false,
        imageAnalysisDebugLog: false,
        foodEstimateDebugLog: false,
        scanFoodEnabled: true,
        shipsLightAndSystemAppearance: false,
        supportsIncreasedContrastPaletteVariants: false,
        supportsReduceTransparencyCompositing: false,
        dataDeletionEnabled: true,
        shipsInAppLegalWithoutPublishedURL: false,
        developerSectionVisible: false,
        supportsAnonymousSignIn: false,
        requiresSignInBeforeOnboarding: true,
        preservesLocalUserDataOnSignOut: true,
        clearsCloudSyncMetadataOnSignOut: true,
        internalBuildEnabled: false,
        includesDeveloperTools: false,
        todayAnalyticsTrace: false,
        journeyAnalyticsTrace: false,
        onboardingAnalyticsTrace: false,
        settingsAnalyticsTrace: false,
        themeAnalyticsTrace: false,
        publicEntryAnalyticsTrace: false,
        healthIntelligenceAnalyticsTrace: false,
        weeklyProgressAnalyticsTrace: false,
        healthTrainingTrace: false,
        profileBootstrapTrace: false,
        authSignInTrace: false,
        todayHydrationTrace: false,
        accountSyncTrace: false,
        accountRestoreTrace: false,
        accountDeletionTrace: false
    )
}
