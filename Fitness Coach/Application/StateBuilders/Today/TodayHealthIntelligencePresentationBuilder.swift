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
        isUIEnabled: Bool = HealthIntelligenceFeatureFlags.isUIEnabled,
        availability: HealthDataAvailability? = nil,
        isAppleHealthConnected: Bool = false,
        cachedDayCount: Int = 0,
        errorMessage: String? = nil,
        syncPhase: HealthSyncPhase? = nil,
        lastSuccessfulLocalSyncAt: Date? = nil,
        baseline: HealthBaselineContext? = nil,
        isRemoteSyncCapabilityEnabled: Bool = false,
        remoteSyncConsentDecision: HealthSummarySyncConsentDecision = .notDetermined
    ) -> TodayHealthIntelligenceSectionState? {
        guard isUIEnabled else { return nil }

        if isLoading {
            return loadingSection()
        }

        let presentationContext = presentationContext(
            snapshot: snapshot,
            isLoading: false,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount,
            errorMessage: errorMessage,
            syncPhase: syncPhase
        )

        let uiContext = HealthIntelligenceUIContext.from(
            presentationContext: presentationContext,
            baseline: baseline,
            lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: remoteSyncConsentDecision,
            surface: .today
        )

        let uiState = HealthIntelligenceUIStateMapper.resolve(uiContext)

        if uiState.kind == .loading {
            return loadingSection(uiState: uiState)
        }

        guard let snapshot else {
            return unavailableSection(
                uiState: uiState,
                nutritionProgress: nutritionProgress,
                presentationContext: presentationContext
            )
        }

        return loadedSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            uiState: uiState,
            presentationContext: presentationContext
        )
    }

    // MARK: - Section assembly

    private static func loadedSection(
        snapshot: HealthIntelligenceSnapshot,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress,
        uiState: HealthIntelligenceUIState,
        presentationContext: HealthIntelligencePresentationContext
    ) -> TodayHealthIntelligenceSectionState {
        let staleLabel = staleDataLabel(for: uiState)
        let recoveryCard = recoveryCard(
            from: snapshot.recovery,
            uiState: uiState,
            staleDataLabel: staleLabel
        )
        let adaptiveNutritionCard = adaptiveNutritionCard(
            from: snapshot.nutritionAdjustment,
            nutritionProgress: nutritionProgress
        )
        let dailyMission = dailyMission(
            recovery: snapshot.recovery,
            workout: snapshot.workout,
            nutritionProgress: nutritionProgress,
            nutritionAdjustment: snapshot.nutritionAdjustment,
            hasVisibleAdaptiveNutritionCard: adaptiveNutritionCard?.isVisible == true
        )
        let mappedNextBestAction = nextBestAction(from: snapshot.nextBestAction)
        let workoutCard = workoutCard(from: snapshot.workout, uiState: uiState)

        return TodayHealthIntelligenceSectionState(
            recoveryCard: recoveryCard,
            dailyMission: dailyMission,
            nextBestAction: supplementalActionIfNeeded(
                healthAction: mappedNextBestAction,
                uiState: uiState
            ),
            workoutCard: workoutCard,
            adaptiveNutritionCard: adaptiveNutritionCard,
            isLoading: false,
            fallbackMessage: fallbackMessage(for: uiState),
            uiState: uiState,
            staleDataLabel: staleLabel
        )
    }

    // MARK: - Recovery

    static func recoveryCard(
        from recovery: RecoverySummary,
        uiState: HealthIntelligenceUIState? = nil,
        staleDataLabel: String? = nil
    ) -> TodayRecoveryCardState {
        if let uiState, uiState.kind == .healthKitUnavailable {
            return safeUnavailableRecoveryCard(uiState: uiState)
        }

        let phase = recoveryPhase(from: recovery)
        let confidenceNote = mergedConfidenceNote(
            recoveryConfidence: confidenceNote(for: recovery.confidence),
            uiState: uiState
        )
        let missingDataNote = missingDataNote(for: recovery)

        let title = recovery.title
        let subtitle = recoverySubtitle(from: recovery)
        let trainingGuidance = sanitizedGuidance(recovery.recommendedTraining)
        let nutritionGuidance = sanitizedGuidance(recovery.recommendedNutrition)

        return TodayRecoveryCardState(
            phase: phase,
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle,
            title: title,
            subtitle: subtitle,
            trainingGuidance: trainingGuidance,
            nutritionGuidance: nutritionGuidance,
            confidenceNote: confidenceNote,
            missingDataNote: missingDataNote,
            staleDataLabel: staleDataLabel,
            accessibilityLabel: recoveryAccessibilityLabel(
                title: title,
                subtitle: subtitle,
                trainingGuidance: trainingGuidance,
                nutritionGuidance: nutritionGuidance,
                confidenceNote: confidenceNote,
                missingDataNote: missingDataNote,
                staleDataLabel: staleDataLabel
            )
        )
    }

    /// Backward-compatible entry point for unit tests and direct recovery mapping.
    static func recoveryCard(from recovery: RecoverySummary) -> TodayRecoveryCardState {
        recoveryCard(from: recovery, uiState: nil, staleDataLabel: nil)
    }

    // MARK: - Workout

    static func workoutCard(
        from workout: WorkoutSummary?,
        uiState: HealthIntelligenceUIState? = nil
    ) -> TodayHealthWorkoutCardState? {
        if let workout, workout.hasWorkout {
            return completedWorkoutCard(from: workout)
        }

        if uiState?.kind == .noWorkoutHistory {
            return emptyWorkoutCard()
        }

        return nil
    }

    /// Backward-compatible entry point for unit tests.
    static func workoutCard(from workout: WorkoutSummary?) -> TodayHealthWorkoutCardState? {
        workoutCard(from: workout, uiState: nil)
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
        nutritionProgress: TodayHealthIntelligenceNutritionProgress,
        nutritionAdjustment: AdaptiveNutritionSummary = .none,
        hasVisibleAdaptiveNutritionCard: Bool = false
    ) -> TodayDailyMissionState {
        let headline = dailyMissionHeadline(for: recovery.status)
        var detailLines = dailyMissionRecoveryDetail(for: recovery)
        detailLines.append(contentsOf: dailyMissionWorkoutDetail(for: workout))
        detailLines.append(
            contentsOf: dailyMissionNutritionDetail(
                from: nutritionProgress,
                nutritionAdjustment: nutritionAdjustment,
                suppressOverlapWithAdaptiveCard: hasVisibleAdaptiveNutritionCard
            )
        )

        let focusSummary = dailyMissionFocusSummary(
            recovery: recovery,
            workout: workout,
            nutritionProgress: nutritionProgress,
            nutritionAdjustment: nutritionAdjustment,
            suppressOverlapWithAdaptiveCard: hasVisibleAdaptiveNutritionCard
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

    private static func loadingSection(
        uiState: HealthIntelligenceUIState? = nil
    ) -> TodayHealthIntelligenceSectionState {
        TodayHealthIntelligenceSectionState(
            recoveryCard: .loading,
            dailyMission: .loading,
            nextBestAction: .loading,
            workoutCard: nil,
            adaptiveNutritionCard: nil,
            isLoading: true,
            fallbackMessage: nil,
            uiState: uiState,
            staleDataLabel: nil
        )
    }

    private static func unavailableSection(
        uiState: HealthIntelligenceUIState,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress,
        presentationContext: HealthIntelligencePresentationContext
    ) -> TodayHealthIntelligenceSectionState {
        let recoveryCard = placeholderRecoveryCard(for: uiState)
        let dailyMission = dailyMission(
            recovery: .unknown,
            workout: nil,
            nutritionProgress: nutritionProgress
        )

        return TodayHealthIntelligenceSectionState(
            recoveryCard: recoveryCard,
            dailyMission: dailyMission,
            nextBestAction: supplementalActionIfNeeded(
                healthAction: .hidden,
                uiState: uiState
            ),
            workoutCard: uiState.kind == .noWorkoutHistory ? emptyWorkoutCard() : nil,
            adaptiveNutritionCard: nil,
            isLoading: false,
            fallbackMessage: fallbackMessage(for: uiState),
            uiState: uiState,
            staleDataLabel: nil
        )
    }

    private static func presentationContext(
        snapshot: HealthIntelligenceSnapshot?,
        isLoading: Bool,
        availability: HealthDataAvailability?,
        isAppleHealthConnected: Bool,
        cachedDayCount: Int,
        errorMessage: String?,
        syncPhase: HealthSyncPhase? = nil
    ) -> HealthIntelligencePresentationContext {
        HealthIntelligencePresentationContext(
            isLoading: isLoading,
            explicitErrorMessage: errorMessage,
            syncPhase: syncPhase,
            availability: availability,
            snapshot: snapshot,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount
        )
    }

    private static func fallbackMessage(for uiState: HealthIntelligenceUIState) -> String? {
        switch uiState.kind {
        case .ready, .loading, .staleData:
            return nil
        case .partialPermission, .noSleepData, .noHeartData, .noWorkoutHistory:
            return uiState.canShowInsight ? nil : uiState.message
        case .syncFailed:
            return uiState.canShowInsight ? nil : uiState.message
        case .remoteSyncDisabled:
            return uiState.canShowInsight ? nil : uiState.message
        case .noHealthPermission, .healthKitUnavailable, .notEnoughBaseline, .unknown:
            return uiState.message
        }
    }

    private static func staleDataLabel(for uiState: HealthIntelligenceUIState) -> String? {
        switch uiState.kind {
        case .staleData:
            return FormaProductCopy.Today.HealthIntelligence.staleDataLabel
        case .syncFailed where uiState.canShowInsight:
            return FormaProductCopy.Today.HealthIntelligence.syncFailedWithCacheLabel
        default:
            return nil
        }
    }

    private static func supplementalActionIfNeeded(
        healthAction: TodayHealthNextBestActionState,
        uiState: HealthIntelligenceUIState
    ) -> TodayHealthNextBestActionState {
        guard !healthAction.isVisible else { return healthAction }

        let copy = FormaProductCopy.HealthIntelligence.UIState.message(
            for: uiState.kind,
            surface: .today,
            explicitErrorMessage: nil
        )

        switch uiState.primaryAction {
        case .connectAppleHealth, .manageHealthPermissions, .manageHealthDataSync:
            return supplementalActionState(
                title: copy.primaryActionTitle ?? copy.title,
                message: uiState.message,
                ctaTitle: copy.primaryActionTitle,
                destination: .connectHealth
            )
        case .askCoach:
            return supplementalActionState(
                title: copy.secondaryActionTitle ?? copy.title,
                message: uiState.message,
                ctaTitle: copy.secondaryActionTitle,
                destination: .askCoach
            )
        case .retrySync, .refreshHealthData:
            return supplementalActionState(
                title: copy.primaryActionTitle ?? copy.title,
                message: uiState.message,
                ctaTitle: copy.primaryActionTitle,
                destination: .connectHealth
            )
        case .continueLogging, .openPlan, .none:
            return healthAction
        }
    }

    private static func supplementalActionState(
        title: String,
        message: String,
        ctaTitle: String?,
        destination: TodayHealthNextBestActionDestination
    ) -> TodayHealthNextBestActionState {
        TodayHealthNextBestActionState(
            isVisible: true,
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.NextAction.sectionTitle,
            title: title,
            message: message,
            ctaTitle: ctaTitle,
            destination: destination,
            accessibilityLabel: nextBestActionAccessibilityLabel(
                title: title,
                message: message,
                ctaTitle: ctaTitle
            )
        )
    }

    private static func placeholderRecoveryCard(
        for uiState: HealthIntelligenceUIState
    ) -> TodayRecoveryCardState {
        switch uiState.kind {
        case .healthKitUnavailable:
            return safeUnavailableRecoveryCard(uiState: uiState)
        case .noHealthPermission:
            return TodayRecoveryCardState(
                phase: .unknown,
                sectionTitle: FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle,
                title: uiState.title,
                subtitle: uiState.message,
                trainingGuidance: nil,
                nutritionGuidance: nil,
                confidenceNote: nil,
                missingDataNote: nil,
                staleDataLabel: nil,
                accessibilityLabel: "\(FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle). \(uiState.title). \(uiState.message)"
            )
        case .unknown, .notEnoughBaseline, .remoteSyncDisabled:
            return TodayRecoveryCardState(
                phase: .unknown,
                sectionTitle: FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle,
                title: uiState.title.isEmpty
                    ? FormaProductCopy.Today.HealthIntelligence.DailyMission.unknownHeadline
                    : uiState.title,
                subtitle: uiState.message,
                trainingGuidance: nil,
                nutritionGuidance: nil,
                confidenceNote: uiState.confidenceLabel,
                missingDataNote: nil,
                staleDataLabel: nil,
                accessibilityLabel: "\(FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle). \(uiState.title). \(uiState.message)"
            )
        default:
            return .loading
        }
    }

    private static func safeUnavailableRecoveryCard(
        uiState: HealthIntelligenceUIState
    ) -> TodayRecoveryCardState {
        TodayRecoveryCardState(
            phase: .unknown,
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle,
            title: uiState.title,
            subtitle: uiState.message,
            trainingGuidance: nil,
            nutritionGuidance: nil,
            confidenceNote: nil,
            missingDataNote: nil,
            staleDataLabel: nil,
            accessibilityLabel: "\(FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle). \(uiState.title). \(uiState.message)"
        )
    }

    private static func completedWorkoutCard(from workout: WorkoutSummary) -> TodayHealthWorkoutCardState {
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

    private static func emptyWorkoutCard() -> TodayHealthWorkoutCardState {
        let title = FormaProductCopy.Today.HealthIntelligence.Workout.emptyTitle
        let subtitle = FormaProductCopy.Today.HealthIntelligence.Workout.emptyMessage

        return TodayHealthWorkoutCardState(
            phase: .empty,
            sectionTitle: FormaProductCopy.Today.HealthIntelligence.Workout.sectionTitle,
            title: title,
            subtitle: subtitle,
            nutritionTip: nil,
            hydrationTip: nil,
            accessibilityLabel: workoutAccessibilityLabel(
                title: title,
                subtitle: subtitle,
                nutritionTip: nil,
                hydrationTip: nil
            )
        )
    }

    private static func mergedConfidenceNote(
        recoveryConfidence: String?,
        uiState: HealthIntelligenceUIState?
    ) -> String? {
        guard let uiState else { return recoveryConfidence }

        switch uiState.kind {
        case .partialPermission, .noSleepData, .noHeartData, .notEnoughBaseline, .staleData:
            return uiState.confidenceLabel ?? recoveryConfidence
        case .ready:
            return recoveryConfidence ?? uiState.confidenceLabel
        default:
            return recoveryConfidence
        }
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
            return FormaProductCopy.HealthIntelligence.limitedEstimateLabel
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
        if let training = sanitizedGuidance(recovery.recommendedTraining) {
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
        from progress: TodayHealthIntelligenceNutritionProgress,
        nutritionAdjustment: AdaptiveNutritionSummary,
        suppressOverlapWithAdaptiveCard: Bool
    ) -> [String] {
        var lines: [String] = []

        let suppressProtein = suppressOverlapWithAdaptiveCard
            && adaptiveCardWouldShowProteinGuidance(from: nutritionAdjustment, nutritionProgress: progress)
        let suppressWater = suppressOverlapWithAdaptiveCard
            && adaptiveCardWouldShowWaterGuidance(from: nutritionAdjustment, nutritionProgress: progress)

        if let calories = progress.calorieRemaining, progress.hasCalorieTarget {
            lines.append(FormaProductCopy.Today.HealthIntelligence.DailyMission.caloriesRemaining(calories))
        }
        if !suppressProtein,
           let protein = progress.proteinRemainingGrams,
           progress.hasProteinTarget,
           protein > 0 {
            lines.append(FormaProductCopy.Today.HealthIntelligence.DailyMission.proteinRemaining(protein))
        }
        if !suppressWater,
           let water = progress.waterRemainingMl,
           progress.hasWaterTarget,
           water > 0 {
            lines.append(FormaProductCopy.Today.HealthIntelligence.DailyMission.waterRemaining(water))
        }

        return lines
    }

    private static func dailyMissionFocusSummary(
        recovery: RecoverySummary,
        workout: WorkoutSummary?,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress,
        nutritionAdjustment: AdaptiveNutritionSummary,
        suppressOverlapWithAdaptiveCard: Bool
    ) -> String? {
        if recovery.status == .low {
            return sanitizedGuidance(recovery.recommendedNutrition)
        }
        if let workout, workout.hasWorkout, !workout.nutritionAdvice.isEmpty {
            return sanitizedGuidance(workout.nutritionAdvice)
        }
        let suppressProtein = suppressOverlapWithAdaptiveCard
            && adaptiveCardWouldShowProteinGuidance(from: nutritionAdjustment, nutritionProgress: nutritionProgress)
        if !suppressProtein,
           nutritionProgress.hasProteinTarget,
           let protein = nutritionProgress.proteinRemainingGrams,
           protein > 0 {
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.proteinRemaining(protein)
        }
        return nil
    }

    private static func adaptiveCardWouldShowProteinGuidance(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress
    ) -> Bool {
        proteinGuidance(from: summary, nutritionProgress: nutritionProgress) != nil
    }

    private static func adaptiveCardWouldShowWaterGuidance(
        from summary: AdaptiveNutritionSummary,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress
    ) -> Bool {
        waterGuidance(from: summary, nutritionProgress: nutritionProgress) != nil
    }

    private static func recoverySubtitle(from recovery: RecoverySummary) -> String? {
        if shouldPreferLimitedRecoveryWording(for: recovery) {
            return limitedRecoveryExplanation(for: recovery)
        }

        if let sanitized = HealthIntelligencePresentationTextSanitizer.sanitize(recovery.explanation) {
            return sanitized
        }

        if let title = HealthIntelligencePresentationTextSanitizer.sanitize(recovery.title) {
            return title
        }

        return statusBasedRecoveryExplanation(for: recovery)
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
            return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryMissingSignals
        }
        if recovery.status == .unknown {
            return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryUnavailable
        }
        return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryPartialSignals
    }

    private static func statusBasedRecoveryExplanation(for recovery: RecoverySummary) -> String? {
        switch recovery.status {
        case .ready:
            return FormaProductCopy.Today.HealthIntelligence.Recovery.readyExplanation
        case .moderate:
            return FormaProductCopy.Today.HealthIntelligence.Recovery.moderateExplanation
        case .low:
            return FormaProductCopy.Today.HealthIntelligence.Recovery.lowExplanation
        case .unknown:
            return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryUnavailable
        }
    }

    private static func hasMissingHeartOrSleepSignals(_ signals: Set<RecoveryMissingSignal>) -> Bool {
        signals.contains(.sleep)
            || signals.contains(.hrv)
            || signals.contains(.restingHeartRate)
    }

    private static func sanitizedGuidance(_ value: String) -> String? {
        guard let trimmed = trimmed(value) else { return nil }
        return HealthIntelligencePresentationTextSanitizer.sanitize(trimmed) ?? trimmed
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
        missingDataNote: String?,
        staleDataLabel: String? = nil
    ) -> String {
        [
            FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle,
            title,
            subtitle,
            trainingGuidance,
            nutritionGuidance,
            confidenceNote,
            missingDataNote,
            staleDataLabel
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
