//
//  NoOpSettingsAnalyticsLogger.swift
//  Fitness Coach
//

import Foundation

struct NoOpSettingsAnalyticsLogger: SettingsAnalyticsLogging {
    func log(_ event: SettingsAnalyticsEvent, properties: SettingsAnalyticsProperties) {}
}
