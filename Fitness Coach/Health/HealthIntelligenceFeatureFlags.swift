//
//  HealthIntelligenceFeatureFlags.swift
//  Fitness Coach
//
//  Forma — Health Intelligence rollout flags (facade over FormaAbTest).
//
//  ## Runtime vs production intent
//  | Layer | Source | Notes |
//  |-------|--------|-------|
//  | Runtime default | `FormaAbTestSnapshot.allEnabled` | All HI gates on in internal builds |
//  | Production intent | `FormaAbTestSnapshot.production` | UI/weekly/remote off; coach context on |
//  | Env keys below | Documentation only | Resolver reads `FormaAbTest`, not process env |
//
//  **Owner:** Health Intelligence platform.
//  **Registry:** `Docs/Architecture/FeatureFlagRegistry.md` § Health Intelligence.
//
//  ## Production defaults (documented ship intent)
//  | Flag | Env key (docs only) | Production default | Effect when off |
//  |------|---------------------|--------------------|-----------------|
//  | Foundation | `FORMA_HEALTH_INTELLIGENCE_ENABLED` | `true` | Disables all HI wiring |
//  | Engines | `FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED` | `true` | No snapshot/review composition |
//  | UI | `FORMA_HEALTH_INTELLIGENCE_UI_ENABLED` | `false` | Today/Journey/Plan HI hidden |
//  | Coach context | `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED` | `true` | Coach omits HI from context packets |
//  | Weekly review | `FORMA_HEALTH_INTELLIGENCE_WEEKLY_REVIEW_ENABLED` | `false` | No weekly review generation |
//  | Remote summary sync | `FORMA_HEALTH_SUMMARY_REMOTE_SYNC_ENABLED` | `false` | No Firestore health upload |
//
//  Coach Health Intelligence context is **on by default** in production intent when engines are enabled.
//  Set `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED=0` only as an operational rollback — not for
//  A/B testing or user-facing toggles.
//

import Foundation

// MARK: - Provider

protocol HealthIntelligenceFeatureFlagProviding: Sendable {
    var healthIntelligenceEnabled: Bool { get }
    var healthIntelligenceEnginesEnabled: Bool { get }
    var healthIntelligenceUIEnabled: Bool { get }
    var healthIntelligenceCoachContextEnabled: Bool { get }
    var healthIntelligenceWeeklyReviewEnabled: Bool { get }
    var isSyncEnabled: Bool { get }
    var isRepositoryReadRoutingEnabled: Bool { get }
    var isTodayModelDebugFetchEnabled: Bool { get }
    var isJourneyModelDebugFetchEnabled: Bool { get }
    var isPlanModelDebugFetchEnabled: Bool { get }
    var healthSummaryRemoteSyncEnabled: Bool { get }
    var healthIntelligencePipelineAnalyticsEnabled: Bool { get }
    var shouldTodayModelLoadHealthIntelligence: Bool { get }
    var shouldCoachLoadHealthIntelligence: Bool { get }
    var shouldJourneyModelLoadHealthIntelligence: Bool { get }
    var shouldPlanModelLoadHealthIntelligence: Bool { get }
}

// MARK: - Flags

enum HealthIntelligenceFeatureFlags {

    /// Injectable override for unit tests. Reset to `nil` in `tearDown`.
    nonisolated(unsafe) static var testOverride: (any HealthIntelligenceFeatureFlagProviding)?

    enum Defaults {
        static let foundationEnabled = FormaAbTest.HealthIntelligence.foundationEnabled
        static let enginesEnabled = FormaAbTest.HealthIntelligence.enginesEnabled
        static let uiEnabled = FormaAbTest.HealthIntelligence.uiEnabled
        static let coachContextEnabled = FormaAbTest.HealthIntelligence.coachContextEnabled
        static let weeklyReviewEnabled = FormaAbTest.HealthIntelligence.weeklyReviewEnabled
        static let syncEnabled = FormaAbTest.HealthIntelligence.syncEnabled
        static let remoteSummarySyncEnabled = FormaAbTest.HealthIntelligence.remoteSummarySyncEnabled
        static let pipelineAnalyticsEnabled = FormaAbTest.HealthIntelligence.pipelineAnalyticsEnabled
        static let repositoryReadRoutingEnabled = FormaAbTest.HealthIntelligence.repositoryReadRoutingEnabled
    }

    /// Legacy env keys retained for documentation and test fixtures.
    enum EnvironmentKey {
        static let foundation = "FORMA_HEALTH_INTELLIGENCE_ENABLED"
        static let engines = "FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED"
        static let ui = "FORMA_HEALTH_INTELLIGENCE_UI_ENABLED"
        static let coachContext = "FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED"
        static let weeklyReview = "FORMA_HEALTH_INTELLIGENCE_WEEKLY_REVIEW_ENABLED"
        static let sync = "FORMA_HEALTH_INTELLIGENCE_SYNC_ENABLED"
        static let repositoryReads = "FORMA_HEALTH_INTELLIGENCE_REPOSITORY_READS_ENABLED"
        static let remoteSummarySync = "FORMA_HEALTH_SUMMARY_REMOTE_SYNC_ENABLED"
        static let pipelineAnalytics = "FORMA_HEALTH_INTELLIGENCE_PIPELINE_ANALYTICS_ENABLED"
        static let todayDebugFetch = "FORMA_HEALTH_INTELLIGENCE_TODAY_FETCH_ENABLED"
        static let journeyDebugFetch = "FORMA_HEALTH_INTELLIGENCE_JOURNEY_FETCH_ENABLED"
        static let planDebugFetch = "FORMA_HEALTH_INTELLIGENCE_PLAN_FETCH_ENABLED"
    }

    struct Snapshot: Equatable, Sendable {
        var healthIntelligenceEnabled: Bool
        var healthIntelligenceEnginesEnabled: Bool
        var healthIntelligenceUIEnabled: Bool
        var healthIntelligenceCoachContextEnabled: Bool
        var healthIntelligenceWeeklyReviewEnabled: Bool
        var isSyncEnabled: Bool
        var healthSummaryRemoteSyncEnabled: Bool
        var healthIntelligencePipelineAnalyticsEnabled: Bool
        var isRepositoryReadRoutingEnabled: Bool
        var shouldTodayModelLoadHealthIntelligence: Bool
        var shouldJourneyModelLoadHealthIntelligence: Bool
        var shouldPlanModelLoadHealthIntelligence: Bool
        var shouldCoachLoadHealthIntelligence: Bool
    }

    static func snapshot(environment: [String: String] = [:]) -> Snapshot {
        _ = environment
        let flags = provider
        return Snapshot(
            healthIntelligenceEnabled: flags.healthIntelligenceEnabled,
            healthIntelligenceEnginesEnabled: flags.healthIntelligenceEnginesEnabled,
            healthIntelligenceUIEnabled: flags.healthIntelligenceUIEnabled,
            healthIntelligenceCoachContextEnabled: flags.healthIntelligenceCoachContextEnabled,
            healthIntelligenceWeeklyReviewEnabled: flags.healthIntelligenceWeeklyReviewEnabled,
            isSyncEnabled: flags.isSyncEnabled,
            healthSummaryRemoteSyncEnabled: flags.healthSummaryRemoteSyncEnabled,
            healthIntelligencePipelineAnalyticsEnabled: flags.healthIntelligencePipelineAnalyticsEnabled,
            isRepositoryReadRoutingEnabled: flags.isRepositoryReadRoutingEnabled,
            shouldTodayModelLoadHealthIntelligence: flags.shouldTodayModelLoadHealthIntelligence,
            shouldJourneyModelLoadHealthIntelligence: flags.shouldJourneyModelLoadHealthIntelligence,
            shouldPlanModelLoadHealthIntelligence: flags.shouldPlanModelLoadHealthIntelligence,
            shouldCoachLoadHealthIntelligence: flags.shouldCoachLoadHealthIntelligence
        )
    }

    private static var provider: any HealthIntelligenceFeatureFlagProviding {
        testOverride ?? AbTestHealthIntelligenceFeatureFlags()
    }

    static var healthIntelligenceEnabled: Bool { provider.healthIntelligenceEnabled }
    static var healthIntelligenceEnginesEnabled: Bool { provider.healthIntelligenceEnginesEnabled }
    static var healthIntelligenceUIEnabled: Bool { provider.healthIntelligenceUIEnabled }
    static var isUIEnabled: Bool { healthIntelligenceUIEnabled }
    static var healthIntelligenceCoachContextEnabled: Bool { provider.healthIntelligenceCoachContextEnabled }
    static var healthIntelligenceWeeklyReviewEnabled: Bool { provider.healthIntelligenceWeeklyReviewEnabled }
    static var isSyncEnabled: Bool { provider.isSyncEnabled }
    static var healthSummaryRemoteSyncEnabled: Bool { provider.healthSummaryRemoteSyncEnabled }
    static var healthIntelligencePipelineAnalyticsEnabled: Bool { provider.healthIntelligencePipelineAnalyticsEnabled }
    static var isRepositoryReadRoutingEnabled: Bool { provider.isRepositoryReadRoutingEnabled }
    static var isTodayModelDebugFetchEnabled: Bool { provider.isTodayModelDebugFetchEnabled }
    static var isJourneyModelDebugFetchEnabled: Bool { provider.isJourneyModelDebugFetchEnabled }
    static var isPlanModelDebugFetchEnabled: Bool { provider.isPlanModelDebugFetchEnabled }
    static var shouldTodayModelLoadHealthIntelligence: Bool { provider.shouldTodayModelLoadHealthIntelligence }
    static var shouldCoachLoadHealthIntelligence: Bool { provider.shouldCoachLoadHealthIntelligence }
    static var shouldJourneyModelLoadHealthIntelligence: Bool { provider.shouldJourneyModelLoadHealthIntelligence }
    static var shouldPlanModelLoadHealthIntelligence: Bool { provider.shouldPlanModelLoadHealthIntelligence }
}

// MARK: - AbTest-backed provider

struct AbTestHealthIntelligenceFeatureFlags: HealthIntelligenceFeatureFlagProviding {
    var healthIntelligenceEnabled: Bool { FormaAbTest.HealthIntelligence.foundationEnabled }
    var healthIntelligenceEnginesEnabled: Bool { FormaAbTest.HealthIntelligence.enginesEnabled }
    var healthIntelligenceUIEnabled: Bool { FormaAbTest.HealthIntelligence.uiEnabled }
    var healthIntelligenceCoachContextEnabled: Bool { FormaAbTest.HealthIntelligence.coachContextEnabled }
    var healthIntelligenceWeeklyReviewEnabled: Bool { FormaAbTest.HealthIntelligence.weeklyReviewEnabled }
    var isSyncEnabled: Bool { FormaAbTest.HealthIntelligence.syncEnabled }
    var healthSummaryRemoteSyncEnabled: Bool { FormaAbTest.HealthIntelligence.remoteSummarySyncEnabled }
    var healthIntelligencePipelineAnalyticsEnabled: Bool {
        FormaAbTest.HealthIntelligence.pipelineAnalyticsEnabled
    }
    var isRepositoryReadRoutingEnabled: Bool { FormaAbTest.HealthIntelligence.repositoryReadRoutingEnabled }
    var isTodayModelDebugFetchEnabled: Bool { FormaAbTest.HealthIntelligence.todayDebugFetchEnabled }
    var isJourneyModelDebugFetchEnabled: Bool { FormaAbTest.HealthIntelligence.journeyDebugFetchEnabled }
    var isPlanModelDebugFetchEnabled: Bool { FormaAbTest.HealthIntelligence.planDebugFetchEnabled }
    var shouldTodayModelLoadHealthIntelligence: Bool { FormaAbTest.HealthIntelligence.shouldTodayModelLoad }
    var shouldCoachLoadHealthIntelligence: Bool { FormaAbTest.HealthIntelligence.shouldCoachLoad }
    var shouldJourneyModelLoadHealthIntelligence: Bool { FormaAbTest.HealthIntelligence.shouldJourneyModelLoad }
    var shouldPlanModelLoadHealthIntelligence: Bool { FormaAbTest.HealthIntelligence.shouldPlanModelLoad }
}

#if DEBUG
struct TestHealthIntelligenceFeatureFlags: HealthIntelligenceFeatureFlagProviding {
    var healthIntelligenceEnabled: Bool = true
    var healthIntelligenceEnginesEnabled: Bool = true
    var healthIntelligenceUIEnabled: Bool = false
    var healthIntelligenceCoachContextEnabled: Bool = true
    var healthIntelligenceWeeklyReviewEnabled: Bool = false
    var isSyncEnabled: Bool = true
    var healthSummaryRemoteSyncEnabled: Bool = true
    var healthIntelligencePipelineAnalyticsEnabled: Bool = true
    var isRepositoryReadRoutingEnabled: Bool = true
    var isTodayModelDebugFetchEnabled: Bool = true
    var isJourneyModelDebugFetchEnabled: Bool = true
    var isPlanModelDebugFetchEnabled: Bool = true

    var shouldTodayModelLoadHealthIntelligence: Bool {
        healthIntelligenceEnginesEnabled && (healthIntelligenceUIEnabled || isTodayModelDebugFetchEnabled)
    }

    var shouldCoachLoadHealthIntelligence: Bool {
        healthIntelligenceEnginesEnabled && healthIntelligenceCoachContextEnabled
    }

    var shouldJourneyModelLoadHealthIntelligence: Bool {
        healthIntelligenceEnginesEnabled && (healthIntelligenceUIEnabled || isJourneyModelDebugFetchEnabled)
    }

    var shouldPlanModelLoadHealthIntelligence: Bool {
        healthIntelligenceEnginesEnabled && (healthIntelligenceUIEnabled || isPlanModelDebugFetchEnabled)
    }
}
#endif
