//
//  CoachHealthContextStatus.swift
//  Fitness Coach
//
//  Forma — Coach-safe health context availability for AI prompt injection.
//

import Foundation

enum CoachHealthContextStatus: String, Equatable, Sendable, Codable, CaseIterable {
    case available
    case partial
    case unavailable
    case stale
}

enum CoachHealthContextInstruction {
    static let doNotAssumeMissingData = """
    Do not assume missing health data. If a signal is unavailable, say it is unavailable or ask the user. \
    Do not infer low activity from missing step data. Do not claim the user did not work out when workout data \
    is unavailable—say workout data is unavailable instead. When recovery confidence is limited, describe the \
    estimate as limited rather than definitive. Mention stale health data only when it is relevant to the \
    user's question. When the user asks about an unavailable signal, explain how to connect or share it from \
    Apple Health in Forma Settings.
    """
}

extension HealthInsightKind {

    var coachPromptLabel: String {
        switch self {
        case .steps:
            return "steps"
        case .activeEnergy:
            return "active energy"
        case .exerciseMinutes:
            return "exercise minutes"
        case .workouts:
            return "workouts"
        case .sleep:
            return "sleep"
        case .restingHeartRate:
            return "resting heart rate"
        case .hrv:
            return "HRV"
        case .weight:
            return "weight"
        case .recoveryBaseline:
            return "recovery baseline"
        case .remoteSync:
            return "remote sync"
        }
    }
}
