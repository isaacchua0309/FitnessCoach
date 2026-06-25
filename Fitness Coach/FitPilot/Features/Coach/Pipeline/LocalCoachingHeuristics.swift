//
//  LocalCoachingHeuristics.swift
//  Fitness Coach
//
//  FitPilot AI — cheap local coaching intent detection.
//

import Foundation

enum LocalCoachingKind: Equatable, Sendable {
    case mealNext
    case recovery
    case tomorrowFocus
}

struct CoachingRequest: Equatable, Sendable {
    var kind: LocalCoachingKind
    var originalText: String
}

struct LocalCoachingHeuristics {
    func request(for input: NormalizedInput) -> CoachingRequest? {
        let text = input.normalizedText

        if text.contains("tomorrow") || text.contains("focus on tomorrow") {
            return CoachingRequest(kind: .tomorrowFocus, originalText: input.trimmedText)
        }

        if text.contains("recover") || text.contains("recovery") {
            return CoachingRequest(kind: .recovery, originalText: input.trimmedText)
        }

        if text.contains("what should i eat")
            || text.contains("meal idea")
            || text.contains("eat next") {
            return CoachingRequest(kind: .mealNext, originalText: input.trimmedText)
        }

        return nil
    }
}
