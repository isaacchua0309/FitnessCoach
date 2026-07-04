//
//  TodayQuickActionKind.swift
//  Fitness Coach
//
//  Forma — Fast-log quick actions shown on Today (meal + optional scan).
//

import Foundation

enum TodayQuickActionKind: String, Equatable, Sendable {
    case scanFood
    case logMeal
}
