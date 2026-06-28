//
//  TodayQuickActionKind.swift
//  Fitness Coach
//
//  Forma — Quick log actions available from the Today FAB menu.
//

import Foundation

enum TodayQuickActionKind: String, Equatable, CaseIterable, Sendable {
    case scanFood
    case manualEntry
    case addWater
    case logWeight
    case askCoach
}

struct TodayQuickActionMenuItem: Equatable, Identifiable, Sendable {
    var kind: TodayQuickActionKind
    var isEnabled: Bool
    var disabledReason: String?

    var id: String { kind.rawValue }
}
