//
//  AppContainer+Construction.swift
//  Fitness Coach
//
//  Thin construction delegates for AppContainer init-time domain bundles.
//  See Docs/Architecture/DependencyInjectionMap.md
//

import Foundation
import SwiftData

extension AppContainer {

    // MARK: - Bundle typealiases (legacy construction names)

    typealias AuthDependenciesBundle = AuthDependencies
    typealias AnalyticsDependenciesBundle = AnalyticsDependencies
    typealias HealthBundle = HealthDependencies
    typealias PersistenceDependenciesBundle = PersistenceDependencies
    typealias HealthIntelligenceDependenciesBundle = HealthIntelligenceDependencies
    typealias CoachDependenciesBundle = CoachPlatformDependencies
    typealias AIBundle = AIDependencies
    typealias SyncDependenciesBundle = SyncDependencies
    typealias SettingsDependenciesBundle = SettingsDependencies
    typealias TodayDependenciesBundle = TodayDependencies

    // MARK: - Init-time factories

    static func buildAuthDependencies(
        inMemory: Bool,
        onboardingUserDefaults: UserDefaults?,
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration?
    ) -> AuthDependencies {
        AuthDependencies.build(
            inMemory: inMemory,
            onboardingUserDefaults: onboardingUserDefaults,
            onboardingRoutingConfiguration: onboardingRoutingConfiguration
        )
    }

    static func buildAnalyticsDependencies(
        onboardingAnalyticsLogger: (any OnboardingAnalyticsLogging)?,
        todayAnalyticsLogger: (any TodayAnalyticsLogging)?,
        planAnalyticsLogger: (any PlanAnalyticsLogging)?,
        journeyAnalyticsLogger: (any JourneyAnalyticsLogging)?,
        weeklyProgressAnalyticsLogger: (any WeeklyProgressAnalyticsLogging)?,
        publicEntryAnalyticsLogger: (any PublicEntryAnalyticsLogging)?,
        themeAnalyticsLogger: (any ThemeAnalyticsLogging)?,
        settingsAnalyticsLogger: (any SettingsAnalyticsLogging)?,
        healthIntelligenceAnalyticsLogger: (any HealthIntelligenceAnalyticsLogging)?
    ) -> AnalyticsDependencies {
        AnalyticsDependencies.build(
            onboardingAnalyticsLogger: onboardingAnalyticsLogger,
            todayAnalyticsLogger: todayAnalyticsLogger,
            planAnalyticsLogger: planAnalyticsLogger,
            journeyAnalyticsLogger: journeyAnalyticsLogger,
            weeklyProgressAnalyticsLogger: weeklyProgressAnalyticsLogger,
            publicEntryAnalyticsLogger: publicEntryAnalyticsLogger,
            themeAnalyticsLogger: themeAnalyticsLogger,
            settingsAnalyticsLogger: settingsAnalyticsLogger,
            healthIntelligenceAnalyticsLogger: healthIntelligenceAnalyticsLogger
        )
    }

    static func buildHealth(
        session: AuthDependenciesBundle,
        inMemory: Bool
    ) -> HealthDependencies {
        HealthDependencies.build(session: session, inMemory: inMemory)
    }

    static func buildPersistenceDependencies(
        session: AuthDependenciesBundle,
        inMemory: Bool,
        accountDataRemoteStore: (any AccountDataRemoteStore)?
    ) throws -> PersistenceDependencies {
        try PersistenceDependencies.build(
            session: session,
            inMemory: inMemory,
            accountDataRemoteStore: accountDataRemoteStore
        )
    }

    static func buildHealthIntelligenceDependencies(
        health: HealthBundle,
        persistence: PersistenceDependenciesBundle
    ) -> HealthIntelligenceDependencies {
        HealthIntelligenceDependencies.build(health: health, persistence: persistence)
    }

    static func buildCoachDependencies(
        session: AuthDependenciesBundle,
        persistence: PersistenceDependenciesBundle,
        health: HealthBundle
    ) -> CoachPlatformDependencies {
        CoachPlatformDependencies.build(
            session: session,
            persistence: persistence,
            health: health
        )
    }

    static func buildAI(
        session: AuthDependenciesBundle,
        inMemory: Bool
    ) -> AIDependencies {
        AIDependencies.build(session: session, inMemory: inMemory)
    }

    static func buildSyncDependencies(
        session: AuthDependenciesBundle,
        persistence: PersistenceDependenciesBundle,
        health: HealthBundle,
        inMemory: Bool
    ) -> SyncDependencies {
        SyncDependencies.build(
            session: session,
            persistence: persistence,
            health: health,
            inMemory: inMemory
        )
    }

    static func buildSettingsDependencies(
        analytics: AnalyticsDependenciesBundle
    ) -> SettingsDependencies {
        SettingsDependencies.build(analytics: analytics)
    }

    static func buildTodayDependencies(
        auth: AuthDependenciesBundle,
        persistence: PersistenceDependenciesBundle,
        health: HealthBundle,
        ai: AIBundle,
        refreshCenter: AppRefreshCenter
    ) -> TodayDependencies {
        TodayDependencies.build(
            auth: auth,
            persistence: persistence,
            health: health,
            ai: ai,
            refreshCenter: refreshCenter
        )
    }
}
