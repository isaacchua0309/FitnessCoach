//
//  CoachDailyStatusBuilder.swift
//  Fitness Coach
//
//  Deterministic, timeline-aware daily status copy for local Coach responses.
//

import Foundation

struct CoachDailyStatusSnapshot: Equatable, Sendable {
    var nutrition: DailyNutritionSummary
    var recentMeals: [CoachRecentMealContext]
    var steps: Int?
    var training: DailyTrainingActivity?
    var primaryWorkoutTitle: String?
    var timelineEvents: [CoachTimelineContextEvent]
    var missingData: CoachMissingDataContext?
    var healthIntelligence: CoachHealthIntelligenceContext?

    static func make(
        log: DailyLog,
        recentMeals: [CoachRecentMealContext] = [],
        steps: Int? = nil,
        training: DailyTrainingActivity? = nil,
        primaryWorkoutTitle: String? = nil,
        timelineEvents: [CoachTimelineContextEvent] = [],
        missingData: CoachMissingDataContext? = nil,
        healthIntelligence: CoachHealthIntelligenceContext? = nil
    ) -> CoachDailyStatusSnapshot {
        CoachDailyStatusSnapshot(
            nutrition: DailyNutritionSummaryBuilder.build(from: log),
            recentMeals: recentMeals,
            steps: steps,
            training: training,
            primaryWorkoutTitle: primaryWorkoutTitle,
            timelineEvents: timelineEvents,
            missingData: missingData,
            healthIntelligence: healthIntelligence
        )
    }

    static func from(
        log: DailyLog,
        hints: CoachResponseContextHints?,
        healthIntelligence: CoachHealthIntelligenceContext? = nil,
        training: DailyTrainingActivity? = nil
    ) -> CoachDailyStatusSnapshot {
        let missingData = hints?.missingData
        var resolvedSteps = hints?.steps ?? log.steps
        if missingData?.stepsUnavailable == true || missingData?.stepsMissing == true {
            resolvedSteps = nil
        }

        var resolvedTraining = training
        if missingData?.workoutsUnavailable == true
            || missingData?.workoutPermissionDeniedOrUnavailable == true {
            resolvedTraining = nil
        }

        return make(
            log: log,
            recentMeals: hints?.recentMeals ?? [],
            steps: resolvedSteps,
            training: resolvedTraining,
            primaryWorkoutTitle: hints?.primaryWorkoutTitle,
            timelineEvents: hints?.timelineEvents ?? [],
            missingData: missingData,
            healthIntelligence: healthIntelligence ?? hints?.healthIntelligence
        )
    }
}

enum CoachDailyStatusBuilder {

    private static let nonConsumedFoodTimelineTypes: Set<String> = [
        CoachTimelineEventType.foodEstimateCreated.rawValue,
        CoachTimelineEventType.foodRejected.rawValue,
        CoachTimelineEventType.pendingConfirmationCreated.rawValue,
        CoachTimelineEventType.pendingConfirmationRejected.rawValue,
        CoachTimelineEventType.photoAnalysisFailed.rawValue,
    ]

    static func message(
        from snapshot: CoachDailyStatusSnapshot,
        focus: CoachDailyStatusFocus = .summary
    ) -> String {
        switch focus {
        case .summary:
            return summaryMessage(from: snapshot)
        case .caloriesRemaining:
            return focusedMessage(from: snapshot, body: caloriesLine(from: snapshot))
        case .proteinRemaining:
            return focusedMessage(from: snapshot, body: proteinLine(from: snapshot))
        case .waterRemaining:
            return focusedMessage(from: snapshot, body: waterLine(from: snapshot))
        case .mealsToday:
            return focusedMessage(from: snapshot, body: mealsTodayBody(from: snapshot))
        case .lastMeal:
            return focusedMessage(from: snapshot, body: lastMealBody(from: snapshot))
        }
    }

    private static func summaryMessage(from snapshot: CoachDailyStatusSnapshot) -> String {
        let nutrition = snapshot.nutrition
        let remainingCalories = max(nutrition.remaining.calories, 0)
        let remainingProtein = max(nutrition.remaining.protein, 0)
        let remainingWater = max(nutrition.water.remainingMl, 0)

        var lines: [String] = [
            "Today so far:",
            "• \(nutrition.totals.calories) / \(nutrition.targets.calories) kcal — \(remainingCalories) kcal remaining",
            "• \(formatMacro(nutrition.totals.protein)) / \(formatMacro(nutrition.targets.protein))g protein — \(formatMacro(remainingProtein))g remaining",
            "• \(formatWater(nutrition.water.consumedMl)) / \(formatWater(nutrition.water.targetMl))ml water — \(formatWater(remainingWater))ml remaining",
        ]

        if let lastMeal = lastLoggedMealLabel(
            timelineEvents: snapshot.timelineEvents,
            recentMeals: snapshot.recentMeals
        ) {
            lines.append("")
            lines.append("Last logged meal: \(lastMeal)")
        } else if snapshot.recentMeals.isEmpty,
                  !hasConfirmedFoodLogged(in: snapshot.timelineEvents) {
            lines.append("")
            lines.append("No meals logged yet today.")
        }

        if let activityLines = activityLines(from: snapshot), !activityLines.isEmpty {
            lines.append("")
            lines.append(contentsOf: activityLines)
        }

        if let insight = CoachHealthGuidanceFormatter.dailyHealthInsight(from: snapshot.healthIntelligence) {
            lines.append("")
            lines.append(insight)
        }

        if let nextAction = nextUsefulAction(from: snapshot) {
            lines.append("")
            lines.append("Next: \(nextAction)")
        }

        let body = lines.joined(separator: "\n")
        return CoachAIResponseContextAdapter.appendMissingDataDisclaimer(
            to: body,
            hints: CoachResponseContextHints(
                missingData: snapshot.missingData,
                timelineEvents: snapshot.timelineEvents
            ),
            includeSteps: false,
            includeWorkouts: false
        )
    }

    private static func focusedMessage(from snapshot: CoachDailyStatusSnapshot, body: String) -> String {
        var lines = [body.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let nextAction = nextUsefulAction(from: snapshot) {
            lines.append("Next: \(nextAction)")
        }
        return lines.joined(separator: "\n")
    }

    private static func caloriesLine(from snapshot: CoachDailyStatusSnapshot) -> String {
        let nutrition = snapshot.nutrition
        if nutrition.isOverCalories {
            let overBy = nutrition.totals.calories - nutrition.targets.calories
            return "You are \(PlanDisplayFormatter.formatGroupedInteger(overBy)) kcal over target today (\(nutrition.totals.calories) / \(nutrition.targets.calories) kcal logged)."
        }
        let remaining = max(nutrition.remaining.calories, 0)
        return "You have \(PlanDisplayFormatter.formatGroupedInteger(remaining)) kcal remaining today (\(nutrition.totals.calories) / \(nutrition.targets.calories) kcal logged)."
    }

    private static func proteinLine(from snapshot: CoachDailyStatusSnapshot) -> String {
        let nutrition = snapshot.nutrition
        if nutrition.hasMetProteinTarget {
            return "Protein target met for today (\(formatMacro(nutrition.totals.protein))g / \(formatMacro(nutrition.targets.protein))g logged)."
        }
        let remaining = max(nutrition.remaining.protein, 0)
        return "You have \(formatMacro(remaining))g protein remaining today (\(formatMacro(nutrition.totals.protein))g / \(formatMacro(nutrition.targets.protein))g logged)."
    }

    private static func waterLine(from snapshot: CoachDailyStatusSnapshot) -> String {
        let nutrition = snapshot.nutrition
        let remaining = max(nutrition.water.remainingMl, 0)
        return "You have \(formatWater(remaining))ml water remaining today (\(formatWater(nutrition.water.consumedMl)) / \(formatWater(nutrition.water.targetMl))ml logged)."
    }

    private static func mealsTodayBody(from snapshot: CoachDailyStatusSnapshot) -> String {
        let meals = consumedMealLabels(from: snapshot)
        guard !meals.isEmpty else {
            return "No meals logged yet today."
        }
        if meals.count == 1 {
            return "Today's logged meal: \(meals[0])"
        }
        return "Today's logged meals:\n" + meals.map { "• \($0)" }.joined(separator: "\n")
    }

    private static func lastMealBody(from snapshot: CoachDailyStatusSnapshot) -> String {
        if let lastMeal = lastLoggedMealLabel(
            timelineEvents: snapshot.timelineEvents,
            recentMeals: snapshot.recentMeals
        ) {
            return "Last logged meal: \(lastMeal)"
        }
        return "No meals logged yet today."
    }

    private static func consumedMealLabels(from snapshot: CoachDailyStatusSnapshot) -> [String] {
        let timelineMeals = confirmedEvents(snapshot.timelineEvents)
            .filter { $0.type == CoachTimelineEventType.foodLogged.rawValue }
            .map { formatFoodEventLabel($0) }

        if !timelineMeals.isEmpty {
            return timelineMeals
        }

        return snapshot.recentMeals.map { formatRecentMealLabel($0) }
    }

    // MARK: Timeline helpers

    private static func confirmedEvents(
        _ events: [CoachTimelineContextEvent]
    ) -> [CoachTimelineContextEvent] {
        events.filter { event in
            guard event.status == CoachTimelineEventStatus.confirmed.rawValue else {
                return false
            }
            return !nonConsumedFoodTimelineTypes.contains(event.type)
        }
    }

    private static func hasConfirmedFoodLogged(in events: [CoachTimelineContextEvent]) -> Bool {
        confirmedEvents(events).contains {
            $0.type == CoachTimelineEventType.foodLogged.rawValue
        }
    }

    private static func lastLoggedMealLabel(
        timelineEvents: [CoachTimelineContextEvent],
        recentMeals: [CoachRecentMealContext]
    ) -> String? {
        if let foodEvent = confirmedEvents(timelineEvents).last(where: {
            $0.type == CoachTimelineEventType.foodLogged.rawValue
        }) {
            return formatFoodEventLabel(foodEvent)
        }

        guard let meal = recentMeals.last else { return nil }
        return formatRecentMealLabel(meal)
    }

    private static func formatFoodEventLabel(_ event: CoachTimelineContextEvent) -> String {
        if let payload = event.compactPayload,
           let name = payload["name"],
           let kcal = payload["kcal"] {
            return "\(name) (\(kcal) kcal)"
        }
        let summary = event.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? "Logged meal" : summary
    }

    private static func formatRecentMealLabel(_ meal: CoachRecentMealContext) -> String {
        if let calories = meal.calories {
            return "\(meal.name) (\(calories) kcal)"
        }
        return meal.name
    }

    private static func activityLines(from snapshot: CoachDailyStatusSnapshot) -> [String]? {
        var lines: [String] = []

        if snapshot.missingData?.stepsMissing == true
            || snapshot.missingData?.stepsUnavailable == true {
            lines.append("Steps: unavailable (not synced from Apple Health).")
        } else if let steps = snapshot.steps {
            lines.append("Steps: \(formatSteps(steps))")
        }

        if snapshot.missingData?.workoutPermissionDeniedOrUnavailable != true,
           snapshot.missingData?.workoutsUnavailable != true,
           let training = snapshot.training,
           training.hasWorkout,
           let workoutLine = workoutLine(
               training: training,
               primaryTitle: snapshot.primaryWorkoutTitle,
               timelineEvents: snapshot.timelineEvents
           ) {
            lines.append(workoutLine)
        }

        if let waterAction = latestTimelineActionLabel(
            type: CoachTimelineEventType.waterLogged.rawValue,
            in: snapshot.timelineEvents,
            fallbackPrefix: "Water"
        ) {
            lines.append(waterAction)
        }

        if let weightAction = latestTimelineActionLabel(
            type: CoachTimelineEventType.weightLogged.rawValue,
            in: snapshot.timelineEvents,
            fallbackPrefix: "Weight"
        ) {
            lines.append(weightAction)
        }

        return lines.isEmpty ? nil : lines
    }

    private static func workoutLine(
        training: DailyTrainingActivity,
        primaryTitle: String?,
        timelineEvents: [CoachTimelineContextEvent]
    ) -> String? {
        if let workout = confirmedEvents(timelineEvents).last(where: {
            $0.type == CoachTimelineEventType.workoutDetected.rawValue
        }) {
            let summary = workout.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty {
                return "Workout: \(summary)"
            }
        }

        if let primaryTitle, !primaryTitle.isEmpty {
            return "Workout: \(primaryTitle)"
        }

        let count = training.workoutCount
        guard count > 0 else { return nil }
        return "Workout: \(count) session\(count == 1 ? "" : "s") logged today."
    }

    private static func latestTimelineActionLabel(
        type: String,
        in events: [CoachTimelineContextEvent],
        fallbackPrefix: String
    ) -> String? {
        guard let event = confirmedEvents(events).last(where: { $0.type == type }) else {
            return nil
        }
        let summary = event.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { return nil }
        if summary.lowercased().hasPrefix(fallbackPrefix.lowercased()) {
            return summary
        }
        return "\(fallbackPrefix): \(summary)"
    }

    private static func nextUsefulAction(from snapshot: CoachDailyStatusSnapshot) -> String? {
        let nutrition = snapshot.nutrition

        if nutrition.totals.calories == 0,
           snapshot.recentMeals.isEmpty,
           !hasConfirmedFoodLogged(in: snapshot.timelineEvents) {
            return "Log your first meal to start tracking today."
        }

        if nutrition.isOverCalories {
            return "Keep your next meal lean and portion-controlled."
        }

        if snapshot.training?.hasWorkout == true
            || snapshot.healthIntelligence?.workoutCompletedToday == true {
            return "Refuel with protein and fluids after training."
        }

        if nutrition.remaining.protein > 40 {
            return "Anchor your next meal with protein."
        }

        if nutrition.water.remainingMl > 1_000 {
            return "Pace your water earlier — don't leave it all for evening."
        }

        if nutrition.hasMetProteinTarget && nutrition.hasMetWaterTarget {
            return "Stay consistent — you're on track for today."
        }

        return "Stay consistent today. Small wins compound."
    }

    // MARK: Formatting

    private static func formatMacro(_ value: Double) -> String {
        FoodEntryFormFormatter.formatMacro(value)
    }

    private static func formatWater(_ ml: Int) -> String {
        PlanDisplayFormatter.formatGroupedInteger(ml)
    }

    private static func formatSteps(_ steps: Int) -> String {
        PlanDisplayFormatter.formatGroupedInteger(steps)
    }
}
