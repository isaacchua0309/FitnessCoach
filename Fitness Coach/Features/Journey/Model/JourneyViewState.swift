//
//  JourneyViewState.swift
//  Fitness Coach
//
//  FitPilot AI — Screen-level state for the Progress feature.
//

import Foundation

enum JourneyViewState: Equatable {
    case loading
    case loaded(JourneyDashboardState)
    case empty
    case error(String)
}
