//
//  NoOpTodayAnalyticsLogger.swift
//  Fitness Coach
//

import Foundation

struct NoOpTodayAnalyticsLogger: TodayAnalyticsLogging {
    func log(_ event: TodayAnalyticsEvent, properties: TodayAnalyticsProperties) {}
}
