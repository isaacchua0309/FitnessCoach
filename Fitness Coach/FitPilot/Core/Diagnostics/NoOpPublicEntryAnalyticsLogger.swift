//
//  NoOpPublicEntryAnalyticsLogger.swift
//  Fitness Coach
//

import Foundation

struct NoOpPublicEntryAnalyticsLogger: PublicEntryAnalyticsLogging {
    func log(_ event: PublicEntryAnalyticsEvent, properties: PublicEntryAnalyticsProperties) {}
}
