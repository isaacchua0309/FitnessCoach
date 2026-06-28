//
//  TodayAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Today analytics events and safe property bag.
//

import Foundation

enum TodayAnalyticsEvent: String, Sendable {
    case nextActionCTATapped = "today_next_action_cta_tapped"
    case quickActionTapped = "today_quick_action_tapped"
}

struct TodayAnalyticsProperties: Sendable {
    var reason: String?
    var cta: String?
    var route: String?
    var action: String?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let reason { parameters["reason"] = reason }
        if let cta { parameters["cta"] = cta }
        if let route { parameters["route"] = route }
        if let action { parameters["action"] = action }
        return parameters
    }
}

protocol TodayAnalyticsLogging: Sendable {
    func log(_ event: TodayAnalyticsEvent, properties: TodayAnalyticsProperties)
}
