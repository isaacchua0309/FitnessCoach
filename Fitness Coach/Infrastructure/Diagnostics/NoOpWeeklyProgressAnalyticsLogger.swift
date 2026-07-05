//
//  NoOpWeeklyProgressAnalyticsLogger.swift
//  Fitness Coach
//

import Foundation

struct NoOpWeeklyProgressAnalyticsLogger: WeeklyProgressAnalyticsLogging {
    func log(_ event: WeeklyProgressAnalyticsEvent, properties: WeeklyProgressAnalyticsProperties) {}
}
