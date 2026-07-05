//
//  AppContainer+AnalyticsDependencies.swift
//  Fitness Coach
//
//  Analytics logger construction for AppContainer.
//  See Docs/Architecture/DependencyInjectionMap.md
//

import Foundation

// MARK: - Analytics dependencies

extension AppContainer {

    struct AnalyticsDependenciesBundle {
        let onboardingAnalyticsLogger: any OnboardingAnalyticsLogging
        let todayAnalyticsLogger: any TodayAnalyticsLogging
        let planAnalyticsLogger: any PlanAnalyticsLogging
        let journeyAnalyticsLogger: any JourneyAnalyticsLogging
        let weeklyProgressAnalyticsLogger: any WeeklyProgressAnalyticsLogging
        let publicEntryAnalyticsLogger: any PublicEntryAnalyticsLogging
        let themeAnalyticsLogger: any ThemeAnalyticsLogging
        let settingsAnalyticsLogger: any SettingsAnalyticsLogging
        let healthIntelligenceAnalyticsLogger: any HealthIntelligenceAnalyticsLogging
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
    ) -> AnalyticsDependenciesBundle {
        let loggers = AnalyticsLoggerFactory.makeAppLoggers(
            onboarding: onboardingAnalyticsLogger,
            today: todayAnalyticsLogger,
            plan: planAnalyticsLogger,
            journey: journeyAnalyticsLogger,
            weeklyProgress: weeklyProgressAnalyticsLogger,
            publicEntry: publicEntryAnalyticsLogger,
            theme: themeAnalyticsLogger,
            settings: settingsAnalyticsLogger,
            healthIntelligence: healthIntelligenceAnalyticsLogger
        )

        return AnalyticsDependenciesBundle(
            onboardingAnalyticsLogger: loggers.onboarding,
            todayAnalyticsLogger: loggers.today,
            planAnalyticsLogger: loggers.plan,
            journeyAnalyticsLogger: loggers.journey,
            weeklyProgressAnalyticsLogger: loggers.weeklyProgress,
            publicEntryAnalyticsLogger: loggers.publicEntry,
            themeAnalyticsLogger: loggers.theme,
            settingsAnalyticsLogger: loggers.settings,
            healthIntelligenceAnalyticsLogger: loggers.healthIntelligence
        )
    }
}
