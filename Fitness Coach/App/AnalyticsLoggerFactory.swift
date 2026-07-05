//
//  AnalyticsLoggerFactory.swift
//  Fitness Coach
//
//  Forma — Centralized analytics sink selection for AppContainer wiring.
//  Registry: Docs/Architecture/AnalyticsReadinessChecklist.md
//

import Foundation

/// Resolved analytics sinks for AppContainer dependency injection.
struct AppAnalyticsLoggers {
    let onboarding: any OnboardingAnalyticsLogging
    let today: any TodayAnalyticsLogging
    let plan: any PlanAnalyticsLogging
    let journey: any JourneyAnalyticsLogging
    let weeklyProgress: any WeeklyProgressAnalyticsLogging
    let publicEntry: any PublicEntryAnalyticsLogging
    let theme: any ThemeAnalyticsLogging
    let settings: any SettingsAnalyticsLogging
    let healthIntelligence: any HealthIntelligenceAnalyticsLogging
}

enum AnalyticsLoggerFactory {

    // MARK: - App container

    static func makeAppLoggers(
        onboarding: (any OnboardingAnalyticsLogging)? = nil,
        today: (any TodayAnalyticsLogging)? = nil,
        plan: (any PlanAnalyticsLogging)? = nil,
        journey: (any JourneyAnalyticsLogging)? = nil,
        weeklyProgress: (any WeeklyProgressAnalyticsLogging)? = nil,
        publicEntry: (any PublicEntryAnalyticsLogging)? = nil,
        theme: (any ThemeAnalyticsLogging)? = nil,
        settings: (any SettingsAnalyticsLogging)? = nil,
        healthIntelligence: (any HealthIntelligenceAnalyticsLogging)? = nil
    ) -> AppAnalyticsLoggers {
        AppAnalyticsLoggers(
            onboarding: resolve(onboarding, osLog: OSLogOnboardingAnalyticsLogger(), noOp: NoOpOnboardingAnalyticsLogger()),
            today: resolve(today, osLog: OSLogTodayAnalyticsLogger(), noOp: NoOpTodayAnalyticsLogger()),
            plan: resolve(plan, osLog: OSLogPlanAnalyticsLogger(), noOp: NoOpPlanAnalyticsLogger()),
            journey: resolve(journey, osLog: OSLogJourneyAnalyticsLogger(), noOp: NoOpJourneyAnalyticsLogger()),
            weeklyProgress: resolve(
                weeklyProgress,
                osLog: OSLogWeeklyProgressAnalyticsLogger(),
                noOp: NoOpWeeklyProgressAnalyticsLogger()
            ),
            publicEntry: resolve(
                publicEntry,
                osLog: OSLogPublicEntryAnalyticsLogger(),
                noOp: NoOpPublicEntryAnalyticsLogger()
            ),
            theme: resolve(theme, osLog: OSLogThemeAnalyticsLogger(), noOp: NoOpThemeAnalyticsLogger()),
            settings: resolve(settings, osLog: OSLogSettingsAnalyticsLogger(), noOp: NoOpSettingsAnalyticsLogger()),
            healthIntelligence: resolve(
                healthIntelligence,
                osLog: OSLogHealthIntelligenceAnalyticsLogger(),
                noOp: NoOpHealthIntelligenceAnalyticsLogger()
            )
        )
    }

    // MARK: - Coach (not AppContainer-wired)

    static func coach(_ override: (any CoachAnalyticsLogging)? = nil) -> any CoachAnalyticsLogging {
        if let override { return override }
        #if DEBUG
        return OSLogCoachAnalyticsLogger()
        #else
        return NoOpCoachAnalyticsLogger()
        #endif
    }

    // MARK: - Sink selection

    static func resolve<L>(
        _ override: L?,
        osLog: @autoclosure () -> L,
        noOp: @autoclosure () -> L
    ) -> L {
        if let override { return override }
        #if DEBUG
        return osLog()
        #else
        return noOp()
        #endif
    }
}
