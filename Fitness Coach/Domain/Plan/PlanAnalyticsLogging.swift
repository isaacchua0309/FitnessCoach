//
//  PlanAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Plan analytics events and safe property bag.
//

import Foundation

enum PlanAnalyticsEvent: String, Sendable {
    case adjustPlanStarted = "plan_adjust_plan_started"
}

struct PlanAnalyticsProperties: Sendable {
    var entryPoint: String?
    var initialStep: Int?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let entryPoint { parameters["entryPoint"] = entryPoint }
        if let initialStep { parameters["initialStep"] = String(initialStep) }
        return parameters
    }
}

protocol PlanAnalyticsLogging: Sendable {
    func log(_ event: PlanAnalyticsEvent, properties: PlanAnalyticsProperties)
}

enum PlanAdjustPlanEntryPoint {
    static let dashboard = "plan_dashboard"
    static let activityAssumptions = "plan_activity_assumptions"
}
