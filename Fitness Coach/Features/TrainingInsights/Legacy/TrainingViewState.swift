//
//  TrainingViewState.swift
//  Fitness Coach
//
//  FitPilot AI — Screen-level state for Training intelligence.
//

import Foundation

enum TrainingViewState: Equatable {
    case loading
    case loaded(TrainingDashboardState)
    case error(String)
}
