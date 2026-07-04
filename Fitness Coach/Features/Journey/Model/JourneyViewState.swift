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
    case pendingAccountRestore(message: String)
    case error(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}
