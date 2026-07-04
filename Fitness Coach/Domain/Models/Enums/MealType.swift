//
//  MealType.swift
//  Fitness Coach
//
//  FitPilot AI — Core domain enums.
//

import Foundation

enum MealType: String, Codable, CaseIterable, Equatable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
    case unknown

    /// Maps optional backend strings; treats empty and literal `"null"` as absent.
    static func fromOptionalRawValue(_ raw: String?) -> MealType? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed != "null" else { return nil }
        return MealType(rawValue: trimmed) ?? .unknown
    }
}
