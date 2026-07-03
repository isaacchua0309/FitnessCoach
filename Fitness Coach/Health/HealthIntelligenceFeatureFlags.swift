//
//  HealthIntelligenceFeatureFlags.swift
//  Fitness Coach
//
//  Forma — Temporary rollout flags for Health Intelligence foundation.
//

import Foundation

enum HealthIntelligenceFeatureFlags {

    /// Master switch for Health Intelligence foundation wiring (repository, sync, cache).
    ///
    /// Defaults to `true` so internal sync/cache can run without exposing new UI.
    /// Set `FORMA_HEALTH_INTELLIGENCE_ENABLED=0` to disable the entire foundation.
    static var healthIntelligenceEnabled: Bool {
        FormaEnvironment.isTracingEnabled(
            primary: "FORMA_HEALTH_INTELLIGENCE_ENABLED",
            legacy: "FITPILOT_HEALTH_INTELLIGENCE_ENABLED",
            defaultEnabled: true
        )
    }

    /// When `false` (default), no Health Intelligence UI surfaces are shown.
    static var isUIEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return FormaEnvironment.isTracingEnabled(
            primary: "FORMA_HEALTH_INTELLIGENCE_UI_ENABLED",
            legacy: "FITPILOT_HEALTH_INTELLIGENCE_UI_ENABLED",
            defaultEnabled: false
        )
    }

    /// Internal background sync and local cache refresh.
    ///
    /// Defaults to `true` when the foundation is enabled.
    static var isSyncEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return FormaEnvironment.isTracingEnabled(
            primary: "FORMA_HEALTH_INTELLIGENCE_SYNC_ENABLED",
            legacy: "FITPILOT_HEALTH_INTELLIGENCE_SYNC_ENABLED",
            defaultEnabled: true
        )
    }

    /// Routes legacy `HealthActivityQueryService` reads through `HealthDataRepository`
    /// while preserving existing UI behavior.
    static var isRepositoryReadRoutingEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return FormaEnvironment.isTracingEnabled(
            primary: "FORMA_HEALTH_INTELLIGENCE_REPOSITORY_READS_ENABLED",
            legacy: "FITPILOT_HEALTH_INTELLIGENCE_REPOSITORY_READS_ENABLED",
            defaultEnabled: true
        )
    }

    /// Phase 6–10 engine orchestration and internal snapshot composition.
    ///
    /// Defaults to `true` when the foundation is enabled so snapshots can be composed
    /// and cached without exposing new UI. Set `FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED=0`
    /// to disable engine wiring side effects.
    static var healthIntelligenceEnginesEnabled: Bool {
        guard healthIntelligenceEnabled else { return false }
        return FormaEnvironment.isTracingEnabled(
            primary: "FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED",
            legacy: "FITPILOT_HEALTH_INTELLIGENCE_ENGINES_ENABLED",
            defaultEnabled: true
        )
    }

    /// DEBUG-only: allows TodayModel to compose snapshots when UI is disabled (diagnostics).
    static var isTodayModelDebugFetchEnabled: Bool {
        #if DEBUG
        guard healthIntelligenceEnabled else { return false }
        return FormaEnvironment.isTracingEnabled(
            primary: "FORMA_HEALTH_INTELLIGENCE_TODAY_FETCH_ENABLED",
            legacy: "FITPILOT_HEALTH_INTELLIGENCE_TODAY_FETCH_ENABLED",
            defaultEnabled: false
        )
        #else
        return false
        #endif
    }

    /// Whether TodayModel should load Health Intelligence snapshots on refresh.
    static var shouldTodayModelLoadHealthIntelligence: Bool {
        guard healthIntelligenceEnginesEnabled else { return false }
        return isUIEnabled || isTodayModelDebugFetchEnabled
    }

    /// Whether Coach should compose Health Intelligence context for AI prompts.
    ///
    /// Enabled when engines are on so Coach can use cached snapshots without requiring HI UI.
    static var shouldCoachLoadHealthIntelligence: Bool {
        healthIntelligenceEnginesEnabled
    }

    /// DEBUG-only: allows JourneyModel to compose snapshots when UI is disabled (diagnostics).
    static var isJourneyModelDebugFetchEnabled: Bool {
        #if DEBUG
        guard healthIntelligenceEnabled else { return false }
        return FormaEnvironment.isTracingEnabled(
            primary: "FORMA_HEALTH_INTELLIGENCE_JOURNEY_FETCH_ENABLED",
            legacy: "FITPILOT_HEALTH_INTELLIGENCE_JOURNEY_FETCH_ENABLED",
            defaultEnabled: false
        )
        #else
        return false
        #endif
    }

    /// Whether JourneyModel should load Health Intelligence on refresh.
    static var shouldJourneyModelLoadHealthIntelligence: Bool {
        guard healthIntelligenceEnginesEnabled else { return false }
        return isUIEnabled || isJourneyModelDebugFetchEnabled
    }

    /// DEBUG-only: allows PlanModel to compose snapshots when UI is disabled (diagnostics).
    static var isPlanModelDebugFetchEnabled: Bool {
        #if DEBUG
        guard healthIntelligenceEnabled else { return false }
        return FormaEnvironment.isTracingEnabled(
            primary: "FORMA_HEALTH_INTELLIGENCE_PLAN_FETCH_ENABLED",
            legacy: "FITPILOT_HEALTH_INTELLIGENCE_PLAN_FETCH_ENABLED",
            defaultEnabled: false
        )
        #else
        return false
        #endif
    }

    /// Whether PlanModel should load Health Intelligence on refresh.
    static var shouldPlanModelLoadHealthIntelligence: Bool {
        guard healthIntelligenceEnginesEnabled else { return false }
        return isUIEnabled || isPlanModelDebugFetchEnabled
    }
}
