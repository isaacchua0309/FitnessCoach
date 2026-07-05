//
//  TodayDashboardSectionOrder.swift
//  Fitness Coach
//
//  Forma — Canonical Today dashboard section order.
//

import Foundation

/// Fixed section order for the Today read-only dashboard.
enum TodayDashboardSectionOrder {
    static let sections: [TodayDashboardSection] = [
        .header,
        .missionHero,
        .quickActions,
        .waterQuickLog,
        .meals,
        .macroHydration,
        .recovery,
        .activity,
        .appleHealthSetup,
        .yesterdayReview,
        .dailyVictory,
        .smartCoach,
        .endOfDayWrapUp
    ]
}

enum TodayDashboardSection: String, CaseIterable, Equatable {
    case header
    case missionHero
    case quickActions
    case waterQuickLog
    case meals
    case macroHydration
    case recovery
    case activity
    case appleHealthSetup
    case yesterdayReview
    case dailyVictory
    case smartCoach
    case endOfDayWrapUp
}
