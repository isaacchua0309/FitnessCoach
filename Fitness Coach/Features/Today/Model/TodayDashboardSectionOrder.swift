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
        .nextBestAction,
        .quickActions,
        .meals,
        .macroHydration,
        .activity,
        .dailyVictory,
        .smartCoach,
        .endOfDayWrapUp
    ]
}

enum TodayDashboardSection: String, CaseIterable, Equatable {
    case header
    case missionHero
    case nextBestAction
    case quickActions
    case meals
    case macroHydration
    case activity
    case dailyVictory
    case smartCoach
    case endOfDayWrapUp
}
