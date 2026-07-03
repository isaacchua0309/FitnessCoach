//
//  HealthIntelligenceFeatureFlags.swift
//  Fitness Coach
//
//  Forma — Phase 11–15 rollout flags for Health Intelligence.
//
//  ## Production defaults (safe release)
//  | Flag | Env key | Default | Effect when off |
//  |------|---------|---------|-----------------|
//  | Foundation | `FORMA_HEALTH_INTELLIGENCE_ENABLED` | `true` | Disables all HI wiring |
//  | Engines | `FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED` | `true` | No snapshot/review composition |
//  | UI | `FORMA_HEALTH_INTELLIGENCE_UI_ENABLED` | `false` | Today/Journey/Plan HI hidden |
//  | Coach context | `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED` | `false` | Coach skips HI prompts |
//  | Weekly review | `FORMA_HEALTH_INTELLIGENCE_WEEKLY_REVIEW_ENABLED` | `false` | No weekly review generation |
//
//  Engines and sync can run internally while UI, coach context, and weekly review stay off.
//  Set any flag to `0` in the process environment or Info.plist to disable it.
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
        static let foundationEnabled = true
        static let enginesEnabled = true
        static let uiEnabled = false
        static let coachContextEnabled = false
        static let weeklyReviewEnabled = false
        static let syncEnabled = true
        static let remoteSummarySyncEnabled = false
        static let pipelineAnalyticsEnabled = true
        static let repositoryReadRoutingEnabled = true
    }

    enum EnvironmentKey {
        static let foundation = "FORMA_HEALTH_INTELLIGENCE_ENABLED"
        static let foundationLegacy = "FITPILOT_HEALTH_INTELLIGENCE_ENABLED"
        static let engines = "FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED"
        static let enginesLegacy = "FITPILOT_HEALTH_INTELLIGENCE_ENGINES_ENABLED"
        static let ui = "FORMA_HEALTH_INTELLIGENCE_UI_ENABLED"
        static let uiLegacy = "FITPILOT_HEALTH_INTELLIGENCE_UI_ENABLED"
        static let coachContext = "FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED"
        static let coachContextLegacy = "FITPILOT_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED"
        static let weeklyReview = "FORMA_HEALTH_INTELLIGENCE_WEEKLY_REVIEW_ENABLED"
        static let weeklyReviewLegacy = "FITPILOT_HEALTH_INTELLIGENCE_WEEKLY_REVIEW_ENABLED"
        static let sync = "FORMA_HEALTH_INTELLIGENCE_SYNC_ENABLED"
        static let syncLegacy = "FITPILOT_HEALTH_INTELLIGENCE_SYNC_ENABLED"
        static let repositoryReads = "FORMA_HEALTH_INTELLIGENCE_REPOSITORY_READS_ENABLED"
        static let repositoryReadsLegacy = "FITPILOT_HEALTH_INTELLIGENCE_REPOSITORY_READS_ENABLED"
        static let remoteSummarySync = "FORMA_HEALTH_SUMMARY_REMOTE_SYNC_ENABLED"
        static let remoteSummarySyncLegacy = "FITPILOT_HEALTH_SUMMARY_REMOTE_SYNC_ENABLED"
        static let pipelineAnalytics = "FORMA_HEALTH_INTELLIGENCE_PIPELINE_ANALYTICS_ENABLED"
        static let pipelineAnalyticsLegacy = "FITPILOT_HEALTH_INTELLIGENCE_PIPELINE_ANALYTICS_ENABLED"
        static let todayDebugFetch = "FORMA_HEALTH_INTELLIGENCE_TODAY_FETCH_ENABLED"
        static let todayDebugFetchLegacy = "FITPILOT_HEALTH_INTELLIGENCE_TODAY_FETCH_ENABLED"
        static let journeyDebugFetch = "FORMA_HEALTH_INTELLIGENCE_JOURNEY_FETCH_ENABLED"
        static let journeyDebugFetchLegacy = "FITPILOT_HEALTH_INTELLIGENCE_JOURNEY_FETCH_ENABLED"
        static let planDebugFetch = "FORMA_HEALTH_INTELLIGENCE_PLAN_FETCH_ENABLED"
        static let planDebugFetchLegacy = "FITPILOT_HEALTH_INTELLIGENCE_PLAN_FETCH_ENABLED"
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
        let flags = EnvironmentHealthIntelligenceFeatureFlags(environment: environment)
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
        testOverride ?? EnvironmentHealthIntelligenceFeatureFlags()
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

// MARK: - Environment-backed provider

struct EnvironmentHealthIntelligenceFeatureFlags: HealthIntelligenceFeatureFlagProviding {
    let environment: [String: String]

    init(environment: [String: String] = [:]) {
        self.environment = environment
    }

    var healthIntelligenceEnabled: Bool {
        flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.foundation,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.foundationLegacy,
            defaultEnabled: HealthIntelligenceFeatureFlags.Defaults.foundationEnabled
        )
    }

    var healthIntelligenceEnginesEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.engines,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.enginesLegacy,
            defaultEnabled: HealthIntelligenceFeatureFlags.Defaults.enginesEnabled
        )
    }

    var healthIntelligenceUIEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.ui,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.uiLegacy,
            defaultEnabled: HealthIntelligenceFeatureFlags.Defaults.uiEnabled
        )
    }

    var healthIntelligenceCoachContextEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.coachContext,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.coachContextLegacy,
            defaultEnabled: HealthIntelligenceFeatureFlags.Defaults.coachContextEnabled
        )
    }

    var healthIntelligenceWeeklyReviewEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.weeklyReview,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.weeklyReviewLegacy,
            defaultEnabled: HealthIntelligenceFeatureFlags.Defaults.weeklyReviewEnabled
        )
    }

    var isSyncEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.sync,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.syncLegacy,
            defaultEnabled: HealthIntelligenceFeatureFlags.Defaults.syncEnabled
        )
    }

    var healthSummaryRemoteSyncEnabled: Bool {
        guard healthIntelligenceEnabled, isSyncEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.remoteSummarySync,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.remoteSummarySyncLegacy,
            defaultEnabled: HealthIntelligenceFeatureFlags.Defaults.remoteSummarySyncEnabled
        )
    }

    var healthIntelligencePipelineAnalyticsEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.pipelineAnalytics,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.pipelineAnalyticsLegacy,
            defaultEnabled: HealthIntelligenceFeatureFlags.Defaults.pipelineAnalyticsEnabled
        )
    }

    var isRepositoryReadRoutingEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.repositoryReads,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.repositoryReadsLegacy,
            defaultEnabled: HealthIntelligenceFeatureFlags.Defaults.repositoryReadRoutingEnabled
        )
    }

    var isTodayModelDebugFetchEnabled: Bool {
        #if DEBUG
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.todayDebugFetch,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.todayDebugFetchLegacy,
            defaultEnabled: false
        )
        #else
        return false
        #endif
    }

    var isJourneyModelDebugFetchEnabled: Bool {
        #if DEBUG
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.journeyDebugFetch,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.journeyDebugFetchLegacy,
            defaultEnabled: false
        )
        #else
        return false
        #endif
    }

    var isPlanModelDebugFetchEnabled: Bool {
        #if DEBUG
        guard healthIntelligenceEnabled else { return false }
        return flag(
            primary: HealthIntelligenceFeatureFlags.EnvironmentKey.planDebugFetch,
            legacy: HealthIntelligenceFeatureFlags.EnvironmentKey.planDebugFetchLegacy,
            defaultEnabled: false
        )
        #else
        return false
        #endif
    }

    var shouldTodayModelLoadHealthIntelligence: Bool {
        guard healthIntelligenceEnginesEnabled else { return false }
        return healthIntelligenceUIEnabled || isTodayModelDebugFetchEnabled
    }

    var shouldCoachLoadHealthIntelligence: Bool {
        healthIntelligenceEnginesEnabled && healthIntelligenceCoachContextEnabled
    }

    var shouldJourneyModelLoadHealthIntelligence: Bool {
        guard healthIntelligenceEnginesEnabled else { return false }
        return healthIntelligenceUIEnabled || isJourneyModelDebugFetchEnabled
    }

    var shouldPlanModelLoadHealthIntelligence: Bool {
        guard healthIntelligenceEnginesEnabled else { return false }
        return healthIntelligenceUIEnabled || isPlanModelDebugFetchEnabled
    }

    private func flag(primary: String, legacy: String, defaultEnabled: Bool) -> Bool {
        FormaEnvironment.isTracingEnabled(
            primary: primary,
            legacy: legacy,
            defaultEnabled: defaultEnabled,
            environment: environment.isEmpty ? nil : environment
        )
    }
}

#if DEBUG
struct TestHealthIntelligenceFeatureFlags: HealthIntelligenceFeatureFlagProviding {
    var healthIntelligenceEnabled: Bool = true
    var healthIntelligenceEnginesEnabled: Bool = true
    var healthIntelligenceUIEnabled: Bool = false
    var healthIntelligenceCoachContextEnabled: Bool = false
    var healthIntelligenceWeeklyReviewEnabled: Bool = false
    var isSyncEnabled: Bool = true
    var healthSummaryRemoteSyncEnabled: Bool = false
    var healthIntelligencePipelineAnalyticsEnabled: Bool = true
    var isRepositoryReadRoutingEnabled: Bool = true
    var isTodayModelDebugFetchEnabled: Bool = false
    var isJourneyModelDebugFetchEnabled: Bool = false
    var isPlanModelDebugFetchEnabled: Bool = false

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
