//
//  HealthIntelligencePresentationCore.swift
//  Fitness Coach
//
//  Forma — Shared pure presentation builders for Health Intelligence cards.
//  Tab-specific builders compose these fragments into their section states.
//

import Foundation

enum HealthIntelligencePresentationCore {

    // MARK: - Text helpers

    static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func sanitizedGuidance(_ value: String) -> String? {
        guard let trimmed = trimmed(value) else { return nil }
        return HealthIntelligencePresentationTextSanitizer.sanitize(trimmed) ?? trimmed
    }

    static func sanitizedText(_ text: String) -> String? {
        HealthIntelligencePresentationTextSanitizer.sanitize(text)
    }

    // MARK: - UI state resolution

    static func presentationContext(
        snapshot: HealthIntelligenceSnapshot?,
        isLoading: Bool,
        availability: HealthDataAvailability?,
        isAppleHealthConnected: Bool,
        cachedDayCount: Int,
        errorMessage: String?,
        syncPhase: HealthSyncPhase? = nil,
        trainingIntegrationState: TrainingIntegrationState = .notConnected,
        connectionRecord: HealthIntegrationConnectionRecord = .empty,
        baseline: HealthBaselineContext? = nil
    ) -> HealthIntelligencePresentationContext {
        HealthIntelligencePresentationContext(
            isLoading: isLoading,
            explicitErrorMessage: errorMessage,
            syncPhase: syncPhase,
            availability: availability,
            snapshot: snapshot,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount,
            trainingIntegrationState: trainingIntegrationState,
            connectionRecord: connectionRecord,
            baseline: baseline
        )
    }

    static func resolveUIState(from input: HealthIntelligenceUIResolutionInput) -> HealthIntelligenceUIState {
        let uiContext = HealthIntelligenceUIContext.from(
            presentationContext: input.presentationContext,
            baseline: input.baseline,
            lastSuccessfulLocalSyncAt: input.lastSuccessfulLocalSyncAt,
            isRemoteSyncCapabilityEnabled: input.isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: input.remoteSyncConsentDecision,
            surface: input.surface
        )
        return HealthIntelligenceUIStateMapper.resolve(uiContext)
    }

    // MARK: - Recovery card

    static func recoveryPhase(from recovery: RecoverySummary) -> HealthIntelligenceRecoveryPhase {
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

    static func recoverySubtitle(
        from recovery: RecoverySummary,
        surface: HealthIntelligenceSurface
    ) -> String? {
        if HealthIntelligencePresentationPolicy.shouldPreferLimitedRecoveryWording(
            for: recovery,
            surface: surface
        ) {
            return HealthIntelligencePresentationPolicy.limitedRecoveryExplanation(
                for: recovery,
                surface: surface
            )
        }

        if let sanitized = sanitizedText(recovery.explanation) {
            return sanitized
        }

        if let title = sanitizedText(recovery.title) {
            return title
        }

        if let statusBased = HealthIntelligencePresentationPolicy.statusBasedRecoveryExplanation(
            for: recovery,
            surface: surface
        ) {
            return statusBased
        }

        return journeyRecoveryStatusLabel(for: recoveryPhase(from: recovery))
    }

    static func buildRecoveryCardContent(
        from recovery: RecoverySummary,
        uiState: HealthIntelligenceUIState?,
        staleDataLabel: String?,
        surface: HealthIntelligenceSurface
    ) -> HealthIntelligenceRecoveryCardContent {
        if let uiState, uiState.kind == .healthKitUnavailable {
            return unavailableRecoveryContent(uiState: uiState, surface: surface)
        }

        let phase = recoveryPhase(from: recovery)
        let confidenceNote = HealthIntelligencePresentationPolicy.mergedConfidenceNote(
            recoveryConfidence: HealthIntelligencePresentationPolicy.confidenceNote(
                for: recovery.confidence
            ),
            uiState: uiState
        )
        let missingDataNote = HealthIntelligencePresentationPolicy.missingRecoverySignalsNote(
            for: recovery,
            surface: surface
        )
        let title = recovery.title
        let subtitle = recoverySubtitle(from: recovery, surface: surface)
        let trainingGuidance = sanitizedGuidance(recovery.recommendedTraining)
        let nutritionGuidance = sanitizedGuidance(recovery.recommendedNutrition)

        return HealthIntelligenceRecoveryCardContent(
            phase: phase,
            title: title,
            subtitle: subtitle,
            trainingGuidance: trainingGuidance,
            nutritionGuidance: nutritionGuidance,
            confidenceNote: confidenceNote,
            missingDataNote: missingDataNote,
            staleDataLabel: staleDataLabel,
            accessibilityParts: [
                title,
                subtitle,
                trainingGuidance,
                nutritionGuidance,
                confidenceNote,
                missingDataNote,
                staleDataLabel
            ]
        )
    }

    static func unavailableRecoveryContent(
        uiState: HealthIntelligenceUIState,
        surface _: HealthIntelligenceSurface
    ) -> HealthIntelligenceRecoveryCardContent {
        HealthIntelligenceRecoveryCardContent(
            phase: .unknown,
            title: uiState.title,
            subtitle: uiState.message,
            trainingGuidance: nil,
            nutritionGuidance: nil,
            confidenceNote: nil,
            missingDataNote: nil,
            staleDataLabel: nil,
            accessibilityParts: [uiState.title, uiState.message]
        )
    }

    static func placeholderRecoveryContent(
        for uiState: HealthIntelligenceUIState,
        surface _: HealthIntelligenceSurface
    ) -> HealthIntelligenceRecoveryCardContent? {
        switch uiState.kind {
        case .healthKitUnavailable:
            return unavailableRecoveryContent(uiState: uiState, surface: .today)
        case .noHealthPermission:
            return HealthIntelligenceRecoveryCardContent(
                phase: .unknown,
                title: uiState.title,
                subtitle: uiState.message,
                trainingGuidance: nil,
                nutritionGuidance: nil,
                confidenceNote: nil,
                missingDataNote: nil,
                staleDataLabel: nil,
                accessibilityParts: [uiState.title, uiState.message]
            )
        case .unknown, .notEnoughBaseline, .remoteSyncDisabled:
            let title = uiState.title.isEmpty
                ? FormaProductCopy.Today.HealthIntelligence.DailyMission.unknownHeadline
                : uiState.title
            return HealthIntelligenceRecoveryCardContent(
                phase: .unknown,
                title: title,
                subtitle: uiState.message,
                trainingGuidance: nil,
                nutritionGuidance: nil,
                confidenceNote: uiState.confidenceLabel,
                missingDataNote: nil,
                staleDataLabel: nil,
                accessibilityParts: [title, uiState.message, uiState.confidenceLabel]
            )
        default:
            return nil
        }
    }

    static func coachSafeRecoveryScore(from recovery: RecoverySummary) -> Int? {
        guard let score = recovery.score else { return nil }
        guard recovery.confidence == .moderate || recovery.confidence == .high else { return nil }
        guard recoveryPhase(from: recovery) != .limitedEstimate else { return nil }
        guard recovery.status != .unknown else { return nil }
        return score
    }

    static func journeyRecoveryStatusLabel(
        for phase: HealthIntelligenceRecoveryPhase
    ) -> String {
        switch phase {
        case .ready: return "Ready"
        case .moderate: return "Moderate"
        case .low: return "Low"
        case .limitedEstimate: return FormaProductCopy.Journey.HealthIntelligence.limitedEstimate
        case .unknown: return "Unknown"
        }
    }

    static func journeyRecoveryStatusColorToken(
        for phase: HealthIntelligenceRecoveryPhase
    ) -> String {
        switch phase {
        case .ready: return "recoveryReady"
        case .moderate: return "recoveryModerate"
        case .low: return "recoveryLow"
        case .limitedEstimate: return "recoveryLimited"
        case .unknown: return "recoveryUnknown"
        }
    }

    // MARK: - Workout / training load card

    static func buildWorkoutCardContent(
        from workout: WorkoutSummary?,
        uiState: HealthIntelligenceUIState? = nil
    ) -> HealthIntelligenceWorkoutCardContent? {
        if let workout, workout.hasWorkout {
            return completedWorkoutContent(from: workout)
        }

        if uiState?.kind == .noWorkoutHistory {
            return emptyWorkoutContent()
        }

        return nil
    }

    private static func completedWorkoutContent(
        from workout: WorkoutSummary
    ) -> HealthIntelligenceWorkoutCardContent {
        let title = FormaProductCopy.Today.HealthIntelligence.workoutComplete
        let subtitle = trimmed(workout.title)
        let nutritionTip = trimmed(workout.nutritionAdvice)
        let hydrationTip = hydrationTip(from: workout)

        return HealthIntelligenceWorkoutCardContent(
            phase: .completed,
            title: title,
            subtitle: subtitle,
            nutritionTip: nutritionTip,
            hydrationTip: hydrationTip,
            accessibilityParts: [title, subtitle, nutritionTip, hydrationTip]
        )
    }

    private static func emptyWorkoutContent() -> HealthIntelligenceWorkoutCardContent {
        let title = FormaProductCopy.Today.HealthIntelligence.Workout.emptyTitle
        let subtitle = FormaProductCopy.Today.HealthIntelligence.Workout.emptyMessage

        return HealthIntelligenceWorkoutCardContent(
            phase: .empty,
            title: title,
            subtitle: subtitle,
            nutritionTip: nil,
            hydrationTip: nil,
            accessibilityParts: [title, subtitle]
        )
    }

    private static func hydrationTip(from workout: WorkoutSummary) -> String? {
        guard workout.hydrationAdviceMl > 0 else { return nil }
        return FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.extraWater(
            workout.hydrationAdviceMl
        )
    }

    static func coachSafeCaloriesLabel(from calories: Int?) -> String? {
        guard let calories, calories > 0 else { return nil }
        return "\(calories.formatted()) kcal est."
    }

    // MARK: - Adaptive nutrition card

    static func hasAdaptiveNutritionContent(_ summary: AdaptiveNutritionSummary) -> Bool {
        if summary.shouldChangeTarget { return true }
        if !summary.calorieAdvice.isEmpty { return true }
        if !summary.adjustmentReason.isEmpty { return true }
        if summary.proteinRecommendationGrams != nil { return true }
        if summary.suggestedProteinRemaining != nil { return true }
        if summary.waterIncreaseMl > 0 { return true }
        if summary.suggestedWaterRemainingMl != nil { return true }
        return false
    }

    static func buildAdaptiveNutritionContent(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: HealthIntelligenceNutritionProgressInput
    ) -> HealthIntelligenceAdaptiveNutritionContent? {
        guard hasAdaptiveNutritionContent(summary) else { return nil }

        let title = adaptiveNutritionTitle(from: summary)
        let subtitle = trimmed(summary.adjustmentReason)
        let proteinGuidance = proteinGuidance(from: summary, nutritionProgress: nutritionProgress)
        let calorieGuidance = trimmed(summary.calorieAdvice)
        let waterGuidance = waterGuidance(from: summary, nutritionProgress: nutritionProgress)
        let confidenceNote = HealthIntelligencePresentationPolicy.adaptiveNutritionConfidenceNote(
            for: summary.confidence
        )

        return HealthIntelligenceAdaptiveNutritionContent(
            isVisible: true,
            title: title,
            subtitle: subtitle?.isEmpty == false ? subtitle : nil,
            proteinGuidance: proteinGuidance,
            calorieGuidance: calorieGuidance,
            waterGuidance: waterGuidance,
            confidenceNote: confidenceNote,
            accessibilityParts: [
                title,
                subtitle,
                proteinGuidance,
                calorieGuidance,
                waterGuidance,
                confidenceNote
            ]
        )
    }

    static func adaptiveCardWouldShowProteinGuidance(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: HealthIntelligenceNutritionProgressInput
    ) -> Bool {
        proteinGuidance(from: summary, nutritionProgress: nutritionProgress) != nil
    }

    static func adaptiveCardWouldShowWaterGuidance(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: HealthIntelligenceNutritionProgressInput
    ) -> Bool {
        waterGuidance(from: summary, nutritionProgress: nutritionProgress) != nil
    }

    private static func adaptiveNutritionTitle(from summary: AdaptiveNutritionSummary) -> String {
        if summary.priority >= 5 {
            return FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.postWorkoutTitle
        }
        return FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.defaultTitle
    }

    private static func proteinGuidance(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: HealthIntelligenceNutritionProgressInput
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
        nutritionProgress: HealthIntelligenceNutritionProgressInput
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

    // MARK: - Weekly review building card

    static func buildWeeklyReviewBuildingContent(
        uiState: HealthIntelligenceUIState?
    ) -> HealthIntelligenceWeeklyReviewBuildingContent {
        let copy = FormaProductCopy.WeeklyReviewPresentation.self
        let usesNotEnoughData = uiState?.kind == .notEnoughBaseline
            || uiState?.kind == .unknown
            || uiState?.kind == .noWorkoutHistory

        let title = usesNotEnoughData ? copy.notEnoughDataTitle : copy.emptyTitle
        let summary = usesNotEnoughData
            ? "\(copy.notEnoughDataSummary) \(copy.notEnoughDataRequirements)"
            : copy.emptySummary
        let accessibilityLabel = usesNotEnoughData
            ? "\(title). \(summary)"
            : copy.emptyAccessibilityLabel

        return HealthIntelligenceWeeklyReviewBuildingContent(
            phase: .empty,
            title: title,
            summary: summary,
            confidenceLabel: copy.confidenceLow,
            dateRangeLabel: "",
            accessibilityLabel: accessibilityLabel
        )
    }

    // MARK: - Next best action / CTA normalization

    static func isVisibleHealthAction(_ action: NextBestAction) -> Bool {
        guard !action.id.isEmpty else { return false }
        guard !action.title.isEmpty else { return false }
        return true
    }

    static func normalizeUIStateCTACopy(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface,
        explicitErrorMessage: String? = nil
    ) -> HealthIntelligenceUIStateCTACopy {
        let copy = FormaProductCopy.HealthIntelligence.UIState.message(
            for: uiState.kind,
            surface: surface,
            explicitErrorMessage: explicitErrorMessage
        )
        return HealthIntelligenceUIStateCTACopy(
            title: copy.title,
            message: copy.message,
            primaryActionTitle: copy.primaryActionTitle,
            secondaryActionTitle: copy.secondaryActionTitle,
            accessibilityLabel: HealthIntelligencePresentationAccessibility.joinedLabel(
                parts: [copy.title, copy.message, copy.primaryActionTitle, copy.secondaryActionTitle]
            )
        )
    }

    static func connectCTACopy(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface,
        defaultCTATitle: String
    ) -> HealthIntelligenceConnectCTACopy? {
        let copy = normalizeUIStateCTACopy(for: uiState, surface: surface)

        switch uiState.primaryAction {
        case .connectAppleHealth, .manageHealthPermissions:
            return HealthIntelligenceConnectCTACopy(
                title: copy.title,
                message: copy.message,
                ctaTitle: copy.primaryActionTitle ?? defaultCTATitle,
                accessibilityLabel: "\(copy.title). \(copy.message)"
            )
        case .retrySync, .refreshHealthData:
            return HealthIntelligenceConnectCTACopy(
                title: copy.title,
                message: copy.message,
                ctaTitle: copy.primaryActionTitle ?? defaultCTATitle,
                accessibilityLabel: "\(copy.title). \(copy.message)"
            )
        case .continueLogging, .askCoach, .manageHealthDataSync, .openPlan, .none:
            return nil
        }
    }

    static func normalizedActionFields(
        from action: NextBestAction
    ) -> (title: String, message: String?, ctaTitle: String?) {
        (
            title: action.title,
            message: trimmed(action.message),
            ctaTitle: trimmed(action.ctaTitle)
        )
    }

    // MARK: - Section-level helpers (policy delegates)

    static func fallbackMessage(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface
    ) -> String? {
        HealthIntelligencePresentationPolicy.fallbackMessage(for: uiState, surface: surface)
    }

    static func staleDataLabel(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface
    ) -> String? {
        HealthIntelligencePresentationPolicy.staleDataLabel(for: uiState, surface: surface)
    }

    static func partialSignalsNote(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface
    ) -> String? {
        HealthIntelligencePresentationPolicy.partialSignalsNote(for: uiState, surface: surface)
    }

    // MARK: - Accessibility

    static func recoveryAccessibilityLabel(
        sectionTitle: String,
        content: HealthIntelligenceRecoveryCardContent
    ) -> String {
        HealthIntelligencePresentationAccessibility.cardLabel(
            sectionTitle: sectionTitle,
            parts: content.accessibilityParts
        )
    }

    static func workoutAccessibilityLabel(
        sectionTitle: String,
        content: HealthIntelligenceWorkoutCardContent
    ) -> String {
        HealthIntelligencePresentationAccessibility.cardLabel(
            sectionTitle: sectionTitle,
            parts: content.accessibilityParts
        )
    }

    static func adaptiveNutritionAccessibilityLabel(
        sectionTitle: String,
        content: HealthIntelligenceAdaptiveNutritionContent
    ) -> String {
        HealthIntelligencePresentationAccessibility.cardLabel(
            sectionTitle: sectionTitle,
            parts: content.accessibilityParts
        )
    }

    static func nextBestActionAccessibilityLabel(
        sectionTitle: String,
        title: String,
        message: String?,
        ctaTitle: String?
    ) -> String {
        HealthIntelligencePresentationAccessibility.cardLabel(
            sectionTitle: sectionTitle,
            parts: [title, message, ctaTitle]
        )
    }
}

// MARK: - Today nutrition bridge

extension HealthIntelligenceNutritionProgressInput {

    static func from(_ progress: TodayHealthIntelligenceNutritionProgress) -> Self {
        HealthIntelligenceNutritionProgressInput(
            calorieRemaining: progress.calorieRemaining,
            proteinRemainingGrams: progress.proteinRemainingGrams,
            waterRemainingMl: progress.waterRemainingMl,
            hasCalorieTarget: progress.hasCalorieTarget,
            hasProteinTarget: progress.hasProteinTarget,
            hasWaterTarget: progress.hasWaterTarget
        )
    }
}
