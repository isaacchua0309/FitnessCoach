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
        trainingIntegrationState: TrainingIntegrationState = .notConnected,
        connectionRecord: HealthIntegrationConnectionRecord = .empty,
        cachedDayCount: Int = 0,
        errorMessage: String? = nil,
        syncPhase: HealthSyncPhase? = nil,
        lastSuccessfulLocalSyncAt: Date? = nil,
        baseline: HealthBaselineContext? = nil,
        isRemoteSyncCapabilityEnabled: Bool = false,
        remoteSyncConsentDecision: HealthSummarySyncConsentDecision = .notDetermined
    ) -> TodayHealthIntelligenceSectionState? {
        let input = sectionLoadingInput(
            snapshot: snapshot,
            isLoading: isLoading,
            isUIEnabled: isUIEnabled,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            trainingIntegrationState: trainingIntegrationState,
            connectionRecord: connectionRecord,
            cachedDayCount: cachedDayCount,
            errorMessage: errorMessage,
            syncPhase: syncPhase,
            lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
            baseline: baseline,
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: remoteSyncConsentDecision
        )

        guard input.isUIEnabled else { return nil }

        let classification = HealthIntelligenceSectionLoaderCore.classifySectionLoading(from: input)
        if classification.availability == .loading {
            if input.isLoading || input.syncPhase == .syncing {
                return loadingSection()
            }
            return loadingSection(uiState: HealthIntelligenceSectionLoaderCore.resolveUIState(from: input))
        }

        let uiState = HealthIntelligenceSectionLoaderCore.resolveUIState(from: input)
        let fallbackMessage = HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface)

        guard let snapshot else {
            let statusInput = HealthIntelligenceSectionLoaderCore.integrationStatusInput(
                availability: availability,
                trainingIntegrationState: trainingIntegrationState,
                connectionRecord: connectionRecord,
                snapshot: nil,
                baseline: baseline,
                cachedDayCount: cachedDayCount
            )
            return unavailableSection(
                uiState: uiState,
                nutritionProgress: nutritionProgress,
                integrationStatus: HealthIntegrationStatusResolver.resolve(statusInput),
                statusInput: statusInput,
                fallbackMessage: fallbackMessage
            )
        }

        let statusInput = HealthIntelligenceSectionLoaderCore.integrationStatusInput(
            availability: availability,
            trainingIntegrationState: trainingIntegrationState,
            connectionRecord: connectionRecord,
            snapshot: snapshot,
            baseline: baseline,
            cachedDayCount: cachedDayCount
        )

        return loadedSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            uiState: uiState,
            classification: classification,
            fallbackMessage: fallbackMessage,
            integrationStatus: HealthIntegrationStatusResolver.resolve(statusInput),
            signalAvailability: HealthIntegrationStatusResolver.resolveSignalAvailability(from: statusInput),
            statusInput: statusInput
        )
    }

    // MARK: - Recovery

    static func recoveryCard(
        from recovery: RecoverySummary,
        uiState: HealthIntelligenceUIState? = nil,
        staleDataLabel: String? = nil
    ) -> TodayRecoveryCardState {
        mapRecoveryCard(
            from: HealthIntelligencePresentationCore.buildRecoveryCardContent(
                from: recovery,
                uiState: uiState,
                staleDataLabel: staleDataLabel,
                surface: surface
            ),
            uiState: uiState
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

    // MARK: - Section assembly

    private static func loadedSection(
        snapshot: HealthIntelligenceSnapshot,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress,
        uiState: HealthIntelligenceUIState,
        classification: HealthIntelligenceSectionLoadingResult,
        fallbackMessage: String?,
        integrationStatus: HealthIntegrationStatus,
        signalAvailability: HealthSignalAvailability,
        statusInput: HealthIntegrationStatusInput
    ) -> TodayHealthIntelligenceSectionState {
        let staleLabel = classification.staleDataLabel
        let recoveryForCards = uiState.kind == .healthKitUnavailable ? RecoverySummary.unknown : snapshot.recovery
        let adaptiveNutritionCard = adaptiveNutritionCard(
            from: snapshot.nutritionAdjustment,
            nutritionProgress: nutritionProgress
        )

        return TodayHealthIntelligenceSectionState(
            recoveryCard: recoveryCard(
                from: recoveryForCards,
                uiState: uiState,
                staleDataLabel: staleLabel
            ),
            dailyMission: dailyMission(
                recovery: recoveryForCards,
                workout: snapshot.workout,
                nutritionProgress: nutritionProgress,
                nutritionAdjustment: snapshot.nutritionAdjustment,
                hasVisibleAdaptiveNutritionCard: adaptiveNutritionCard?.isVisible == true
            ),
            nextBestAction: supplementalActionIfNeeded(
                healthAction: resolvedNextBestAction(
                    snapshot: snapshot,
                    integrationStatus: integrationStatus,
                    signalAvailability: signalAvailability,
                    statusInput: statusInput
                ),
                uiState: uiState,
                integrationStatus: integrationStatus,
                statusInput: statusInput
            ),
            workoutCard: workoutCard(from: snapshot.workout, uiState: uiState),
            adaptiveNutritionCard: adaptiveNutritionCard,
            isLoading: false,
            fallbackMessage: fallbackMessage,
            uiState: uiState,
            staleDataLabel: staleLabel
        )
    }

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
        integrationStatus: HealthIntegrationStatus,
        statusInput: HealthIntegrationStatusInput,
        fallbackMessage: String?
    ) -> TodayHealthIntelligenceSectionState {
        TodayHealthIntelligenceSectionState(
            recoveryCard: placeholderRecoveryCard(for: uiState),
            dailyMission: dailyMission(
                recovery: .unknown,
                workout: nil,
                nutritionProgress: nutritionProgress
            ),
            nextBestAction: supplementalActionIfNeeded(
                healthAction: .hidden,
                uiState: uiState,
                integrationStatus: integrationStatus,
                statusInput: statusInput
            ),
            workoutCard: workoutCard(from: nil, uiState: uiState),
            adaptiveNutritionCard: nil,
            isLoading: false,
            fallbackMessage: fallbackMessage,
            uiState: uiState,
            staleDataLabel: nil
        )
    }

    // MARK: - Section loading input

    private static func sectionLoadingInput(
        snapshot: HealthIntelligenceSnapshot?,
        isLoading: Bool,
        isUIEnabled: Bool,
        availability: HealthDataAvailability?,
        isAppleHealthConnected: Bool,
        trainingIntegrationState: TrainingIntegrationState,
        connectionRecord: HealthIntegrationConnectionRecord,
        cachedDayCount: Int,
        errorMessage: String?,
        syncPhase: HealthSyncPhase?,
        lastSuccessfulLocalSyncAt: Date?,
        baseline: HealthBaselineContext?,
        isRemoteSyncCapabilityEnabled: Bool,
        remoteSyncConsentDecision: HealthSummarySyncConsentDecision
    ) -> HealthIntelligenceSectionLoadingInput {
        HealthIntelligenceSectionLoadingInput(
            isUIEnabled: isUIEnabled,
            isLoading: isLoading,
            snapshot: snapshot,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount > 0 ? cachedDayCount : (availability?.cachedDayCount ?? 0),
            errorMessage: errorMessage,
            syncPhase: syncPhase,
            lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
            baseline: baseline,
            surface: surface,
            trainingIntegrationState: trainingIntegrationState,
            connectionRecord: connectionRecord,
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: remoteSyncConsentDecision
        )
    }

    // MARK: - Next best action

    private static func supplementalActionIfNeeded(
        healthAction: TodayHealthNextBestActionState,
        uiState: HealthIntelligenceUIState,
        integrationStatus: HealthIntegrationStatus,
        statusInput: HealthIntegrationStatusInput
    ) -> TodayHealthNextBestActionState {
        guard !healthAction.isVisible else { return healthAction }

        if integrationStatus.requiresInitialConnection(
            hasPriorConnectionEvidence: statusInput.hasPriorConnectionEvidence
        ) {
            return TodayHealthIntegrationNextStepResolver.resolve(
                integrationStatus: integrationStatus,
                signalAvailability: HealthIntegrationStatusResolver.resolveSignalAvailability(from: statusInput),
                behavioralAction: .none,
                hasPriorConnectionEvidence: statusInput.hasPriorConnectionEvidence
            )
        }

        if integrationStatus.isConnected {
            return healthAction
        }

        switch uiState.primaryAction {
        case .connectAppleHealth, .manageHealthPermissions, .manageHealthDataSync:
            return supplementalActionState(
                title: uiState.title,
                message: uiState.message,
                ctaTitle: uiState.primaryActionTitle,
                destination: .connectHealth
            )
        case .askCoach:
            return supplementalActionState(
                title: uiState.secondaryActionTitle ?? uiState.title,
                message: uiState.message,
                ctaTitle: uiState.secondaryActionTitle,
                destination: .askCoach
            )
        case .retrySync, .refreshHealthData:
            return supplementalActionState(
                title: uiState.primaryActionTitle ?? uiState.title,
                message: uiState.message,
                ctaTitle: uiState.primaryActionTitle,
                destination: .refreshHealthData
            )
        case .continueLogging, .openPlan, .none:
            return healthAction
        }
    }

    private static func resolvedNextBestAction(
        snapshot: HealthIntelligenceSnapshot,
        integrationStatus: HealthIntegrationStatus,
        signalAvailability: HealthSignalAvailability,
        statusInput: HealthIntegrationStatusInput
    ) -> TodayHealthNextBestActionState {
        let behavioralAction = sanitizedBehavioralAction(snapshot.nextBestAction)
        return TodayHealthIntegrationNextStepResolver.resolve(
            integrationStatus: integrationStatus,
            signalAvailability: signalAvailability,
            behavioralAction: behavioralAction,
            hasPriorConnectionEvidence: statusInput.hasPriorConnectionEvidence
        )
    }

    private static func sanitizedBehavioralAction(_ action: NextBestAction) -> NextBestAction {
        guard action.reason != .connectHealth else {
            return .none
        }
        return action
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

    // MARK: - Shared card mapping

    private static func placeholderRecoveryCard(
        for uiState: HealthIntelligenceUIState
    ) -> TodayRecoveryCardState {
        guard let content = HealthIntelligencePresentationCore.placeholderRecoveryContent(
            for: uiState,
            surface: surface
        ) else {
            return .loading
        }
        return mapRecoveryCard(from: content, uiState: uiState)
    }

    private static func mapRecoveryCard(
        from content: HealthIntelligenceRecoveryCardContent,
        uiState: HealthIntelligenceUIState? = nil
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
            accessibilityLabel: recoveryAccessibilityLabel(from: content, uiState: uiState)
        )
    }

    private static func recoveryAccessibilityLabel(
        from content: HealthIntelligenceRecoveryCardContent,
        uiState: HealthIntelligenceUIState?
    ) -> String {
        if let uiState,
           uiState.kind == .unknown
            || uiState.kind == .notEnoughBaseline
            || uiState.kind == .remoteSyncDisabled {
            return "\(recoverySectionTitle). \(uiState.title). \(uiState.message)"
        }

        return HealthIntelligencePresentationCore.recoveryAccessibilityLabel(
            sectionTitle: recoverySectionTitle,
            content: content
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

    // MARK: - Daily mission

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
