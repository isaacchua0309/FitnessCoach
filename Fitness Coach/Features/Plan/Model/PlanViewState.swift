//
//  PlanViewState.swift
//  Fitness Coach
//
//  FitPilot AI — Screen-level state for Profile.
//

import Foundation

enum PlanViewState: Equatable {
    case loading
    case loaded(PlanDashboardState)
    case empty
    case error(String)
}
