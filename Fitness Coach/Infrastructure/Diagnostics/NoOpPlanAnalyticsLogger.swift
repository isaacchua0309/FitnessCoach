//
//  NoOpPlanAnalyticsLogger.swift
//  Fitness Coach
//

import Foundation

struct NoOpPlanAnalyticsLogger: PlanAnalyticsLogging {
    func log(_ event: PlanAnalyticsEvent, properties: PlanAnalyticsProperties) {}
}
