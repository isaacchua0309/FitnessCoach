//
//  AnalyticsDependencies.swift
//  Fitness Coach
//
//  Typed analytics dependency bundle for AppContainer wiring.
//  Registry: Docs/Architecture/AnalyticsReadinessChecklist.md
//

import Foundation

/// Resolved analytics configuration and domain loggers for `AppContainer`.
struct AnalyticsDependencies {
    let configuration: FormaAnalyticsConfiguration

    let onboardingAnalyticsLogger: any OnboardingAnalyticsLogging
    let todayAnalyticsLogger: any TodayAnalyticsLogging
    let planAnalyticsLogger: any PlanAnalyticsLogging
    let journeyAnalyticsLogger: any JourneyAnalyticsLogging
    let weeklyProgressAnalyticsLogger: any WeeklyProgressAnalyticsLogging
    let publicEntryAnalyticsLogger: any PublicEntryAnalyticsLogging
    let themeAnalyticsLogger: any ThemeAnalyticsLogging
    let settingsAnalyticsLogger: any SettingsAnalyticsLogging
    let healthIntelligenceAnalyticsLogger: any HealthIntelligenceAnalyticsLogging

    /// Builds analytics dependencies via `AnalyticsLoggerFactory`.
    ///
    /// Injectable logger parameters support tests and previews without changing
    /// `AppContainer`'s public initializer surface.
    static func build(
        configuration: FormaAnalyticsConfiguration = .current,
        onboardingAnalyticsLogger: (any OnboardingAnalyticsLogging)? = nil,
        todayAnalyticsLogger: (any TodayAnalyticsLogging)? = nil,
        planAnalyticsLogger: (any PlanAnalyticsLogging)? = nil,
        journeyAnalyticsLogger: (any JourneyAnalyticsLogging)? = nil,
        weeklyProgressAnalyticsLogger: (any WeeklyProgressAnalyticsLogging)? = nil,
        publicEntryAnalyticsLogger: (any PublicEntryAnalyticsLogging)? = nil,
        themeAnalyticsLogger: (any ThemeAnalyticsLogging)? = nil,
        settingsAnalyticsLogger: (any SettingsAnalyticsLogging)? = nil,
        healthIntelligenceAnalyticsLogger: (any HealthIntelligenceAnalyticsLogging)? = nil
    ) -> AnalyticsDependencies {
        let loggers = AnalyticsLoggerFactory.makeAppLoggers(
            configuration: configuration,
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

        return AnalyticsDependencies(
            configuration: configuration,
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
