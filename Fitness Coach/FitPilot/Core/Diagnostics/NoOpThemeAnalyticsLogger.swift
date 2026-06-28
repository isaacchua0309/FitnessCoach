//
//  NoOpThemeAnalyticsLogger.swift
//  Fitness Coach
//

import Foundation

struct NoOpThemeAnalyticsLogger: ThemeAnalyticsLogging {
    func log(_ event: ThemeAnalyticsEvent, properties: ThemeAnalyticsProperties) {}
}
