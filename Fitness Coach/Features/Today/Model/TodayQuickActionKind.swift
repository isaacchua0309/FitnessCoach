//
//  TodayQuickActionKind.swift
//  Fitness Coach
//
//  Forma — Quick log actions on Today.
//

import Foundation

enum TodayQuickActionKind: String, Equatable, CaseIterable, Sendable {
    case scanFood
    case logMeal
    case manualEntry
    case addWater
    case logWeight
    case logWorkout
}

enum TodayQuickActionPresentation: Equatable, Sendable {
    case primary
    case secondary
}

struct TodayQuickActionMenuItem: Equatable, Identifiable, Sendable {
    var kind: TodayQuickActionKind
    var isEnabled: Bool
    var disabledReason: String?
    var presentation: TodayQuickActionPresentation

    var id: String { kind.rawValue }

    init(
        kind: TodayQuickActionKind,
        isEnabled: Bool,
        disabledReason: String?,
        presentation: TodayQuickActionPresentation = .primary
    ) {
        self.kind = kind
        self.isEnabled = isEnabled
        self.disabledReason = disabledReason
        self.presentation = presentation
    }
}
