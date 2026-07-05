//
//  TodayHealthIntelligencePresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Maps HealthIntelligenceSnapshot into Today Health Intelligence presentation state.
//  Pure deterministic mapping; no SwiftUI or HealthKit.
//

import Foundation

enum TodayHealthIntelligencePresentationBuilder {

    private static let surface: HealthIntelligenceSurface = .today
    private static let recoverySectionTitle = FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle
    private static let workoutSectionTitle = FormaProductCopy.Today.HealthIntelligence.Workout.sectionTitle
    private static let adaptiveNutritionSectionTitle = FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.sectionTitle
    private static let nextActionSectionTitle = FormaProductCopy.Today.HealthIntelligence.NextAction.sectionTitle
    private static let dailyMissionSectionTitle = FormaProductCopy.Today.HealthIntelligence.DailyMission.sectionTitle

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

        let presentationContext = HealthIntelligencePresentationCore.presentationContext(
            snapshot: snapshot,
            isLoading: false,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount,
            errorMessage: errorMessage,
            syncPhase: syncPhase
        )

        let uiState = HealthIntelligencePresentationCore.resolveUIState(
            from: HealthIntelligenceUIResolutionInput(
                presentationContext: presentationContext,
                baseline: baseline,
                lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
                isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
                remoteSyncConsentDecision: remoteSyncConsentDecision,
                surface: surface
            )
        )

        if uiState.kind == .loading {
            return loadingSection(uiState: uiState)
        }

        guard let snapshot else {
            return unavailableSection(
                uiState: uiState,
                nutritionProgress: nutritionProgress
            )
        }

        return loadedSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            uiState: uiState
        )
    }

    // MARK: - Section assembly

    private static func loadedSection(
        snapshot: HealthIntelligenceSnapshot,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress,
        uiState: HealthIntelligenceUIState
    ) -> TodayHealthIntelligenceSectionState {
        let staleLabel = HealthIntelligencePresentationCore.staleDataLabel(for: uiState, surface: surface)
        let recoveryForCards = uiState.kind == .healthKitUnavailable ? RecoverySummary.unknown : snapshot.recovery
        let recoveryCard = recoveryCard(
            from: recoveryForCards,
            uiState: uiState,
            staleDataLabel: staleLabel
        )
        let adaptiveNutritionCard = adaptiveNutritionCard(
            from: snapshot.nutritionAdjustment,
            nutritionProgress: nutritionProgress
        )
        let dailyMission = dailyMission(
            recovery: recoveryForCards,
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
            fallbackMessage: HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
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
            return mapRecoveryCard(
                from: HealthIntelligencePresentationCore.unavailableRecoveryContent(
                    uiState: uiState,
                    surface: surface
                )
            )
        }

        return mapRecoveryCard(
            from: HealthIntelligencePresentationCore.buildRecoveryCardContent(
                from: recovery,
                uiState: uiState,
                staleDataLabel: staleDataLabel,
                surface: surface
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
        guard let content = HealthIntelligencePresentationCore.buildWorkoutCardContent(
            from: workout,
            uiState: uiState
        ) else {
            return nil
        }
        return mapWorkoutCard(from: content)
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
        guard let content = HealthIntelligencePresentationCore.buildAdaptiveNutritionContent(
            from: summary,
            nutritionProgress: .from(nutritionProgress)
        ) else {
            return nil
        }
        return mapAdaptiveNutritionCard(from: content)
    }

    // MARK: - Next best action

    static func nextBestAction(from action: NextBestAction) -> TodayHealthNextBestActionState {
        guard HealthIntelligencePresentationCore.isVisibleHealthAction(action) else {
            return .hidden
        }

        let fields = HealthIntelligencePresentationCore.normalizedActionFields(from: action)
        let destination = mapDestination(action.destination, reason: action.reason)

        return TodayHealthNextBestActionState(
            isVisible: true,
            sectionTitle: nextActionSectionTitle,
            title: fields.title,
            message: fields.message,
            ctaTitle: fields.ctaTitle?.isEmpty == false ? fields.ctaTitle : nil,
            destination: destination,
            accessibilityLabel: HealthIntelligencePresentationCore.nextBestActionAccessibilityLabel(
                sectionTitle: nextActionSectionTitle,
                title: fields.title,
                message: fields.message,
                ctaTitle: fields.ctaTitle
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
            sectionTitle: dailyMissionSectionTitle,
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
        nutritionProgress: TodayHealthIntelligenceNutritionProgress
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
            workoutCard: workoutCard(from: nil, uiState: uiState),
            adaptiveNutritionCard: nil,
            isLoading: false,
            fallbackMessage: HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
            uiState: uiState,
            staleDataLabel: nil
        )
    }

    private static func supplementalActionIfNeeded(
        healthAction: TodayHealthNextBestActionState,
        uiState: HealthIntelligenceUIState
    ) -> TodayHealthNextBestActionState {
        guard !healthAction.isVisible else { return healthAction }

        let copy = HealthIntelligencePresentationCore.normalizeUIStateCTACopy(
            for: uiState,
            surface: surface
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
            sectionTitle: nextActionSectionTitle,
            title: title,
            message: message,
            ctaTitle: ctaTitle,
            destination: destination,
            accessibilityLabel: HealthIntelligencePresentationCore.nextBestActionAccessibilityLabel(
                sectionTitle: nextActionSectionTitle,
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
            return mapRecoveryCard(
                from: HealthIntelligencePresentationCore.unavailableRecoveryContent(
                    uiState: uiState,
                    surface: surface
                )
            )
        case .noHealthPermission:
            return TodayRecoveryCardState(
                phase: .unknown,
                sectionTitle: recoverySectionTitle,
                title: uiState.title,
                subtitle: uiState.message,
                trainingGuidance: nil,
                nutritionGuidance: nil,
                confidenceNote: nil,
                missingDataNote: nil,
                staleDataLabel: nil,
                accessibilityLabel: "\(recoverySectionTitle). \(uiState.title). \(uiState.message)"
            )
        case .unknown, .notEnoughBaseline, .remoteSyncDisabled:
            let title = uiState.title.isEmpty
                ? FormaProductCopy.Today.HealthIntelligence.DailyMission.unknownHeadline
                : uiState.title
            return TodayRecoveryCardState(
                phase: .unknown,
                sectionTitle: recoverySectionTitle,
                title: title,
                subtitle: uiState.message,
                trainingGuidance: nil,
                nutritionGuidance: nil,
                confidenceNote: uiState.confidenceLabel,
                missingDataNote: nil,
                staleDataLabel: nil,
                accessibilityLabel: "\(recoverySectionTitle). \(uiState.title). \(uiState.message)"
            )
        default:
            return .loading
        }
    }

    private static func mapRecoveryCard(
        from content: HealthIntelligenceRecoveryCardContent
    ) -> TodayRecoveryCardState {
        TodayRecoveryCardState(
            phase: todayPhase(from: content.phase),
            sectionTitle: recoverySectionTitle,
            title: content.title,
            subtitle: content.subtitle,
            trainingGuidance: content.trainingGuidance,
            nutritionGuidance: content.nutritionGuidance,
            confidenceNote: content.confidenceNote,
            missingDataNote: content.missingDataNote,
            staleDataLabel: content.staleDataLabel,
            accessibilityLabel: HealthIntelligencePresentationCore.recoveryAccessibilityLabel(
                sectionTitle: recoverySectionTitle,
                content: content
            )
        )
    }

    private static func mapWorkoutCard(
        from content: HealthIntelligenceWorkoutCardContent
    ) -> TodayHealthWorkoutCardState {
        TodayHealthWorkoutCardState(
            phase: todayWorkoutPhase(from: content.phase),
            sectionTitle: workoutSectionTitle,
            title: content.title,
            subtitle: content.subtitle,
            nutritionTip: content.nutritionTip,
            hydrationTip: content.hydrationTip,
            accessibilityLabel: HealthIntelligencePresentationCore.workoutAccessibilityLabel(
                sectionTitle: workoutSectionTitle,
                content: content
            )
        )
    }

    private static func mapAdaptiveNutritionCard(
        from content: HealthIntelligenceAdaptiveNutritionContent
    ) -> TodayAdaptiveNutritionCardState {
        TodayAdaptiveNutritionCardState(
            isVisible: content.isVisible,
            sectionTitle: adaptiveNutritionSectionTitle,
            title: content.title,
            subtitle: content.subtitle,
            proteinGuidance: content.proteinGuidance,
            calorieGuidance: content.calorieGuidance,
            waterGuidance: content.waterGuidance,
            confidenceNote: content.confidenceNote,
            accessibilityLabel: HealthIntelligencePresentationCore.adaptiveNutritionAccessibilityLabel(
                sectionTitle: adaptiveNutritionSectionTitle,
                content: content
            )
        )
    }

    private static func todayPhase(
        from phase: HealthIntelligenceRecoveryPhase
    ) -> TodayRecoveryCardPhase {
        switch phase {
        case .ready: return .ready
        case .moderate: return .moderate
        case .low: return .low
        case .unknown: return .unknown
        case .limitedEstimate: return .limitedEstimate
        }
    }

    private static func todayWorkoutPhase(
        from phase: HealthIntelligenceWorkoutCardPhase
    ) -> TodayHealthWorkoutCardPhase {
        switch phase {
        case .completed: return .completed
        case .empty: return .empty
        case .hidden: return .unknown
        }
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
        if let training = HealthIntelligencePresentationCore.sanitizedGuidance(recovery.recommendedTraining) {
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
        let nutritionInput = HealthIntelligenceNutritionProgressInput.from(progress)
        var lines: [String] = []

        let suppressProtein = suppressOverlapWithAdaptiveCard
            && HealthIntelligencePresentationCore.adaptiveCardWouldShowProteinGuidance(
                from: nutritionAdjustment,
                nutritionProgress: nutritionInput
            )
        let suppressWater = suppressOverlapWithAdaptiveCard
            && HealthIntelligencePresentationCore.adaptiveCardWouldShowWaterGuidance(
                from: nutritionAdjustment,
                nutritionProgress: nutritionInput
            )

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
            return HealthIntelligencePresentationCore.sanitizedGuidance(recovery.recommendedNutrition)
        }
        if let workout, workout.hasWorkout, !workout.nutritionAdvice.isEmpty {
            return HealthIntelligencePresentationCore.sanitizedGuidance(workout.nutritionAdvice)
        }
        let nutritionInput = HealthIntelligenceNutritionProgressInput.from(nutritionProgress)
        let suppressProtein = suppressOverlapWithAdaptiveCard
            && HealthIntelligencePresentationCore.adaptiveCardWouldShowProteinGuidance(
                from: nutritionAdjustment,
                nutritionProgress: nutritionInput
            )
        if !suppressProtein,
           nutritionProgress.hasProteinTarget,
           let protein = nutritionProgress.proteinRemainingGrams,
           protein > 0 {
            return FormaProductCopy.Today.HealthIntelligence.DailyMission.proteinRemaining(protein)
        }
        return nil
    }

    private static func dailyMissionAccessibilityLabel(
        headline: String,
        detailLines: [String],
        focusSummary: String?
    ) -> String {
        ([dailyMissionSectionTitle, headline] + detailLines + [focusSummary])
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }
}
