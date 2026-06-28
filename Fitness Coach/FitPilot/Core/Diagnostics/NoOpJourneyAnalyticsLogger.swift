//
//  NoOpJourneyAnalyticsLogger.swift
//  Fitness Coach
//

import Foundation

struct NoOpJourneyAnalyticsLogger: JourneyAnalyticsLogging {
    func log(_ event: JourneyAnalyticsEvent, properties: JourneyAnalyticsProperties) {}
}
