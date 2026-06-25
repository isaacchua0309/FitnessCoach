//
//  TrainingViewState.swift
//  Fitness Coach
//
//  FitPilot AI — Screen-level state for Training.
//

import Foundation

enum TrainingViewState: Equatable {
    case loading
    case loaded(TrainingDashboardState)
    case empty
    case error(String)
}
