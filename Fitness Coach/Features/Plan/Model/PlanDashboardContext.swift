//
//  PlanDashboardContext.swift
//  Fitness Coach
//
//  Forma — Fetch bundle for Plan strategy builders.
//

import Foundation

struct PlanDashboardContext: Equatable, Sendable {
    var profile: UserProfile
    var weekLogs: [DailyLog]
    var allWeights: [WeightEntry]
    var integrationState: TrainingIntegrationState
    var dataSource: TrainingDataSource
    var asOf: Date
    var calendar: Calendar

    static func profileOnly(
        profile: UserProfile,
        integrationState: TrainingIntegrationState = .notConnected,
        dataSource: TrainingDataSource = .appleHealth,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> PlanDashboardContext {
        PlanDashboardContext(
            profile: profile,
            weekLogs: [],
            allWeights: [],
            integrationState: integrationState,
            dataSource: dataSource,
            asOf: referenceDate,
            calendar: calendar
        )
    }
}
