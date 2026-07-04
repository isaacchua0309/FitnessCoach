//
//  CoachAIResponseContextAdapter.swift
//  Fitness Coach
//
//  Maps CoachContextPacketV2 into response-building hints without contradicting
//  structured context (confirmed timeline, today aggregates, missingData).
//

import Foundation

struct CoachResponseContextHints: Equatable, Sendable {
    var missingData: CoachMissingDataContext?
    var timelineEvents: [CoachTimelineContextEvent]
    var recentMeals: [CoachRecentMealContext]
    var steps: Int?
    var workoutsToday: Int?
    var primaryWorkoutTitle: String?
    var healthIntelligence: CoachHealthIntelligenceContext?

    init(
        missingData: CoachMissingDataContext? = nil,
        timelineEvents: [CoachTimelineContextEvent] = [],
        recentMeals: [CoachRecentMealContext] = [],
        steps: Int? = nil,
        workoutsToday: Int? = nil,
        primaryWorkoutTitle: String? = nil,
        healthIntelligence: CoachHealthIntelligenceContext? = nil
    ) {
        self.missingData = missingData
        self.timelineEvents = timelineEvents
        self.recentMeals = recentMeals
        self.steps = steps
        self.workoutsToday = workoutsToday
        self.primaryWorkoutTitle = primaryWorkoutTitle
        self.healthIntelligence = healthIntelligence
    }

    static func from(_ context: CoachContextPacketV2?) -> CoachResponseContextHints {
        guard let context else { return CoachResponseContextHints() }
        return CoachResponseContextHints(
            missingData: context.missingData,
            timelineEvents: context.timeline.recentEvents,
            recentMeals: context.recentMealsStructured,
            steps: context.today?.steps?.value,
            workoutsToday: context.training?.workoutsToday,
            primaryWorkoutTitle: context.training?.workouts.last?.title,
            healthIntelligence: context.healthIntelligence
        )
    }
}

enum CoachAIResponseContextAdapter {

    static func resolveFoodEstimateAttribution(
        fromPhotoAnalysis: Bool,
        usedClassifierMerge: Bool,
        matchedCommonFood: Bool,
        isLocalEstimate: Bool
    ) -> CoachTimelineEventSourceAttribution {
        if fromPhotoAnalysis { return .mealImage }
        if matchedCommonFood { return .commonFoodReference }
        if usedClassifierMerge { return .classifier }
        if isLocalEstimate { return .localParser }
        return .estimateFood
    }

    static func matchesCommonFoodReference(
        prompt: String,
        commonFoods: [CoachCommonFoodContext]
    ) -> Bool {
        let normalized = CommandParserUtilities.normalized(prompt)
        guard !normalized.isEmpty else { return false }

        if normalized.contains("same as usual") || normalized.contains("usual") {
            return !commonFoods.isEmpty
        }

        return commonFoods.contains { food in
            let name = (food.displayName ?? food.name)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !name.isEmpty else { return false }
            return normalized.contains(name)
        }
    }

    static func missingDataDisclaimer(
        _ missing: CoachMissingDataContext?,
        includeSteps: Bool = true,
        includeWorkouts: Bool = true
    ) -> String? {
        guard let missing, missing.hasAnyMissingSignals else { return nil }

        var parts: [String] = []
        if includeSteps, missing.stepsMissing || missing.stepsUnavailable {
            parts.append("Steps aren't available from Apple Health right now.")
        }
        if includeWorkouts,
           missing.workoutPermissionDeniedOrUnavailable || missing.workoutsUnavailable {
            parts.append("Workout data isn't available from Apple Health right now.")
        }
        if missing.sleepMissing || missing.sleepUnavailable {
            parts.append("Sleep data isn't available right now.")
        }
        if missing.hrvMissing || missing.hrvUnavailable {
            parts.append("Heart-rate variability isn't available right now.")
        }
        if missing.healthKitDenied || missing.healthKitUnavailable {
            parts.append("Some Apple Health signals are unavailable.")
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    static func appendMissingDataDisclaimer(
        to message: String,
        hints: CoachResponseContextHints?,
        includeSteps: Bool = true,
        includeWorkouts: Bool = true
    ) -> String {
        guard let disclaimer = missingDataDisclaimer(
            hints?.missingData,
            includeSteps: includeSteps,
            includeWorkouts: includeWorkouts
        ) else {
            return message
        }

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return disclaimer }
        if trimmed.lowercased().contains(disclaimer.lowercased()) { return trimmed }
        return "\(trimmed) \(disclaimer)"
    }

    static func statusTimelineSupplement(from events: [CoachTimelineContextEvent]) -> String? {
        let confirmed = events.filter { $0.status == CoachTimelineEventStatus.confirmed.rawValue }
        guard !confirmed.isEmpty else { return nil }

        var lines: [String] = []
        if let workout = confirmed.last(where: { $0.type == CoachTimelineEventType.workoutDetected.rawValue }) {
            lines.append("Timeline: \(workout.summary)")
        }
        if let lastFood = confirmed.last(where: { $0.type == CoachTimelineEventType.foodLogged.rawValue }) {
            lines.append("Last logged meal: \(lastFood.summary)")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func stepsLine(from hints: CoachResponseContextHints?) -> String? {
        guard let missing = hints?.missingData else { return nil }
        if missing.stepsMissing || missing.stepsUnavailable {
            return "Steps: unavailable (not synced from Apple Health)."
        }
        return nil
    }
}
