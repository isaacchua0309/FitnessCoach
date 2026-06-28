//
//  OSLogPlanAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for Plan analytics events.
//

import Foundation
import OSLog

struct OSLogPlanAnalyticsLogger: PlanAnalyticsLogging {

    func log(_ event: PlanAnalyticsEvent, properties: PlanAnalyticsProperties) {
        #if DEBUG
        TodayAnalyticsDebugLogger.event(event.rawValue, fields: properties.asParameters())
        #endif
    }
}
