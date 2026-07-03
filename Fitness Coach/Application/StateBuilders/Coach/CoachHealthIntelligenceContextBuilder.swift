//
//  CoachHealthIntelligenceContextBuilder.swift
//  Fitness Coach
//
//  Forma — Maps HealthIntelligenceSnapshot into Coach-safe prompt context.
//  Pure deterministic mapping; no HealthKit, UI, or repository access.
//

import Foundation

enum CoachHealthIntelligenceContextBuilder {

    static func build(
        from snapshot: HealthIntelligenceSnapshot,
        trainingLoad: TrainingLoadSummary = .unknown,
        calendar: Calendar = .current
    ) -> CoachHealthIntelligenceContext {
        let recovery = snapshot.recovery
        let workout = snapshot.workout
        let activity = snapshot.activity
        let nutrition = snapshot.nutritionAdjustment
        let nextBestAction = snapshot.nextBestAction

        return CoachHealthIntelligenceContext(
            date: calendar.startOfDay(for: snapshot.date),
            recoveryStatus: coachSafeRecoveryStatus(from: recovery),
            recoveryScore: coachSafeRecoveryScore(from: recovery),
            recoveryConfidence: conservativeConfidenceLabel(for: recovery.confidence),
            recoveryExplanation: coachSafeRecoveryExplanation(from: recovery),
            workoutCompletedToday: workout?.hasWorkout == true,
            workoutSummaryText: coachSafeWorkoutSummary(from: workout),
            workoutDemand: coachSafeWorkoutDemand(from: workout),
            totalWorkoutMinutesToday: workout?.totalDurationMinutes ?? 0,
            totalActiveCaloriesToday: coachSafeActiveCalories(from: workout),
            stepsToday: activity.steps,
            adaptiveNutritionAdvice: coachSafeNutritionAdvice(from: nutrition),
            proteinRecommendation: coachSafeProteinRecommendation(from: nutrition),
            hydrationRecommendationMl: coachSafeHydrationRecommendation(from: nutrition),
            trainingLoadStatus: coachSafeTrainingLoadStatus(from: trainingLoad),
            nextBestActionTitle: coachSafeNextBestActionTitle(from: nextBestAction),
            nextBestActionReason: coachSafeNextBestActionReason(from: nextBestAction),
            missingSignals: plainLanguageMissingSignals(
                recovery: recovery,
                nutrition: nutrition,
                trainingLoad: trainingLoad
            ),
            healthDataConfidenceLabel: healthDataConfidenceLabel(
                recovery: recovery,
                planConfidence: snapshot.planConfidence,
                trainingLoad: trainingLoad
            )
        )
    }

    // MARK: - Recovery

    static func coachSafeRecoveryExplanation(from recovery: RecoverySummary) -> String {
        if shouldPreferLimitedRecoveryWording(for: recovery) {
            return limitedRecoveryExplanation(for: recovery)
        }

        if let sanitized = sanitizedCoachText(recovery.explanation) {
            return sanitized
        }

        return statusBasedRecoveryExplanation(for: recovery)
    }

    private static func coachSafeRecoveryStatus(from recovery: RecoverySummary) -> String {
        recovery.status.rawValue
    }

    private static func coachSafeRecoveryScore(from recovery: RecoverySummary) -> Int? {
        guard let score = recovery.score else { return nil }
        guard recovery.confidence == .moderate || recovery.confidence == .high else { return nil }
        guard !shouldPreferLimitedRecoveryWording(for: recovery) else { return nil }
        return score
    }

    private static func shouldPreferLimitedRecoveryWording(for recovery: RecoverySummary) -> Bool {
        if recovery.confidence == .low || recovery.confidence == .unknown {
            return true
        }

        if recovery.status == .unknown {
            return true
        }

        return hasMissingHeartOrSleepSignals(recovery.missingSignals)
    }

    private static func limitedRecoveryExplanation(for recovery: RecoverySummary) -> String {
        if hasMissingHeartOrSleepSignals(recovery.missingSignals) {
            return "Recovery estimate is limited because \(missingHeartSleepPhrase(from: recovery.missingSignals)) signals are missing."
        }

        if recovery.status == .unknown {
            return "Recovery estimate is unavailable because not enough recovery signals are available yet."
        }

        return "Recovery estimate is limited because some recovery signals are incomplete."
    }

    private static func statusBasedRecoveryExplanation(for recovery: RecoverySummary) -> String {
        var parts: [String] = []

        if let title = sanitizedCoachText(recovery.title) {
            parts.append(title + ".")
        }

        switch recovery.status {
        case .ready:
            parts.append("Available recovery signals look supportive for your usual plan today.")
        case .moderate:
            parts.append("Available recovery signals look mixed, so steady pacing may work better than pushing hard.")
        case .low:
            parts.append("Available recovery signals suggest keeping today lighter and prioritizing rest.")
        case .unknown:
            parts.append("Recovery estimate is unavailable because not enough recovery signals are available yet.")
        }

        if let training = sanitizedCoachText(recovery.recommendedTraining) {
            parts.append(training)
        }

        return parts.joined(separator: " ")
    }

    private static func hasMissingHeartOrSleepSignals(_ signals: Set<RecoveryMissingSignal>) -> Bool {
        signals.contains(.sleep)
            || signals.contains(.hrv)
            || signals.contains(.restingHeartRate)
    }

    private static func missingHeartSleepPhrase(from signals: Set<RecoveryMissingSignal>) -> String {
        let missingSleep = signals.contains(.sleep)
        let missingHeart = signals.contains(.hrv) || signals.contains(.restingHeartRate)

        switch (missingSleep, missingHeart) {
        case (true, true):
            return "sleep and heart"
        case (true, false):
            return "sleep"
        case (false, true):
            return "heart"
        case (false, false):
            return "recovery"
        }
    }

    // MARK: - Workout

    static func coachSafeWorkoutSummary(from workout: WorkoutSummary?) -> String? {
        guard let workout, workout.hasWorkout else { return nil }

        var parts: [String] = []

        if let title = sanitizedCoachText(workout.title) {
            parts.append("A \(title.lowercased()) workout was logged today.")
        } else {
            parts.append("A workout was logged today.")
        }

        if workout.totalDurationMinutes > 0 {
            parts.append("Duration: \(workout.totalDurationMinutes) minutes.")
        }

        if workout.demand != .unknown {
            parts.append("Training demand looks \(workout.demand.rawValue).")
        }

        if let nutritionAdvice = sanitizedCoachText(workout.nutritionAdvice) {
            parts.append(nutritionAdvice)
        }

        return parts.joined(separator: " ")
    }

    private static func coachSafeWorkoutDemand(from workout: WorkoutSummary?) -> String? {
        guard let workout, workout.hasWorkout, workout.demand != .unknown else { return nil }
        return workout.demand.rawValue
    }

    private static func coachSafeActiveCalories(from workout: WorkoutSummary?) -> Int? {
        guard let workout, workout.hasWorkout else { return nil }
        guard workout.confidence != .low else { return nil }
        return workout.totalActiveCalories
    }

    // MARK: - Adaptive nutrition

    static func coachSafeNutritionAdvice(from summary: AdaptiveNutritionSummary) -> String? {
        guard summary.confidence != .low || summary.missingSignals.isEmpty else {
            return nil
        }

        var parts: [String] = []

        if let advice = sanitizedCoachText(summary.calorieAdvice) {
            parts.append(advice)
        }

        if let reason = sanitizedCoachText(summary.adjustmentReason) {
            parts.append(reason)
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    private static func coachSafeProteinRecommendation(from summary: AdaptiveNutritionSummary) -> Int? {
        guard summary.confidence != .low || summary.missingSignals.isEmpty else { return nil }

        if let recommendation = summary.proteinRecommendationGrams, recommendation > 0 {
            return recommendation
        }
        if let remaining = summary.suggestedProteinRemaining, remaining > 0 {
            return remaining
        }
        return nil
    }

    private static func coachSafeHydrationRecommendation(from summary: AdaptiveNutritionSummary) -> Int? {
        guard summary.confidence != .low || summary.missingSignals.isEmpty else { return nil }

        if summary.waterIncreaseMl > 0 {
            return summary.waterIncreaseMl
        }
        if let remaining = summary.suggestedWaterRemainingMl, remaining > 0 {
            return remaining
        }
        return nil
    }

    // MARK: - Training load

    static func coachSafeTrainingLoadStatus(from summary: TrainingLoadSummary) -> String {
        let status = summary.status.rawValue

        guard summary.status != .unknown else {
            return "unknown"
        }

        guard summary.confidence != .low else {
            return "\(status) (limited estimate)"
        }

        if let explanation = sanitizedCoachText(summary.explanation) {
            return "\(status) — \(explanation)"
        }

        return status
    }

    // MARK: - Next best action

    static func coachSafeNextBestActionTitle(from action: NextBestAction) -> String? {
        guard !action.id.isEmpty else { return nil }
        return sanitizedCoachText(action.title)
    }

    static func coachSafeNextBestActionReason(from action: NextBestAction) -> String? {
        guard !action.id.isEmpty else { return nil }
        return humanizedReason(action.reason.rawValue)
    }

    // MARK: - Missing signals

    static func plainLanguageMissingSignals(
        recovery: RecoverySummary,
        nutrition: AdaptiveNutritionSummary,
        trainingLoad: TrainingLoadSummary
    ) -> [String] {
        var labels = Set<String>()

        for signal in recovery.missingSignals {
            labels.insert(recoveryMissingSignalLabel(signal))
        }

        for signal in nutrition.missingSignals {
            labels.insert(nutritionMissingSignalLabel(signal))
        }

        for signal in trainingLoad.missingSignals {
            labels.insert(trainingLoadMissingSignalLabel(signal))
        }

        if shouldPreferLimitedRecoveryWording(for: recovery),
           hasMissingHeartOrSleepSignals(recovery.missingSignals) {
            labels.remove("sleep")
            labels.remove("HRV")
            labels.remove("resting heart rate")
        }

        return labels.sorted()
    }

    // MARK: - Confidence

    private static func conservativeConfidenceLabel(for confidence: RecoveryConfidence) -> String {
        switch confidence {
        case .high:
            return "moderate"
        case .moderate:
            return "moderate"
        case .low, .unknown:
            return "limited"
        }
    }

    private static func healthDataConfidenceLabel(
        recovery: RecoverySummary,
        planConfidence: PlanHealthConfidence,
        trainingLoad: TrainingLoadSummary
    ) -> String {
        if recovery.confidence == .low || recovery.confidence == .unknown {
            return FormaProductCopy.HealthIntelligence.limitedEstimateLabel
        }

        if !recovery.missingSignals.isEmpty {
            return FormaProductCopy.HealthIntelligence.partialDataLabel
        }

        if trainingLoad.confidence == .low || trainingLoad.status == .unknown {
            return FormaProductCopy.HealthIntelligence.partialDataLabel
        }

        let planLabel = planConfidence.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if planLabel.isEmpty || planLabel.caseInsensitiveCompare("unknown") == .orderedSame {
            return "Moderate estimate"
        }

        return "\(planLabel) estimate"
    }

    // MARK: - Sanitization

    private static func sanitizedCoachText(_ text: String) -> String? {
        HealthIntelligencePresentationTextSanitizer.sanitize(text)
    }

    private static func humanizedReason(_ reason: String) -> String {
        reason
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .lowercased()
    }

    private static func recoveryMissingSignalLabel(_ signal: RecoveryMissingSignal) -> String {
        switch signal {
        case .sleep:
            return "sleep"
        case .restingHeartRate:
            return "resting heart rate"
        case .hrv:
            return "HRV"
        case .activity:
            return "activity"
        case .workouts:
            return "workouts"
        case .trainingLoad:
            return "training load"
        }
    }

    private static func nutritionMissingSignalLabel(_ signal: AdaptiveNutritionMissingSignal) -> String {
        switch signal {
        case .nutritionProgress:
            return "nutrition progress"
        case .userPlan:
            return "user plan"
        case .workout:
            return "workout"
        case .workoutCalories:
            return "workout calories"
        case .recovery:
            return "recovery"
        case .trainingLoad:
            return "training load"
        }
    }

    private static func trainingLoadMissingSignalLabel(_ signal: TrainingLoadMissingSignal) -> String {
        switch signal {
        case .workoutHistory:
            return "workout history"
        case .baseline:
            return "training baseline"
        case .intensityData:
            return "workout intensity"
        case .calories:
            return "workout calories"
        }
    }
}
