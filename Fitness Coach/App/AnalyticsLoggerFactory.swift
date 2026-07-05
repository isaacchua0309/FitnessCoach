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
        configuration: FormaAnalyticsConfiguration = .current,
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
            onboarding: resolve(
                onboarding,
                configuration: configuration,
                debugSink: { OSLogOnboardingAnalyticsLogger() },
                noOpSink: { NoOpOnboardingAnalyticsLogger() },
                productionSink: { nil },
                composite: { CompositeOnboardingAnalyticsLogger(loggers: $0) }
            ),
            today: resolve(
                today,
                configuration: configuration,
                debugSink: { OSLogTodayAnalyticsLogger() },
                noOpSink: { NoOpTodayAnalyticsLogger() },
                productionSink: { nil },
                composite: { CompositeTodayAnalyticsLogger(loggers: $0) }
            ),
            plan: resolve(
                plan,
                configuration: configuration,
                debugSink: { OSLogPlanAnalyticsLogger() },
                noOpSink: { NoOpPlanAnalyticsLogger() },
                productionSink: { nil },
                composite: { CompositePlanAnalyticsLogger(loggers: $0) }
            ),
            journey: resolve(
                journey,
                configuration: configuration,
                debugSink: { OSLogJourneyAnalyticsLogger() },
                noOpSink: { NoOpJourneyAnalyticsLogger() },
                productionSink: { nil },
                composite: { CompositeJourneyAnalyticsLogger(loggers: $0) }
            ),
            weeklyProgress: resolve(
                weeklyProgress,
                configuration: configuration,
                debugSink: { OSLogWeeklyProgressAnalyticsLogger() },
                noOpSink: { NoOpWeeklyProgressAnalyticsLogger() },
                productionSink: { nil },
                composite: { CompositeWeeklyProgressAnalyticsLogger(loggers: $0) }
            ),
            publicEntry: resolve(
                publicEntry,
                configuration: configuration,
                debugSink: { OSLogPublicEntryAnalyticsLogger() },
                noOpSink: { NoOpPublicEntryAnalyticsLogger() },
                productionSink: { nil },
                composite: { CompositePublicEntryAnalyticsLogger(loggers: $0) }
            ),
            theme: resolve(
                theme,
                configuration: configuration,
                debugSink: { OSLogThemeAnalyticsLogger() },
                noOpSink: { NoOpThemeAnalyticsLogger() },
                productionSink: { nil },
                composite: { CompositeThemeAnalyticsLogger(loggers: $0) }
            ),
            settings: resolve(
                settings,
                configuration: configuration,
                debugSink: { OSLogSettingsAnalyticsLogger() },
                noOpSink: { NoOpSettingsAnalyticsLogger() },
                productionSink: { nil },
                composite: { CompositeSettingsAnalyticsLogger(loggers: $0) }
            ),
            healthIntelligence: resolve(
                healthIntelligence,
                configuration: configuration,
                debugSink: { OSLogHealthIntelligenceAnalyticsLogger() },
                noOpSink: { NoOpHealthIntelligenceAnalyticsLogger() },
                productionSink: { nil },
                composite: { CompositeHealthIntelligenceAnalyticsLogger(loggers: $0) }
            )
        )
    }

    // MARK: - Coach (not AppContainer-wired)

    static func coach(
        _ override: (any CoachAnalyticsLogging)? = nil,
        configuration: FormaAnalyticsConfiguration = .current
    ) -> any CoachAnalyticsLogging {
        resolve(
            override,
            configuration: configuration,
            debugSink: { coachDebugSink() },
            noOpSink: { NoOpCoachAnalyticsLogger() },
            productionSink: { nil },
            composite: { CompositeCoachAnalyticsLogger(loggers: $0) }
        )
    }

    // MARK: - Sink selection

    static func resolve<L>(
        _ override: L?,
        configuration: FormaAnalyticsConfiguration = .current,
        debugSink: () -> L,
        noOpSink: () -> L,
        productionSink: () -> L? = { nil },
        composite: ([L]) -> L
    ) -> L {
        if let override { return override }

        var sinks: [L] = []
        #if DEBUG
        sinks.append(debugSink())
        #endif
        if configuration.isProductionSinkEnabled, let production = productionSink() {
            sinks.append(production)
        }

        switch sinks.count {
        case 0:
            return noOpSink()
        case 1:
            return sinks[0]
        default:
            return composite(sinks)
        }
    }

    // MARK: - Private

    #if DEBUG
    private static func coachDebugSink() -> any CoachAnalyticsLogging {
        OSLogCoachAnalyticsLogger()
    }
    #else
    private static func coachDebugSink() -> any CoachAnalyticsLogging {
        NoOpCoachAnalyticsLogger()
    }
    #endif
}
