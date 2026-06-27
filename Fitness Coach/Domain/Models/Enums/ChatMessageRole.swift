//
//  ChatMessageRole.swift
//  Fitness Coach
//
//  FitPilot AI — Core domain enums.
//

import Foundation

enum ChatMessageRole: String, Codable, CaseIterable, Equatable, Sendable {
    case user
    case assistant
    case system
}
