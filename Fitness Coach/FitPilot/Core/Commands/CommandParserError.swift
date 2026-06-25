//
//  CommandParserError.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight reasons surfaced by the local command parser.
//
//  These are not thrown for normal parse failures; they are reusable reason
//  strings carried inside CommandParseResult cases.
//

import Foundation

enum CommandParserError: Equatable, Sendable {
    case nonPositiveWeight
    case nonPositiveWater
    case waterTooLarge(maxMl: Int)
    case nonPositiveSteps
    case negativeCalories
    case negativeMacro
    case emptyFoodName
    case ambiguousNumbers
    case vagueFood

    var reason: String {
        switch self {
        case .nonPositiveWeight:
            return "Weight must be greater than zero."
        case .nonPositiveWater:
            return "Water amount must be greater than zero."
        case .waterTooLarge(let maxMl):
            return "A single water entry above \(maxMl)ml is not supported."
        case .nonPositiveSteps:
            return "Step count must be greater than zero."
        case .negativeCalories:
            return "Calories cannot be negative."
        case .negativeMacro:
            return "Macros cannot be negative."
        case .emptyFoodName:
            return "A food name is required."
        case .ambiguousNumbers:
            return "Too many numbers to interpret this command confidently."
        case .vagueFood:
            return "Food estimate requires AI interpretation."
        }
    }
}
