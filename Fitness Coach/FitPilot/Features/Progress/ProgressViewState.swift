//
//  ProgressViewState.swift
//  Fitness Coach
//
//  FitPilot AI — Screen-level state for the Progress feature.
//

import Foundation

enum ProgressViewState: Equatable {
    case loading
    case loaded(ProgressDashboardState)
    case empty
    case error(String)
}
