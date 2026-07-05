//
//  FakeAnalyticsLogger.swift
//  Fitness CoachTests
//
//  Factory for in-memory analytics loggers (no Firebase). Prefer these over ad-hoc mocks.
//

import Foundation
@testable import Fitness_Coach

enum FakeAnalyticsLogger {

    static func onboarding() -> CapturingOnboardingAnalyticsLogger {
        CapturingOnboardingAnalyticsLogger()
    }

    static func today() -> CapturingTodayAnalyticsLogger {
        CapturingTodayAnalyticsLogger()
    }

    static func plan() -> CapturingPlanAnalyticsLogger {
        CapturingPlanAnalyticsLogger()
    }

    static func journey() -> CapturingJourneyAnalyticsLogger {
        CapturingJourneyAnalyticsLogger()
    }

    static func coach() -> CapturingCoachAnalyticsLogger {
        CapturingCoachAnalyticsLogger()
    }

    static func settings() -> CapturingSettingsAnalyticsLogger {
        CapturingSettingsAnalyticsLogger()
    }

    static func theme() -> CapturingThemeAnalyticsLogger {
        CapturingThemeAnalyticsLogger()
    }

    static func publicEntry() -> CapturingPublicEntryAnalyticsLogger {
        CapturingPublicEntryAnalyticsLogger()
    }

    static func healthIntelligence() -> CapturingHealthIntelligenceAnalyticsLogger {
        CapturingHealthIntelligenceAnalyticsLogger()
    }
}
