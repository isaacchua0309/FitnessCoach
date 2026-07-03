//
//  CoachHealthGuidanceFormatter.swift
//  Fitness Coach
//
//  Deterministic workout/recovery-aware Coach copy derived from Health Intelligence.
//

import Foundation

enum CoachHealthGuidanceFormatter {

    static func knowsWorkoutStatus(from health: CoachHealthIntelligenceContext?) -> Bool {
        guard let health else { return false }
        return health.workoutCompletedToday
            || health.healthDataConfidenceLabel != "Limited estimate"
    }

    static func dailyHealthInsight(from health: CoachHealthIntelligenceContext?) -> String? {
        guard let health else { return nil }

        if health.recoveryStatus == RecoveryStatus.low.rawValue {
            return "Recovery looks limited today — lighter movement may fit better."
        }

        if health.workoutCompletedToday {
            if let demand = health.workoutDemand, demand != WorkoutDemand.unknown.rawValue {
                return "Today's \(demand)-demand workout is logged — prioritize protein and hydration."
            }
            return "Today's workout is logged — prioritize protein and hydration."
        }

        if health.trainingLoadStatus.hasPrefix("high") {
            return "Recent training load looks elevated — steady pacing may help."
        }

        if health.recoveryStatus == RecoveryStatus.ready.rawValue,
           health.missingSignals.isEmpty {
            return "Recovery looks supportive for your usual plan today."
        }

        return nil
    }

    static func mealAdviceOpening(from health: CoachHealthIntelligenceContext?) -> String? {
        guard let health else { return nil }

        if health.workoutCompletedToday {
            if let demand = health.workoutDemand, demand != WorkoutDemand.unknown.rawValue {
                return "After today's \(demand)-demand workout, prioritize protein and rehydrate."
            }
            return "After today's workout, prioritize protein and rehydrate."
        }

        if health.recoveryStatus == RecoveryStatus.low.rawValue {
            return "Recovery looks limited today — favor steady, protein-forward meals over heavy restriction."
        }

        return nil
    }

    static func mealAdviceSupplementLines(from health: CoachHealthIntelligenceContext?) -> [String] {
        guard let health else { return [] }

        var lines: [String] = []

        if let advice = health.adaptiveNutritionAdvice,
           !advice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(advice)
        }

        if let protein = health.proteinRecommendation, protein > 0 {
            lines.append("Aim for about \(protein)g protein across your next meals.")
        }

        if let hydration = health.hydrationRecommendationMl, hydration > 0 {
            lines.append("Add about \(PlanDisplayFormatter.formatGroupedInteger(hydration))ml extra water today.")
        }

        return deduplicated(lines)
    }

    static func workoutAdvice(
        from health: CoachHealthIntelligenceContext?,
        hasWorkoutToday: Bool
    ) -> String {
        guard let health else {
            return fallbackWorkoutAdvice(hasWorkoutToday: hasWorkoutToday)
        }

        if hasWorkoutToday {
            if health.recoveryStatus == RecoveryStatus.low.rawValue {
                return "You already logged a workout today and recovery looks limited. Keep the rest of the day lighter and prioritize fueling and hydration."
            }
            return "You already logged a workout today. Focus on recovery, protein, and hydration rather than adding more hard training."
        }

        let loadNote = trainingLoadNote(from: health.trainingLoadStatus)

        switch health.recoveryStatus {
        case RecoveryStatus.low.rawValue:
            return "Recovery looks limited today.\(loadNote) A lighter session, mobility work, or an extra rest day may be smarter than pushing hard."
        case RecoveryStatus.moderate.rawValue:
            return "Recovery looks moderate today.\(loadNote) You can train if you feel good — keep intensity controlled and fuel afterward."
        case RecoveryStatus.ready.rawValue:
            return "Recovery looks supportive today.\(loadNote) You're clear to train as planned if you feel ready."
        default:
            if health.missingSignals.isEmpty {
                return "Available recovery signals look mixed.\(loadNote) Train based on how you feel and keep effort moderate."
            }
            return fallbackWorkoutAdvice(hasWorkoutToday: hasWorkoutToday)
        }
    }

    static func removeRedundantWorkoutQuestions(
        from message: String,
        knowsWorkoutStatus: Bool
    ) -> String {
        guard knowsWorkoutStatus else { return message }

        let redundantPhrases = [
            "did you work out today?",
            "have you worked out today?",
            "did you workout today?",
            "have you trained today?",
            "did you train today?"
        ]

        var result = message
        for phrase in redundantPhrases {
            result = result.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
        }

        return result
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func appendUniqueLines(to message: String, lines: [String]) -> String {
        let existing = message.lowercased()
        let additions = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            return !existing.contains(trimmed.lowercased())
        }

        guard !additions.isEmpty else { return message }
        return ([message] + additions).joined(separator: " ")
    }

    // MARK: - Private

    private static func fallbackWorkoutAdvice(hasWorkoutToday: Bool) -> String {
        if hasWorkoutToday {
            return "You already logged a workout today. Prioritize recovery and nutrition for the rest of the day."
        }
        return "I don't have enough synced health signals to judge recovery. Train based on how you feel, stay hydrated, and fuel steadily."
    }

    private static func trainingLoadNote(from status: String) -> String {
        if status.hasPrefix("high") {
            return " Recent training load looks elevated."
        }
        if status.hasPrefix("low") {
            return " Recent training load looks manageable."
        }
        if status.hasPrefix("normal") {
            return " Training load looks normal for your recent history."
        }
        return ""
    }

    private static func deduplicated(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        return lines.filter { line in
            let key = line.lowercased()
            guard !key.isEmpty else { return false }
            return seen.insert(key).inserted
        }
    }
}
