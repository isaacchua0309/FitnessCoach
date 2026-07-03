//
//  TodayHealthIntelligencePresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Maps HealthIntelligenceSnapshot into Today Health Intelligence presentation state.
//  Pure deterministic mapping; no SwiftUI or HealthKit.
//

import Foundation

enum TodayHealthIntelligencePresentationBuilder {

    // MARK: - Section

    /// Returns `nil` when Health Intelligence UI is disabled so existing Today output is unchanged.
    static func buildSection(
        snapshot: HealthIntelligenceSnapshot?,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress = .unavailable,
        isLoading: Bool = false,
        isUIEnabled: Bool = HealthIntelligenceFeatureFlags.isUIEnabled
    ) -> TodayHealthIntelligenceSectionState? {
        guard isUIEnabled else { return nil }

        if isLoading {
            return loadingSection()
        }

        guard let snapshot else {
            return unavailableSection()
        }

        let recoveryCard = recoveryCard(from: snapshot.recovery)
        let dailyMission = dailyMission(
            recovery: snapshot.recovery,
            workout: snapshot.workout,
            nutritionProgress: nutritionProgress
        )
        let mappedNextBestAction = nextBestAction(from: snapshot.nextBestAction)
        let workoutCard = workoutCard(from: snapshot.workout)
        let adaptiveNutritionCard = adaptiveNutritionCard(
            from: snapshot.nutritionAdjustment,
            nutritionProgress: nutritionProgress
        )
        let fallbackMessage = fallbackMessage(
            recovery: snapshot.recovery,
            activity: snapshot.activity,
            workout: snapshot.workout,
            nextBestAction: snapshot.nextBestAction
        )

        return TodayHealthIntelligenceSectionState(
            recoveryCard: recoveryCard,
            dailyMission: dailyMission,
            nextBestAction: connectHealthActionIfNeeded(
                healthAction: mappedNextBestAction,
                fallbackMessage: fallbackMessage
            ),
            workoutCard: workoutCard,
            adaptiveNutritionCard: adaptiveNutritionCard,
            isLoading: false,
            fallbackMessage: fallbackMessage
        )
    }

    // MARK: - Recovery

    static func recoveryCard(from recovery: RecoverySummary) -> TodayRecoveryCardState {
        let phase = recoveryPhase(from: recovery)
        let confidenceNote = confidenceNote(for: recovery.confidence)
        let missingDataNote = missingDataNote(for: recovery)

        let title = recovery.title
        let subtitle = trimmed(recovery.explanation)
        let trainingGuidance = trimmed(recovery.recommendedTraining)
        let nutritionGuidance = trimmed(recovery.recommendedNutrition)

        return TodayRecoveryCardState(
            phase: phase,
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle,
            title: title,
            subtitle: subtitle,
            trainingGuidance: trainingGuidance,
            nutritionGuidance: nutritionGuidance,
            confidenceNote: confidenceNote,
            missingDataNote: missingDataNote,
            accessibilityLabel: recoveryAccessibilityLabel(
                title: title,
                subtitle: subtitle,
                trainingGuidance: trainingGuidance,
                nutritionGuidance: nutritionGuidance,
                confidenceNote: confidenceNote,
                missingDataNote: missingDataNote
            )
        )
    }

    // MARK: - Workout

    static func workoutCard(from workout: WorkoutSummary?) -> TodayHealthWorkoutCardState? {
        guard let workout, workout.hasWorkout else { return nil }

        let title = FormaProductCopy.Today.HealthIntelligence.workoutComplete
        let subtitle = trimmed(workout.title)
        let nutritionTip = trimmed(workout.nutritionAdvice)
        let hydrationTip = hydrationTip(from: workout)

        return TodayHealthWorkoutCardState(
            phase: .completed,
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.Workout.sectionTitle,
            title: title,
            subtitle: subtitle,
            nutritionTip: nutritionTip,
            hydrationTip: hydrationTip,
            accessibilityLabel: workoutAccessibilityLabel(
                title: title,
                subtitle: subtitle,
                nutritionTip: nutritionTip,
                hydrationTip: hydrationTip
            )
        )
    }

    // MARK: - Adaptive nutrition

    static func adaptiveNutritionCard(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress
    ) -> TodayAdaptiveNutritionCardState? {
        guard hasAdaptiveNutritionContent(summary) else { return nil }

        let title = adaptiveNutritionTitle(from: summary)
        let subtitle = trimmed(summary.adjustmentReason)
        let proteinGuidance = proteinGuidance(from: summary, nutritionProgress: nutritionProgress)
        let calorieGuidance = trimmed(summary.calorieAdvice)
        let waterGuidance = waterGuidance(from: summary, nutritionProgress: nutritionProgress)
        let confidenceNote = summary.confidence == .low
            ? FormaProductCopy.Today.HealthIntelligence.limitedEstimate
            : nil

        return TodayAdaptiveNutritionCardState(
            isVisible: true,
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.sectionTitle,
            title: title,
            subtitle: subtitle?.isEmpty == false ? subtitle : nil,
            proteinGuidance: proteinGuidance,
            calorieGuidance: calorieGuidance,
            waterGuidance: waterGuidance,
            confidenceNote: confidenceNote,
            accessibilityLabel: adaptiveNutritionAccessibilityLabel(
                title: title,
                subtitle: subtitle,
                proteinGuidance: proteinGuidance,
                calorieGuidance: calorieGuidance,
                waterGuidance: waterGuidance,
                confidenceNote: confidenceNote
            )
        )
    }

    // MARK: - Next best action

    static func nextBestAction(from action: NextBestAction) -> TodayHealthNextBestActionState {
        guard isVisibleHealthAction(action) else {
            return .hidden
        }

        let title = action.title
        let message = trimmed(action.message)
        let ctaTitle = trimmed(action.ctaTitle)
        let destination = mapDestination(action.destination, reason: action.reason)

        return TodayHealthNextBestActionState(
            isVisible: true,
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.NextAction.sectionTitle,
            title: title,
            message: message,
            ctaTitle: ctaTitle?.isEmpty == false ? ctaTitle : nil,
            destination: destination,
            accessibilityLabel: nextBestActionAccessibilityLabel(
                title: title,
                message: message,
                ctaTitle: ctaTitle
            )
        )
    }

    // MARK: - Daily mission

    static func dailyMission(
        recovery: RecoverySummary,
        workout: WorkoutSummary?,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress
    ) -> TodayDailyMissionState {
        let headline = dailyMissionHeadline(for: recovery.status)
        var detailLines = dailyMissionRecoveryDetail(for: recovery)
        detailLines.append(contentsOf: dailyMissionWorkoutDetail(for: workout))
        detailLines.append(contentsOf: dailyMissionNutritionDetail(from: nutritionProgress))

        let focusSummary = dailyMissionFocusSummary(
            recovery: recovery,
            workout: workout,
            nutritionProgress: nutritionProgress
        )

        return TodayDailyMissionState(
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.DailyMission.sectionTitle,
            headline: headline,
            detailLines: detailLines,
            focusSummary: focusSummary,
            accessibilityLabel: dailyMissionAccessibilityLabel(
                headline: headline,
                detailLines: detailLines,
                focusSummary: focusSummary
            )
        )
    }

    // MARK: - Private helpers

    private static func loadingSection() -> TodayHealthIntelligenceSectionState {
        TodayHealthIntelligenceSectionState(
            recoveryCard: .loading,
            dailyMission: .loading,
            nextBestAction: .loading,
            workoutCard: nil,
            adaptiveNutritionCard: nil,
            isLoading: true,
            fallbackMessage: nil
        )
    }

    private static func unavailableSection() -> TodayHealthIntelligenceSectionState {
        TodayHealthIntelligenceSectionState(
            recoveryCard: recoveryCard(from: .unknown),
            dailyMission: dailyMission(
                recovery: .unknown,
                workout: nil,
                nutritionProgress: .unavailable
            ),
            nextBestAction: .hidden,
            workoutCard: nil,
            adaptiveNutritionCard: nil,
            isLoading: false,
            fallbackMessage: FormaProductCopy.Today.HealthIntelligence.connectHealthFallback
        )
    }

    private static func recoveryPhase(from recovery: RecoverySummary) -> TodayRecoveryCardPhase {
        if recovery.confidence == .low || recovery.confidence == .unknown {
            switch recovery.status {
            case .ready, .moderate:
                return .limitedEstimate
            case .low:
                return .low
            case .unknown:
                return .unknown
            }
        }

        switch recovery.status {
        case .ready: return .ready
        case .moderate: return .moderate
        case .low: return .low
        case .unknown: return .unknown
        }
    }

    private static func confidenceNote(for confidence: RecoveryConfidence) -> String? {
        switch confidence {
        case .low, .unknown:
            return FormaProductCopy.Today.HealthIntelligence.limitedEstimate
        case .moderate, .high:
            return nil
        }
    }

    private static func missingDataNote(for recovery: RecoverySummary) -> String? {
        guard !recovery.missingSignals.isEmpty else { return nil }

        var labels: [String] = []
        if recovery.missingSignals.contains(.sleep) {
            labels.append("sleep")
        }
        if recovery.missingSignals.contains(.hrv) {
            labels.append("HRV")
        }
        if recovery.missingSignals.contains(.restingHeartRate) {
            labels.append("resting heart rate")
        }
        if recovery.missingSignals.contains(.activity) {
            labels.append("activity")
        }
        if recovery.missingSignals.contains(.workouts) {
            labels.append("workouts")
        }
        if recovery.missingSignals.contains(.trainingLoad) {
            labels.append("training load")
        }

        guard !labels.isEmpty else { return nil }
        return FormaProductCopy.Today.HealthIntelligence.missingRecoverySignals(labels)
    }

    private static func hydrationTip(from workout: WorkoutSummary) -> String? {
        guard workout.hydrationAdviceMl > 0 else { return nil }
        return FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.extraWater(
            workout.hydrationAdviceMl
        )
    }

    private static func hasAdaptiveNutritionContent(_ summary: AdaptiveNutritionSummary) -> Bool {
        if summary.shouldChangeTarget { return true }
        if !summary.calorieAdvice.isEmpty { return true }
        if !summary.adjustmentReason.isEmpty { return true }
        if summary.proteinRecommendationGrams != nil { return true }
        if summary.suggestedProteinRemaining != nil { return true }
        if summary.waterIncreaseMl > 0 { return true }
        if summary.suggestedWaterRemainingMl != nil { return true }
        return false
    }

    private static func adaptiveNutritionTitle(from summary: AdaptiveNutritionSummary) -> String {
        if summary.priority >= 5 {
            return FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.postWorkoutTitle
        }
        return FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.defaultTitle
    }

    private static func proteinGuidance(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress
    ) -> String? {
        if let remaining = summary.suggestedProteinRemaining, remaining > 0 {
            return FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.proteinRemaining(
                remaining
            )
        }
        if let recommendation = summary.proteinRecommendationGrams, recommendation > 0 {
            return FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.proteinRemaining(
                recommendation
            )
        }
        if let remaining = nutritionProgress.proteinRemainingGrams,
           nutritionProgress.hasProteinTarget,
           remaining > 0 {
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.proteinRemaining(
                remaining
            )
        }
        return nil
    }

    private static func waterGuidance(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress
    ) -> String? {
        if summary.waterIncreaseMl > 0 {
            return FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.extraWater(
                summary.waterIncreaseMl
            )
        }
        if let remaining = summary.suggestedWaterRemainingMl, remaining > 0 {
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.waterRemaining(remaining)
        }
        if let remaining = nutritionProgress.waterRemainingMl,
           nutritionProgress.hasWaterTarget,
           remaining > 0 {
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.waterRemaining(remaining)
        }
        return nil
    }

    private static func isVisibleHealthAction(_ action: NextBestAction) -> Bool {
        guard !action.id.isEmpty else { return false }
        guard !action.title.isEmpty else { return false }
        return true
    }

    private static func mapDestination(
        _ destination: NextBestActionDestination,
        reason: HealthNextBestActionReason
    ) -> TodayHealthNextBestActionDestination {
        if destination == .none, reason == .connectHealth {
            return .connectHealth
        }

        switch destination {
        case .logMeal: return .logMeal
        case .addWater: return .addWater
        case .askCoach: return .askCoach
        case .viewRecovery: return .viewRecovery
        case .logWeight: return .logWeight
        case .none: return .none
        }
    }

    private static func dailyMissionHeadline(for status: RecoveryStatus) -> String {
        switch status {
        case .ready:
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.readyHeadline
        case .moderate:
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.moderateHeadline
        case .low:
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.lowHeadline
        case .unknown:
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.unknownHeadline
        }
    }

    private static func dailyMissionRecoveryDetail(for recovery: RecoverySummary) -> [String] {
        var lines: [String] = []
        let training = trimmed(recovery.recommendedTraining)
        if let training, !training.isEmpty {
            lines.append(training)
        }
        return lines
    }

    private static func dailyMissionWorkoutDetail(for workout: WorkoutSummary?) -> [String] {
        guard let workout, workout.hasWorkout else {
            return [FormaProductCopy.Today.HealthIntelligence.noWorkoutYet]
        }
        return [FormaProductCopy.Today.HealthIntelligence.DailyMission.workoutCompleteDetail]
    }

    private static func dailyMissionNutritionDetail(
        from progress: TodayHealthIntelligenceNutritionProgress
    ) -> [String] {
        var lines: [String] = []

        if let calories = progress.calorieRemaining, progress.hasCalorieTarget {
            lines.append(FormaProductCopy.Today.HealthIntelligence.DailyMission.caloriesRemaining(calories))
        }
        if let protein = progress.proteinRemainingGrams, progress.hasProteinTarget, protein > 0 {
            lines.append(FormaProductCopy.Today.HealthIntelligence.DailyMission.proteinRemaining(protein))
        }
        if let water = progress.waterRemainingMl, progress.hasWaterTarget, water > 0 {
            lines.append(FormaProductCopy.Today.HealthIntelligence.DailyMission.waterRemaining(water))
        }

        return lines
    }

    private static func dailyMissionFocusSummary(
        recovery: RecoverySummary,
        workout: WorkoutSummary?,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress
    ) -> String? {
        if recovery.status == .low {
            return recovery.recommendedNutrition
        }
        if let workout, workout.hasWorkout, !workout.nutritionAdvice.isEmpty {
            return workout.nutritionAdvice
        }
        if nutritionProgress.hasProteinTarget,
           let protein = nutritionProgress.proteinRemainingGrams,
           protein > 0 {
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.proteinRemaining(protein)
        }
        return nil
    }

    private static func fallbackMessage(
        recovery: RecoverySummary,
        activity: ActivitySummary,
        workout: WorkoutSummary?,
        nextBestAction: NextBestAction
    ) -> String? {
        if nextBestAction.reason == .connectHealth {
            return FormaProductCopy.Today.HealthIntelligence.connectHealthFallback
        }

        let hasWorkout = workout?.hasWorkout == true
        let hasActivity = activity.steps != nil
            || activity.activeEnergyKcal != nil
            || activity.exerciseMinutes != nil

        if recovery.status == .unknown && !hasWorkout && !hasActivity {
            return FormaProductCopy.Today.HealthIntelligence.connectHealthFallback
        }

        if recovery.confidence == .low || recovery.confidence == .unknown {
            if !recovery.missingSignals.isEmpty {
                return FormaProductCopy.Today.HealthIntelligence.continueLoggingFallback
            }
        }

        return nil
    }

    private static func connectHealthActionIfNeeded(
        healthAction: TodayHealthNextBestActionState,
        fallbackMessage: String?
    ) -> TodayHealthNextBestActionState {
        guard !healthAction.isVisible else { return healthAction }
        guard let fallbackMessage else { return healthAction }

        return TodayHealthNextBestActionState(
            isVisible: true,
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.NextAction.sectionTitle,
            title: FormaProductCopy.Today.actionConnectAppleHealth,
            message: fallbackMessage,
            ctaTitle: FormaProductCopy.Today.NextAction.ctaConnectHealth,
            destination: .connectHealth,
            accessibilityLabel: [
                FormaProductCopy.Today.HealthIntelligence.NextAction.sectionTitle,
                FormaProductCopy.Today.actionConnectAppleHealth,
                fallbackMessage
            ]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        )
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func recoveryAccessibilityLabel(
        title: String,
        subtitle: String?,
        trainingGuidance: String?,
        nutritionGuidance: String?,
        confidenceNote: String?,
        missingDataNote: String?
    ) -> String {
        [
            FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle,
            title,
            subtitle,
            trainingGuidance,
            nutritionGuidance,
            confidenceNote,
            missingDataNote
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: ". ")
    }

    private static func workoutAccessibilityLabel(
        title: String,
        subtitle: String?,
        nutritionTip: String?,
        hydrationTip: String?
    ) -> String {
        [
            FormaProductCopy.Today.HealthIntelligence.Workout.sectionTitle,
            title,
            subtitle,
            nutritionTip,
            hydrationTip
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: ". ")
    }

    private static func adaptiveNutritionAccessibilityLabel(
        title: String,
        subtitle: String?,
        proteinGuidance: String?,
        calorieGuidance: String?,
        waterGuidance: String?,
        confidenceNote: String?
    ) -> String {
        [
            FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.sectionTitle,
            title,
            subtitle,
            proteinGuidance,
            calorieGuidance,
            waterGuidance,
            confidenceNote
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: ". ")
    }

    private static func nextBestActionAccessibilityLabel(
        title: String,
        message: String?,
        ctaTitle: String?
    ) -> String {
        [
            FormaProductCopy.Today.HealthIntelligence.NextAction.sectionTitle,
            title,
            message,
            ctaTitle
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: ". ")
    }

    private static func dailyMissionAccessibilityLabel(
        headline: String,
        detailLines: [String],
        focusSummary: String?
    ) -> String {
        ([
            FormaProductCopy.Today.HealthIntelligence.DailyMission.sectionTitle,
            headline
        ] + detailLines + [focusSummary])
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: ". ")
    }
}
