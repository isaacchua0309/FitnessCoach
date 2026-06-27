//
//  ActivityLevel.swift
//  Fitness Coach
//
//  FitPilot AI — Core domain enums.
//

import Foundation

enum ActivityLevel: String, Codable, CaseIterable, Equatable, Sendable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case athlete
}
