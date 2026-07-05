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
        HealthIntelligenceCardPresentationFactory.trimmed(value)
    }

    static func sanitizedGuidance(_ value: String) -> String? {
        HealthIntelligenceCardPresentationFactory.sanitizedGuidance(value)
    }

    static func sanitizedText(_ text: String) -> String? {
        HealthIntelligenceCardPresentationFactory.sanitizedText(text)
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
        HealthIntelligenceCardPresentationFactory.recoveryPhase(from: recovery)
    }

    static func recoverySubtitle(
        from recovery: RecoverySummary,
        surface: HealthIntelligenceSurface
    ) -> String? {
        HealthIntelligenceCardPresentationFactory.recoverySubtitle(from: recovery, surface: surface)
    }

    static func buildRecoveryCardContent(
        from recovery: RecoverySummary,
        uiState: HealthIntelligenceUIState?,
        staleDataLabel: String?,
        surface: HealthIntelligenceSurface
    ) -> HealthIntelligenceRecoveryCardContent {
        HealthIntelligenceCardPresentationFactory.makeRecoveryCardContent(
            from: HealthIntelligenceRecoveryCardBuildInput(
                recovery: recovery,
                uiState: uiState,
                staleDataLabel: staleDataLabel,
                surface: surface
            )
        )
    }

    static func unavailableRecoveryContent(
        uiState: HealthIntelligenceUIState,
        surface _: HealthIntelligenceSurface
    ) -> HealthIntelligenceRecoveryCardContent {
        HealthIntelligenceCardPresentationFactory.unavailableRecoveryContent(uiState: uiState)
    }

    static func placeholderRecoveryContent(
        for uiState: HealthIntelligenceUIState,
        surface _: HealthIntelligenceSurface
    ) -> HealthIntelligenceRecoveryCardContent? {
        HealthIntelligenceCardPresentationFactory.placeholderRecoveryContent(for: uiState)
    }

    static func disconnectedSummary(
        for uiState: HealthIntelligenceUIState
    ) -> HealthIntelligenceDisconnectedSummary {
        HealthIntelligenceCardPresentationFactory.disconnectedSummary(for: uiState)
    }

    static func coachSafeRecoveryScore(from recovery: RecoverySummary) -> Int? {
        HealthIntelligenceCardPresentationFactory.coachSafeRecoveryScore(from: recovery)
    }

    static func journeyRecoveryStatusLabel(
        for phase: HealthIntelligenceRecoveryPhase
    ) -> String {
        HealthIntelligenceCardPresentationFactory.journeyRecoveryStatusLabel(for: phase)
    }

    static func journeyRecoveryStatusColorToken(
        for phase: HealthIntelligenceRecoveryPhase
    ) -> String {
        HealthIntelligenceCardPresentationFactory.journeyRecoveryStatusColorToken(for: phase)
    }

    // MARK: - Workout / training load card

    static func buildWorkoutCardContent(
        from workout: WorkoutSummary?,
        uiState: HealthIntelligenceUIState? = nil
    ) -> HealthIntelligenceWorkoutCardContent? {
        HealthIntelligenceCardPresentationFactory.makeWorkoutCardContent(
            from: HealthIntelligenceWorkoutCardBuildInput(
                workout: workout,
                uiState: uiState
            )
        )
    }

    static func coachSafeCaloriesLabel(from calories: Int?) -> String? {
        HealthIntelligenceCardPresentationFactory.coachSafeCaloriesLabel(from: calories)
    }

    // MARK: - Adaptive nutrition card

    static func hasAdaptiveNutritionContent(_ summary: AdaptiveNutritionSummary) -> Bool {
        HealthIntelligenceCardPresentationFactory.hasAdaptiveNutritionContent(summary)
    }

    static func buildAdaptiveNutritionContent(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: HealthIntelligenceNutritionProgressInput
    ) -> HealthIntelligenceAdaptiveNutritionContent? {
        HealthIntelligenceCardPresentationFactory.makeAdaptiveNutritionContent(
            from: HealthIntelligenceAdaptiveNutritionCardBuildInput(
                summary: summary,
                nutritionProgress: nutritionProgress
            )
        )
    }

    static func adaptiveCardWouldShowProteinGuidance(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: HealthIntelligenceNutritionProgressInput
    ) -> Bool {
        HealthIntelligenceCardPresentationFactory.adaptiveCardWouldShowProteinGuidance(
            from: summary,
            nutritionProgress: nutritionProgress
        )
    }

    static func adaptiveCardWouldShowWaterGuidance(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: HealthIntelligenceNutritionProgressInput
    ) -> Bool {
        HealthIntelligenceCardPresentationFactory.adaptiveCardWouldShowWaterGuidance(
            from: summary,
            nutritionProgress: nutritionProgress
        )
    }

    // MARK: - Weekly review building card

    static func buildWeeklyReviewBuildingContent(
        uiState: HealthIntelligenceUIState?
    ) -> HealthIntelligenceWeeklyReviewBuildingContent {
        HealthIntelligenceCardPresentationFactory.makeWeeklyReviewBuildingContent(uiState: uiState)
    }

    // MARK: - Next best action / CTA normalization

    static func isVisibleHealthAction(_ action: NextBestAction) -> Bool {
        HealthIntelligenceCardPresentationFactory.isVisibleHealthAction(action)
    }

    static func normalizeUIStateCTACopy(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface,
        explicitErrorMessage: String? = nil
    ) -> HealthIntelligenceUIStateCTACopy {
        HealthIntelligenceCardPresentationFactory.normalizeUIStateCTACopy(
            for: uiState,
            surface: surface,
            explicitErrorMessage: explicitErrorMessage
        )
    }

    static func connectCTACopy(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface,
        defaultCTATitle: String
    ) -> HealthIntelligenceConnectCTACopy? {
        HealthIntelligenceCardPresentationFactory.connectCTACopy(
            for: uiState,
            surface: surface,
            defaultCTATitle: defaultCTATitle
        )
    }

    static func normalizedActionFields(
        from action: NextBestAction
    ) -> (title: String, message: String?, ctaTitle: String?) {
        HealthIntelligenceCardPresentationFactory.normalizedActionFields(from: action)
    }

    // MARK: - Section-level helpers (policy delegates)

    static func fallbackMessage(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface
    ) -> String? {
        HealthIntelligenceCardPresentationFactory.fallbackMessage(for: uiState, surface: surface)
    }

    static func staleDataLabel(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface
    ) -> String? {
        HealthIntelligenceCardPresentationFactory.staleDataLabel(for: uiState, surface: surface)
    }

    static func partialSignalsNote(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface
    ) -> String? {
        HealthIntelligenceCardPresentationFactory.partialSignalsNote(for: uiState, surface: surface)
    }

    static func confidenceLabel(
        for recovery: RecoverySummary,
        uiState: HealthIntelligenceUIState?
    ) -> String? {
        HealthIntelligenceCardPresentationFactory.confidenceLabel(for: recovery, uiState: uiState)
    }

    // MARK: - Accessibility

    static func recoveryAccessibilityLabel(
        sectionTitle: String,
        content: HealthIntelligenceRecoveryCardContent
    ) -> String {
        HealthIntelligenceCardPresentationFactory.recoveryAccessibilityLabel(
            sectionTitle: sectionTitle,
            content: content
        )
    }

    static func workoutAccessibilityLabel(
        sectionTitle: String,
        content: HealthIntelligenceWorkoutCardContent
    ) -> String {
        HealthIntelligenceCardPresentationFactory.workoutAccessibilityLabel(
            sectionTitle: sectionTitle,
            content: content
        )
    }

    static func adaptiveNutritionAccessibilityLabel(
        sectionTitle: String,
        content: HealthIntelligenceAdaptiveNutritionContent
    ) -> String {
        HealthIntelligenceCardPresentationFactory.adaptiveNutritionAccessibilityLabel(
            sectionTitle: sectionTitle,
            content: content
        )
    }

    static func nextBestActionAccessibilityLabel(
        sectionTitle: String,
        title: String,
        message: String?,
        ctaTitle: String?
    ) -> String {
        HealthIntelligenceCardPresentationFactory.nextBestActionAccessibilityLabel(
            sectionTitle: sectionTitle,
            title: title,
            message: message,
            ctaTitle: ctaTitle
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
