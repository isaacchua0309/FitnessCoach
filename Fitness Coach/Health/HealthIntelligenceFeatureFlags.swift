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
}
