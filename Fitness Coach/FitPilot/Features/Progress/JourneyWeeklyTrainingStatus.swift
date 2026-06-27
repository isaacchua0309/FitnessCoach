//
//  JourneyWeeklyTrainingStatus.swift
//  Fitness Coach
//
//  Forma — Apple Health training display state for Journey (Stage 9).
//

import Foundation

enum JourneyWeeklyTrainingStatus: Equatable {
    case hidden
    case locked
    case connectedEmpty
    case connected(
        workoutDays: Int,
        averageCaloriesBurned: Int?,
        averageTrainingDurationMinutes: Int?
    )

    var isConnected: Bool {
        switch self {
        case .connected, .connectedEmpty:
            return true
        case .hidden, .locked:
            return false
        }
    }

    var showsWorkoutRow: Bool {
        switch self {
        case .hidden:
            return false
        case .locked, .connectedEmpty, .connected:
            return true
        }
    }

    var workoutDays: Int? {
        if case .connected(let days, _, _) = self { return days }
        return nil
    }

    var averageCaloriesBurned: Int? {
        if case .connected(_, let burned, _) = self { return burned }
        return nil
    }

    var averageTrainingDurationMinutes: Int? {
        if case .connected(_, _, let duration) = self { return duration }
        return nil
    }
}
