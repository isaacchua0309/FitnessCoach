//
//  NoOpHealthIntelligenceAnalyticsLogger.swift
//  Fitness Coach
//

import Foundation

struct NoOpHealthIntelligenceAnalyticsLogger: HealthIntelligenceAnalyticsLogging {
    func log(_ event: HealthIntelligenceAnalyticsEvent, properties: HealthIntelligenceAnalyticsProperties) {}
}
