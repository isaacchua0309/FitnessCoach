//
//  ProfileViewState.swift
//  Fitness Coach
//
//  FitPilot AI — Screen-level state for Profile.
//

import Foundation

enum ProfileViewState: Equatable {
    case loading
    case loaded(ProfileDashboardState)
    case empty
    case error(String)
}
