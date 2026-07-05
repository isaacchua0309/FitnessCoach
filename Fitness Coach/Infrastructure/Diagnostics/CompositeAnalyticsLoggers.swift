//
//  CompositeAnalyticsLoggers.swift
//  Fitness Coach
//
//  Forma — Fan-out analytics sinks for DEBUG + future production adapters.
//

import Foundation

struct CompositeOnboardingAnalyticsLogger: OnboardingAnalyticsLogging {
    let loggers: [any OnboardingAnalyticsLogging]

    func log(_ event: OnboardingAnalyticsEvent, properties: OnboardingAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}

struct CompositeTodayAnalyticsLogger: TodayAnalyticsLogging {
    let loggers: [any TodayAnalyticsLogging]

    func log(_ event: TodayAnalyticsEvent, properties: TodayAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}

struct CompositePlanAnalyticsLogger: PlanAnalyticsLogging {
    let loggers: [any PlanAnalyticsLogging]

    func log(_ event: PlanAnalyticsEvent, properties: PlanAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}

struct CompositeJourneyAnalyticsLogger: JourneyAnalyticsLogging {
    let loggers: [any JourneyAnalyticsLogging]

    func log(_ event: JourneyAnalyticsEvent, properties: JourneyAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}

struct CompositeWeeklyProgressAnalyticsLogger: WeeklyProgressAnalyticsLogging {
    let loggers: [any WeeklyProgressAnalyticsLogging]

    func log(_ event: WeeklyProgressAnalyticsEvent, properties: WeeklyProgressAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}

struct CompositePublicEntryAnalyticsLogger: PublicEntryAnalyticsLogging {
    let loggers: [any PublicEntryAnalyticsLogging]

    func log(_ event: PublicEntryAnalyticsEvent, properties: PublicEntryAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}

struct CompositeThemeAnalyticsLogger: ThemeAnalyticsLogging {
    let loggers: [any ThemeAnalyticsLogging]

    func log(_ event: ThemeAnalyticsEvent, properties: ThemeAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}

struct CompositeSettingsAnalyticsLogger: SettingsAnalyticsLogging {
    let loggers: [any SettingsAnalyticsLogging]

    func log(_ event: SettingsAnalyticsEvent, properties: SettingsAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}

struct CompositeHealthIntelligenceAnalyticsLogger: HealthIntelligenceAnalyticsLogging {
    let loggers: [any HealthIntelligenceAnalyticsLogging]

    func log(_ event: HealthIntelligenceAnalyticsEvent, properties: HealthIntelligenceAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}

struct CompositeCoachAnalyticsLogger: CoachAnalyticsLogging {
    let loggers: [any CoachAnalyticsLogging]

    func log(_ event: CoachAnalyticsEvent, properties: CoachAnalyticsProperties) {
        for logger in loggers {
            logger.log(event, properties: properties)
        }
    }
}
