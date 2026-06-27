//
//  NoOpOnboardingAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — Production-safe no-op onboarding analytics sink.
//

import Foundation

struct NoOpOnboardingAnalyticsLogger: OnboardingAnalyticsLogging {
    func log(_ event: OnboardingAnalyticsEvent, properties: OnboardingAnalyticsProperties) {}
}
