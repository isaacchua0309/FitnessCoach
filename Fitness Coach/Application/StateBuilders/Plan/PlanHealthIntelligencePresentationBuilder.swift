//
//  PlanHealthIntelligencePresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Maps Health Intelligence snapshot confidence and baselines into Plan presentation state.
//  Pure deterministic mapping; no SwiftUI, HealthKit, or repository types.
//

import Foundation

enum PlanHealthIntelligencePresentationBuilder {

    private static let surface: HealthIntelligenceSurface = .plan

    // MARK: - Section

    static func buildSection(
        input: PlanHealthIntelligenceBuildInput,
        calendar: Calendar = .current
    ) -> PlanHealthIntelligenceSectionState {
        if input.isLoading {
            return loadingSection()
        }

        let loadingInput = sectionLoadingInput(from: input)
        let classification = HealthIntelligenceSectionLoaderCore.classifySectionLoading(from: loadingInput)
        let uiState = HealthIntelligenceSectionLoaderCore.resolveUIState(from: loadingInput)
        let allSignals = healthSignals(from: input)
        let coreSignals = coreHealthSignals(from: input, allSignals: allSignals)
        let dataQuality = dataQuality(from: input, signals: allSignals)
        let confidenceCard = confidenceCard(from: input, dataQuality: dataQuality, uiState: uiState)
        let assumptions = assumptions(from: input, uiState: uiState)
        let missingDataActions = missingDataActions(from: input, coreSignals: coreSignals)

        return PlanHealthIntelligenceSectionState(
            confidenceCard: confidenceCard,
            assumptions: assumptions,
            dataQuality: dataQuality,
            coreSignals: coreSignals,
            missingDataActions: missingDataActions,
            isLoading: false,
            fallbackMessage: HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
            staleDataLabel: classification.staleDataLabel,
            uiState: uiState,
            accessibilityLabel: sectionAccessibilityLabel(
                confidenceCard: confidenceCard,
                assumptions: assumptions,
                dataQuality: dataQuality,
                missingDataActions: missingDataActions
            )
        )
    }

    static func buildSection(
        snapshot: HealthIntelligenceSnapshot,
        baselineContext: HealthBaselineContext,
        userPlan: UserPlanContext = UserPlanContext(),
        hasNutritionLogging: Bool = false,
        hasRecentWeightLog: Bool = false,
        healthAvailability: HealthDataAvailability? = nil,
        calendar: Calendar = .current
    ) -> PlanHealthIntelligenceSectionState {
        buildSection(
            input: .from(
                snapshot: snapshot,
                baselineContext: baselineContext,
                userPlan: userPlan,
                healthAvailability: healthAvailability,
                hasNutritionLogging: hasNutritionLogging,
                hasRecentWeightLog: hasRecentWeightLog
            ),
            calendar: calendar
        )
    }

    // MARK: - Confidence card

    static func confidenceCard(
        from input: PlanHealthIntelligenceBuildInput,
        dataQuality: PlanHealthDataQualityState,
        uiState: HealthIntelligenceUIState? = nil
    ) -> PlanHealthConfidenceCardState {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let confidence = degradedConfidence(from: input, dataQuality: dataQuality, uiState: uiState)
        let label = copy.confidenceLabel(for: confidence)
        let scorePercent = confidence.score > 0 ? Int((confidence.score * 100).rounded()) : nil
        let headline = copy.confidenceHeadline(label: label)
        let summary = copy.confidenceSummary(score: confidence.score, label: label)
        let reasons = confidenceReasons(from: input, label: label, uiState: uiState)

        return PlanHealthConfidenceCardState(
            phase: .loaded,
            sectionTitle: copy.confidenceSectionTitle,
            headline: headline,
            summary: summary,
            confidenceLabel: label,
            scorePercent: scorePercent,
            reasons: reasons,
            disclaimerLine: copy.disclaimer,
            accessibilityLabel: confidenceAccessibilityLabel(
                headline: headline,
                summary: summary,
                confidenceLabel: label,
                scorePercent: scorePercent,
                reasons: reasons,
                disclaimerLine: copy.disclaimer
            )
        )
    }

    // MARK: - Data quality

    static func dataQuality(
        from input: PlanHealthIntelligenceBuildInput,
        signals: [PlanHealthSignalState]? = nil
    ) -> PlanHealthDataQualityState {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let resolvedSignals = signals ?? healthSignals(from: input)
        let level = dataQualityLevel(for: input, signals: resolvedSignals)
        let explanation = copy.dataQualityExplanation(for: level, connection: input.healthConnection)

        return PlanHealthDataQualityState(
            sectionTitle: copy.dataQualitySectionTitle,
            qualityLevel: level,
            qualityLabel: copy.dataQualityLabel(for: level),
            explanation: explanation,
            signals: resolvedSignals,
            accessibilityLabel: dataQualityAccessibilityLabel(
                qualityLabel: copy.dataQualityLabel(for: level),
                explanation: explanation,
                signals: resolvedSignals
            )
        )
    }

    // MARK: - Assumptions

    static func assumptions(from input: PlanHealthIntelligenceBuildInput) -> PlanHealthAssumptionsState {
        assumptions(from: input, uiState: nil)
    }

    static func assumptions(
        from input: PlanHealthIntelligenceBuildInput,
        uiState: HealthIntelligenceUIState?
    ) -> PlanHealthAssumptionsState {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let items = assumptionItems(from: input, uiState: uiState)
        let summary: String

        if items.contains(where: { !$0.isLimited }) {
            summary = items.contains(where: { $0.isLimited })
                ? copy.assumptionsSummaryLimited
                : copy.assumptionsSummaryAvailable
        } else {
            summary = copy.assumptionsSummaryEmpty
        }

        return PlanHealthAssumptionsState(
            sectionTitle: copy.assumptionsSectionTitle,
            summary: summary,
            items: items,
            accessibilityLabel: assumptionsAccessibilityLabel(summary: summary, items: items)
        )
    }

    // MARK: - Missing data actions

    static func missingDataActions(
        from input: PlanHealthIntelligenceBuildInput
    ) -> [PlanHealthMissingDataActionState] {
        let coreSignals = coreHealthSignals(from: input)
        return missingDataActions(from: input, coreSignals: coreSignals)
    }

    static func missingDataActions(
        from input: PlanHealthIntelligenceBuildInput,
        coreSignals: [PlanHealthSignalState]
    ) -> [PlanHealthMissingDataActionState] {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let baseline = input.baselineContext
        var actions: [PlanHealthMissingDataActionState] = []

        if input.healthConnection == .disconnected {
            actions.append(
                missingDataAction(
                    id: "connect-health",
                    title: copy.actionConnectHealthTitle,
                    message: copy.actionConnectHealthMessage
                )
            )
        }

        if input.healthConnection == .partial {
            actions.append(
                missingDataAction(
                    id: "partial-permissions",
                    title: copy.actionPartialPermissionsTitle,
                    message: copy.actionPartialPermissionsMessage
                )
            )
        }

        let showsPartialPermissionsAction = input.healthConnection == .partial

        if baseline.missingSignals.contains(.sleep), !showsPartialPermissionsAction {
            actions.append(
                missingDataAction(
                    id: "sleep",
                    title: copy.actionEnableSleepTitle,
                    message: copy.actionEnableSleepMessage
                )
            )
        }

        if baseline.missingSignals.contains(.hrv)
            || baseline.missingSignals.contains(.restingHeartRate),
           !showsPartialPermissionsAction {
            actions.append(
                missingDataAction(
                    id: "heart-metrics",
                    title: copy.actionEnableHRVTitle,
                    message: copy.actionEnableHRVMessage
                )
            )
        }

        if !input.hasRecentWeightLog {
            actions.append(
                missingDataAction(
                    id: "weight",
                    title: copy.actionLogWeightTitle,
                    message: copy.actionLogWeightMessage
                )
            )
        }

        if !input.hasNutritionLogging {
            actions.append(
                missingDataAction(
                    id: "nutrition",
                    title: copy.actionLogNutritionTitle,
                    message: copy.actionLogNutritionMessage
                )
            )
        }

        return deduplicatedMissingActions(actions, coreSignals: coreSignals)
    }

    // MARK: - Core health signals

    static func coreHealthSignals(
        from input: PlanHealthIntelligenceBuildInput,
        allSignals: [PlanHealthSignalState]? = nil
    ) -> [PlanHealthSignalState] {
        let resolved = allSignals ?? healthSignals(from: input)
        let coreKinds: [PlanHealthSignalKind] = [
            .appleHealthWorkouts,
            .stepHistory,
            .sleep,
            .heartMetrics,
            .weight
        ]
        return coreKinds.compactMap { kind in
            resolved.first { $0.kind == kind }
        }
    }

    // MARK: - Section loading input

    private static func sectionLoadingInput(
        from input: PlanHealthIntelligenceBuildInput
    ) -> HealthIntelligenceSectionLoadingInput {
        HealthIntelligenceSectionLoadingInput(
            isUIEnabled: true,
            isLoading: input.isLoading,
            snapshot: syntheticSnapshot(from: input),
            availability: input.healthAvailability,
            isAppleHealthConnected: input.healthConnection != .disconnected,
            cachedDayCount: input.cachedDayCount > 0
                ? input.cachedDayCount
                : (input.healthAvailability?.cachedDayCount ?? 0),
            errorMessage: input.errorMessage,
            syncPhase: input.syncPhase,
            lastSuccessfulLocalSyncAt: input.lastSuccessfulLocalSyncAt,
            baseline: input.baselineContext,
            surface: surface,
            isRemoteSyncCapabilityEnabled: input.isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: input.remoteSyncConsentDecision
        )
    }

    private static func syntheticSnapshot(from input: PlanHealthIntelligenceBuildInput) -> HealthIntelligenceSnapshot {
        let hasWorkoutHistory = (input.baselineContext.workoutDays7d ?? 0) > 0
            || (input.baselineContext.workoutDays28d ?? 0) > 0

        return HealthIntelligenceSnapshot(
            date: input.baselineContext.targetDate,
            recovery: input.recovery ?? .unknown,
            workout: hasWorkoutHistory
                ? WorkoutSummary(
                    hasWorkout: true,
                    primaryWorkoutType: nil,
                    title: "Workout",
                    workoutCount: input.baselineContext.workoutDays7d ?? 1,
                    totalDurationMinutes: 0,
                    totalActiveCalories: nil,
                    intensity: .unknown,
                    demand: .unknown,
                    latestWorkoutStart: nil,
                    latestWorkoutEnd: nil,
                    nutritionAdvice: "",
                    hydrationAdviceMl: 0,
                    explanation: "",
                    confidence: .low,
                    sourceSummary: ""
                )
                : nil,
            activity: ActivitySummary(
                steps: (input.baselineContext.averageSteps7d ?? input.baselineContext.averageSteps28d)
                    .map { Int($0.rounded()) },
                activeEnergyKcal: input.baselineContext.averageActiveEnergy7d.map { Int($0.rounded()) },
                exerciseMinutes: nil
            ),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: input.planConfidence,
            nextBestAction: input.healthConnection == .disconnected
                ? NextBestAction(
                    id: "connect-health",
                    title: "Connect Apple Health",
                    message: "",
                    ctaTitle: "",
                    destination: .none,
                    priority: 1,
                    reason: .connectHealth,
                    createdAt: input.baselineContext.targetDate,
                    expiresAt: nil
                )
                : .none
        )
    }

    private static func degradedConfidence(
        from input: PlanHealthIntelligenceBuildInput,
        dataQuality: PlanHealthDataQualityState,
        uiState: HealthIntelligenceUIState?
    ) -> PlanHealthConfidence {
        if input.planConfidence.score > 0 {
            return input.planConfidence
        }

        switch dataQuality.qualityLevel {
        case .strong:
            return PlanHealthConfidence(score: 0.72, label: "Moderate")
        case .moderate:
            return PlanHealthConfidence(score: 0.55, label: "Moderate")
        case .limited:
            if input.healthConnection == .disconnected {
                return PlanHealthConfidence(score: 0, label: "Unknown")
            }
            return PlanHealthConfidence(score: 0.35, label: "Limited")
        }
    }

    private static func deduplicatedMissingActions(
        _ actions: [PlanHealthMissingDataActionState],
        coreSignals: [PlanHealthSignalState]
    ) -> [PlanHealthMissingDataActionState] {
        let missingCoreKinds = Set(
            coreSignals.filter { $0.status == .missing || $0.status == .limited }.map(\.kind)
        )

        return actions.filter { action in
            switch action.id {
            case "connect-health", "partial-permissions":
                return true
            case "sleep":
                return missingCoreKinds.contains(.sleep)
            case "heart-metrics":
                return missingCoreKinds.contains(.heartMetrics)
            case "weight":
                return missingCoreKinds.contains(.weight)
            case "nutrition":
                return true
            default:
                return true
            }
        }
    }

    // MARK: - Health signals

    private static func healthSignals(from input: PlanHealthIntelligenceBuildInput) -> [PlanHealthSignalState] {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let baseline = input.baselineContext

        let workoutDays = baseline.workoutDays7d ?? 0
        let stepsValue = baseline.averageSteps7d ?? baseline.averageSteps28d
        let energyValue = baseline.averageActiveEnergy7d ?? baseline.averageActiveEnergy28d
        let sleepMinutes = baseline.averageSleepDuration7d ?? baseline.averageSleepDuration28d
        let heartValue = copy.heartMetricsQualitativeValue(baseline: baseline)
        let workoutConsistency = copy.workoutConsistencyValue(days: workoutDays)
        let workoutStatus = workoutSignalStatus(from: input, workoutDays: workoutDays)
        let stepsStatus = signalStatus(
            for: .steps,
            baseline: baseline,
            hasValue: stepsValue != nil && (stepsValue ?? 0) > 0
        )
        let energyStatus = signalStatus(
            for: .activeEnergy,
            baseline: baseline,
            hasValue: energyValue != nil && (energyValue ?? 0) > 0
        )
        let sleepStatus = signalStatus(
            for: .sleep,
            baseline: baseline,
            hasValue: sleepMinutes != nil
        )
        let heartStatus = heartMetricsStatus(from: baseline)

        return [
            makeHealthSignal(
                kind: .appleHealthWorkouts,
                title: copy.signalAppleHealthWorkouts,
                value: input.healthConnection == .disconnected ? copy.signalUnavailable : workoutConsistency,
                detail: input.healthConnection == .partial ? copy.signalPartialSync : nil,
                status: workoutStatus,
                accessibilityValue: workoutConsistency
            ),
            makeHealthSignal(
                kind: .stepHistory,
                title: copy.signalStepHistory,
                value: copy.averageStepsPerDayValue(stepsValue),
                detail: baseline.averageSteps7d == nil && baseline.averageSteps28d != nil
                    ? copy.signalLimitedDetail
                    : nil,
                status: stepsStatus
            ),
            makeHealthSignal(
                kind: .activeEnergy,
                title: copy.signalActiveEnergy,
                value: copy.activeEnergyValue(energyValue),
                detail: baseline.averageActiveEnergy7d == nil && baseline.averageActiveEnergy28d != nil
                    ? copy.signalLimitedDetail
                    : nil,
                status: energyStatus
            ),
            makeHealthSignal(
                kind: .sleep,
                title: copy.signalSleep,
                value: copy.sleepAverageValue(minutes: sleepMinutes),
                detail: baseline.missingSignals.contains(.sleep) ? copy.signalLimitedDetail : nil,
                status: sleepStatus
            ),
            makeHealthSignal(
                kind: .heartMetrics,
                title: copy.signalHeartMetrics,
                value: heartValue,
                detail: baseline.missingSignals.contains(.hrv) || baseline.missingSignals.contains(.restingHeartRate)
                    ? copy.signalLimitedDetail
                    : nil,
                status: heartStatus
            ),
            makeHealthSignal(
                kind: .weight,
                title: copy.signalWeight,
                value: input.hasRecentWeightLog ? copy.signalWeightLogged : copy.signalUnavailable,
                detail: input.hasRecentWeightLog ? nil : copy.signalLimitedDetail,
                status: input.hasRecentWeightLog ? .available : .missing
            ),
            makeHealthSignal(
                kind: .nutritionLogs,
                title: copy.signalNutrition,
                value: input.hasNutritionLogging ? copy.signalNutritionLogged : copy.signalUnavailable,
                detail: input.hasNutritionLogging ? nil : copy.signalLimitedDetail,
                status: input.hasNutritionLogging ? .available : .missing
            )
        ]
    }

    private static func makeHealthSignal(
        kind: PlanHealthSignalKind,
        title: String,
        value: String,
        detail: String?,
        status: PlanHealthSignalStatus,
        accessibilityValue: String? = nil
    ) -> PlanHealthSignalState {
        PlanHealthSignalState(
            id: kind.rawValue,
            kind: kind,
            title: title,
            value: value,
            detail: detail,
            status: status,
            accessibilityLabel: signalAccessibilityLabel(
                title: title,
                value: accessibilityValue ?? value,
                detail: nil,
                status: status
            )
        )
    }

    private static func assumptionItems(
        from input: PlanHealthIntelligenceBuildInput,
        uiState: HealthIntelligenceUIState? = nil
    ) -> [PlanAssumptionItemState] {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let baseline = input.baselineContext
        let recovery = input.recovery ?? .unknown
        let stepsValue = baseline.averageSteps7d ?? baseline.averageSteps28d

        var rows: [(String, String, String, Bool)] = [
            (
                "average-steps",
                copy.assumptionAverageSteps,
                copy.averageStepsPerDayValue(stepsValue),
                stepsValue == nil || (stepsValue ?? 0) <= 0
            ),
            (
                "workouts-week",
                copy.assumptionWorkoutsPerWeek,
                copy.workoutsPerWeekValue(baseline.workoutDays7d),
                baseline.workoutDays7d == nil
            ),
            (
                "workout-load",
                copy.assumptionWorkoutLoad,
                copy.workoutLoadValue(baseline.averageWorkoutLoad28d),
                baseline.averageWorkoutLoad28d == nil || (baseline.averageWorkoutLoad28d ?? 0) <= 0
            ),
            (
                "recovery-trend",
                copy.assumptionRecoveryTrend,
                copy.recoveryTrendValue(score: recovery.score, status: recovery.status),
                recovery.status == .unknown && recovery.score == nil
            ),
            (
                "calorie-target",
                copy.assumptionCalorieTarget,
                copy.calorieTargetValue(input.userPlan.calorieTarget),
                input.userPlan.calorieTarget == nil
            ),
            (
                "protein-target",
                copy.assumptionProteinTarget,
                copy.proteinTargetValue(input.userPlan.proteinTargetGrams),
                input.userPlan.proteinTargetGrams == nil
            )
        ]

        if baseline.missingSignals.contains(.sleep) {
            rows.append((
                "sleep-assumption",
                copy.signalSleep,
                copy.signalUnavailable,
                true
            ))
        }

        if baseline.missingSignals.contains(.hrv)
            || baseline.missingSignals.contains(.restingHeartRate) {
            rows.append((
                "heart-assumption",
                copy.signalHeartMetrics,
                copy.signalUnavailable,
                true
            ))
        }

        if !input.hasRecentWeightLog {
            rows.append((
                "weight-assumption",
                copy.signalWeight,
                copy.signalUnavailable,
                true
            ))
        }

        if let uiState {
            for availability in uiState.missingSignals where availability.isMissing {
                let label = HealthIntelligencePresentationCopy.Plan.insightKindLabel(for: availability.kind)
                guard !rows.contains(where: { $0.1 == label }) else { continue }
                rows.append((
                    "missing-\(availability.kind.rawValue)",
                    label,
                    copy.signalUnavailable,
                    true
                ))
            }
        }

        return rows.map { makeAssumptionItem(id: $0.0, label: $0.1, value: $0.2, isLimited: $0.3) }
    }

    private static func makeAssumptionItem(
        id: String,
        label: String,
        value: String,
        isLimited: Bool
    ) -> PlanAssumptionItemState {
        let limitedSuffix = FormaProductCopy.PlanHealthIntelligencePresentation.limitedStatAccessibilitySuffix
        return PlanAssumptionItemState(
            id: id,
            label: label,
            value: value,
            isLimited: isLimited,
            accessibilityLabel: "\(label), \(value)" + (isLimited ? ". \(limitedSuffix)" : "")
        )
    }

    private static func confidenceReasons(
        from input: PlanHealthIntelligenceBuildInput,
        label: String,
        uiState: HealthIntelligenceUIState? = nil
    ) -> [String] {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let baseline = input.baselineContext
        var reasons: [String] = []

        if input.healthConnection != .disconnected,
           baseline.workoutDays7d != nil || baseline.availableSignals.contains(.workoutLoad) {
            reasons.append(copy.reasonWorkoutsSyncing)
        }

        if baseline.availableSignals.contains(.steps),
           let steps = baseline.averageSteps7d ?? baseline.averageSteps28d,
           steps > 0 {
            reasons.append(copy.reasonStepsConsistent)
        }

        if baseline.availableSignals.contains(.activeEnergy),
           let energy = baseline.averageActiveEnergy7d ?? baseline.averageActiveEnergy28d,
           energy > 0 {
            reasons.append(copy.reasonActiveEnergyAvailable)
        }

        if baseline.availableSignals.contains(.sleep),
           baseline.averageSleepDuration7d != nil || baseline.averageSleepDuration28d != nil {
            reasons.append(copy.reasonSleepAvailable)
        }

        if baseline.availableSignals.contains(.hrv) || baseline.availableSignals.contains(.restingHeartRate) {
            reasons.append(copy.reasonHeartSignalsAvailable)
        }

        if input.hasNutritionLogging {
            reasons.append(copy.reasonNutritionLogged)
        }

        if input.hasRecentWeightLog {
            reasons.append(copy.reasonWeightLogged)
        }

        if input.userPlan.calorieTarget != nil || input.userPlan.proteinTargetGrams != nil {
            reasons.append(copy.reasonTargetsSet)
        }

        if isLowConfidence(label: label, score: input.planConfidence.score) {
            reasons.append(contentsOf: improvementHints(from: input))
        }

        if input.healthConnection == .disconnected {
            reasons.append(copy.assumptionsSummaryEmpty)
        }

        if let uiState, !uiState.missingInsightKinds.isEmpty {
            let missingLabels = uiState.missingInsightKinds
                .map { HealthIntelligencePresentationCopy.Plan.insightKindLabel(for: $0) }
                .sorted()
            reasons.append("Optional improvements: \(missingLabels.joined(separator: ", ")).")
        }

        return reasons
    }

    private static func improvementHints(from input: PlanHealthIntelligenceBuildInput) -> [String] {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let baseline = input.baselineContext
        var hints: [String] = []

        if input.healthConnection == .disconnected {
            hints.append(copy.improveConnectHealth)
        }

        if input.healthConnection == .partial {
            hints.append(copy.improvePartialPermissions)
        }

        if baseline.missingSignals.contains(.sleep) {
            hints.append(copy.improveSleepSync)
        }

        if baseline.missingSignals.contains(.hrv) || baseline.missingSignals.contains(.restingHeartRate) {
            hints.append(copy.improveHeartSync)
        }

        if !input.hasRecentWeightLog {
            hints.append(copy.improveLogWeight)
        }

        if !input.hasNutritionLogging {
            hints.append(copy.improveLogNutrition)
        }

        return hints
    }

    private static func dataQualityLevel(
        for input: PlanHealthIntelligenceBuildInput,
        signals: [PlanHealthSignalState]
    ) -> PlanHealthDataQualityLevel {
        if input.healthConnection == .disconnected {
            return .limited
        }

        let availableCount = signals.filter { $0.status == .available }.count

        switch availableCount {
        case 5...:
            return .strong
        case 2...4:
            return .moderate
        default:
            return .limited
        }
    }

    private static func workoutSignalStatus(
        from input: PlanHealthIntelligenceBuildInput,
        workoutDays: Int
    ) -> PlanHealthSignalStatus {
        switch input.healthConnection {
        case .disconnected:
            return .missing
        case .partial:
            return baselineHasWorkoutData(input) ? .limited : .missing
        case .connected:
            if baselineHasWorkoutData(input) {
                return workoutDays > 0 ? .available : .limited
            }
            return .missing
        }
    }

    private static func baselineHasWorkoutData(_ input: PlanHealthIntelligenceBuildInput) -> Bool {
        input.baselineContext.workoutDays7d != nil
            || input.baselineContext.availableSignals.contains(.workoutLoad)
    }

    private static func heartMetricsStatus(from baseline: HealthBaselineContext) -> PlanHealthSignalStatus {
        let hasHRV = baseline.availableSignals.contains(.hrv) && baseline.averageHRV28d != nil
        let hasRestingHR = baseline.availableSignals.contains(.restingHeartRate)
            && baseline.averageRestingHeartRate28d != nil

        switch (hasHRV, hasRestingHR) {
        case (true, true):
            return .available
        case (true, false), (false, true):
            return .limited
        default:
            return baseline.missingSignals.contains(.hrv)
                || baseline.missingSignals.contains(.restingHeartRate)
                ? .missing
                : .limited
        }
    }

    private static func signalStatus(
        for signal: HealthBaselineSignal,
        baseline: HealthBaselineContext,
        hasValue: Bool
    ) -> PlanHealthSignalStatus {
        if baseline.missingSignals.contains(signal) {
            return hasValue ? .limited : .missing
        }
        if baseline.availableSignals.contains(signal), hasValue {
            return .available
        }
        return hasValue ? .limited : .missing
    }

    private static func isLowConfidence(label: String, score: Double) -> Bool {
        label == FormaProductCopy.PlanHealthIntelligencePresentation.confidenceLow
            || score > 0 && score < 0.45
    }

    private static func loadingSection() -> PlanHealthIntelligenceSectionState {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        return PlanHealthIntelligenceSectionState(
            confidenceCard: .loading,
            assumptions: PlanHealthAssumptionsState(
                sectionTitle: copy.assumptionsSectionTitle,
                summary: copy.loadingSubtitle,
                items: [],
                accessibilityLabel: copy.loadingAccessibilityLabel
            ),
            dataQuality: PlanHealthDataQualityState(
                sectionTitle: copy.dataQualitySectionTitle,
                qualityLevel: .limited,
                qualityLabel: copy.dataQualityLimitedLabel,
                explanation: copy.loadingSubtitle,
                signals: [],
                accessibilityLabel: copy.loadingAccessibilityLabel
            ),
            coreSignals: [],
            missingDataActions: [],
            isLoading: true,
            fallbackMessage: nil,
            staleDataLabel: nil,
            uiState: nil,
            accessibilityLabel: copy.loadingAccessibilityLabel
        )
    }

    // MARK: - Missing data action helpers

    private static func missingDataAction(
        id: String,
        title: String,
        message: String
    ) -> PlanHealthMissingDataActionState {
        PlanHealthMissingDataActionState(
            id: id,
            title: title,
            message: message,
            accessibilityLabel: HealthIntelligencePresentationAccessibility.joinedLabel(
                parts: [title, message]
            )
        )
    }

    // MARK: - Accessibility

    private static func confidenceAccessibilityLabel(
        headline: String,
        summary: String,
        confidenceLabel: String,
        scorePercent: Int?,
        reasons: [String],
        disclaimerLine: String
    ) -> String {
        HealthIntelligencePresentationAccessibility.joinedLabel(
            parts: [
                headline,
                summary,
                "Confidence, \(confidenceLabel)",
                scorePercent.map { "\($0) percent" },
                reasons.isEmpty ? nil : reasons.joined(separator: ". "),
                disclaimerLine
            ]
        )
    }

    private static func dataQualityAccessibilityLabel(
        qualityLabel: String,
        explanation: String,
        signals: [PlanHealthSignalState]
    ) -> String {
        HealthIntelligencePresentationAccessibility.cardLabel(
            sectionTitle: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualitySectionTitle,
            parts: [
                qualityLabel,
                explanation,
                signals.isEmpty ? nil : signals.map(\.accessibilityLabel).joined(separator: ". ")
            ]
        )
    }

    private static func assumptionsAccessibilityLabel(
        summary: String,
        items: [PlanAssumptionItemState]
    ) -> String {
        HealthIntelligencePresentationAccessibility.cardLabel(
            sectionTitle: FormaProductCopy.PlanHealthIntelligencePresentation.assumptionsSectionTitle,
            parts: [
                summary,
                items.isEmpty ? nil : items.map(\.accessibilityLabel).joined(separator: ". ")
            ]
        )
    }

    private static func signalAccessibilityLabel(
        title: String,
        value: String,
        detail: String?,
        status: PlanHealthSignalStatus
    ) -> String {
        HealthIntelligencePresentationAccessibility.joinedLabel(
            parts: [
                "\(title), \(value)",
                detail,
                status != .available
                    ? FormaProductCopy.PlanHealthIntelligencePresentation.limitedStatAccessibilitySuffix
                    : nil
            ]
        )
    }

    private static func sectionAccessibilityLabel(
        confidenceCard: PlanHealthConfidenceCardState,
        assumptions: PlanHealthAssumptionsState,
        dataQuality: PlanHealthDataQualityState,
        missingDataActions: [PlanHealthMissingDataActionState]
    ) -> String {
        HealthIntelligencePresentationAccessibility.joinedLabel(
            parts: [
                FormaProductCopy.PlanHealthIntelligencePresentation.sectionTitle,
                confidenceCard.accessibilityLabel,
                assumptions.accessibilityLabel,
                dataQuality.accessibilityLabel,
                missingDataActions.isEmpty
                    ? nil
                    : missingDataActions.map(\.accessibilityLabel).joined(separator: ". ")
            ]
        )
    }
}
