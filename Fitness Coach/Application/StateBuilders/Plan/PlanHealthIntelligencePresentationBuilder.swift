//
//  PlanHealthIntelligencePresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Maps Health Intelligence snapshot confidence and baselines into Plan presentation state.
//  Pure deterministic mapping; no SwiftUI, HealthKit, or repository types.
//

import Foundation

enum PlanHealthIntelligencePresentationBuilder {

    // MARK: - Section

    static func buildSection(
        input: PlanHealthIntelligenceBuildInput,
        calendar: Calendar = .current
    ) -> PlanHealthIntelligenceSectionState {
        if input.isLoading {
            return loadingSection()
        }

        let signals = healthSignals(from: input)
        let dataQuality = dataQuality(from: input, signals: signals)
        let confidenceCard = confidenceCard(from: input, dataQuality: dataQuality)
        let assumptions = assumptions(from: input)
        let missingDataActions = missingDataActions(from: input)

        return PlanHealthIntelligenceSectionState(
            confidenceCard: confidenceCard,
            assumptions: assumptions,
            dataQuality: dataQuality,
            missingDataActions: missingDataActions,
            isLoading: false,
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
        dataQuality: PlanHealthDataQualityState
    ) -> PlanHealthConfidenceCardState {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let confidence = input.planConfidence
        let hasAnySignal = hasRenderableSignals(input)

        guard hasAnySignal || confidence.score > 0 else {
            return .empty
        }

        let label = copy.confidenceLabel(for: confidence)
        let scorePercent = confidence.score > 0 ? Int((confidence.score * 100).rounded()) : nil
        let headline = copy.confidenceHeadline(label: label)
        let summary = copy.confidenceSummary(score: confidence.score, label: label)
        let reasons = confidenceReasons(from: input, label: label)

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
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let items = assumptionItems(from: input)
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
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let baseline = input.baselineContext
        var actions: [PlanHealthMissingDataActionState] = []

        if input.healthConnection == .disconnected {
            actions.append(
                PlanHealthMissingDataActionState(
                    id: "connect-health",
                    title: copy.actionConnectHealthTitle,
                    message: copy.actionConnectHealthMessage,
                    accessibilityLabel: "\(copy.actionConnectHealthTitle). \(copy.actionConnectHealthMessage)"
                )
            )
        }

        if input.healthConnection == .partial {
            actions.append(
                PlanHealthMissingDataActionState(
                    id: "partial-permissions",
                    title: copy.actionPartialPermissionsTitle,
                    message: copy.actionPartialPermissionsMessage,
                    accessibilityLabel: "\(copy.actionPartialPermissionsTitle). \(copy.actionPartialPermissionsMessage)"
                )
            )
        }

        if baseline.missingSignals.contains(.sleep) {
            actions.append(
                PlanHealthMissingDataActionState(
                    id: "sleep",
                    title: copy.actionEnableSleepTitle,
                    message: copy.actionEnableSleepMessage,
                    accessibilityLabel: "\(copy.actionEnableSleepTitle). \(copy.actionEnableSleepMessage)"
                )
            )
        }

        if baseline.missingSignals.contains(.hrv)
            || baseline.missingSignals.contains(.restingHeartRate) {
            actions.append(
                PlanHealthMissingDataActionState(
                    id: "heart-metrics",
                    title: copy.actionEnableHRVTitle,
                    message: copy.actionEnableHRVMessage,
                    accessibilityLabel: "\(copy.actionEnableHRVTitle). \(copy.actionEnableHRVMessage)"
                )
            )
        }

        if !input.hasRecentWeightLog {
            actions.append(
                PlanHealthMissingDataActionState(
                    id: "weight",
                    title: copy.actionLogWeightTitle,
                    message: copy.actionLogWeightMessage,
                    accessibilityLabel: "\(copy.actionLogWeightTitle). \(copy.actionLogWeightMessage)"
                )
            )
        }

        if !input.hasNutritionLogging {
            actions.append(
                PlanHealthMissingDataActionState(
                    id: "nutrition",
                    title: copy.actionLogNutritionTitle,
                    message: copy.actionLogNutritionMessage,
                    accessibilityLabel: "\(copy.actionLogNutritionTitle). \(copy.actionLogNutritionMessage)"
                )
            )
        }

        return actions
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

        let workouts = PlanHealthSignalState(
            id: PlanHealthSignalKind.appleHealthWorkouts.rawValue,
            kind: .appleHealthWorkouts,
            title: copy.signalAppleHealthWorkouts,
            value: input.healthConnection == .disconnected
                ? copy.signalUnavailable
                : copy.workoutConsistencyValue(days: workoutDays),
            detail: input.healthConnection == .partial ? copy.signalPartialSync : nil,
            status: workoutSignalStatus(from: input, workoutDays: workoutDays),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalAppleHealthWorkouts,
                value: copy.workoutConsistencyValue(days: workoutDays),
                detail: nil,
                status: workoutSignalStatus(from: input, workoutDays: workoutDays)
            )
        )

        let steps = PlanHealthSignalState(
            id: PlanHealthSignalKind.stepHistory.rawValue,
            kind: .stepHistory,
            title: copy.signalStepHistory,
            value: copy.averageStepsPerDayValue(stepsValue),
            detail: baseline.averageSteps7d == nil && baseline.averageSteps28d != nil
                ? copy.signalLimitedDetail
                : nil,
            status: signalStatus(for: .steps, baseline: baseline, hasValue: stepsValue != nil && (stepsValue ?? 0) > 0),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalStepHistory,
                value: copy.averageStepsPerDayValue(stepsValue),
                detail: nil,
                status: signalStatus(for: .steps, baseline: baseline, hasValue: stepsValue != nil && (stepsValue ?? 0) > 0)
            )
        )

        let activeEnergy = PlanHealthSignalState(
            id: PlanHealthSignalKind.activeEnergy.rawValue,
            kind: .activeEnergy,
            title: copy.signalActiveEnergy,
            value: copy.activeEnergyValue(energyValue),
            detail: baseline.averageActiveEnergy7d == nil && baseline.averageActiveEnergy28d != nil
                ? copy.signalLimitedDetail
                : nil,
            status: signalStatus(
                for: .activeEnergy,
                baseline: baseline,
                hasValue: energyValue != nil && (energyValue ?? 0) > 0
            ),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalActiveEnergy,
                value: copy.activeEnergyValue(energyValue),
                detail: nil,
                status: signalStatus(
                    for: .activeEnergy,
                    baseline: baseline,
                    hasValue: energyValue != nil && (energyValue ?? 0) > 0
                )
            )
        )

        let sleep = PlanHealthSignalState(
            id: PlanHealthSignalKind.sleep.rawValue,
            kind: .sleep,
            title: copy.signalSleep,
            value: copy.sleepAverageValue(minutes: sleepMinutes),
            detail: baseline.missingSignals.contains(.sleep) ? copy.signalLimitedDetail : nil,
            status: signalStatus(
                for: .sleep,
                baseline: baseline,
                hasValue: sleepMinutes != nil
            ),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalSleep,
                value: copy.sleepAverageValue(minutes: sleepMinutes),
                detail: nil,
                status: signalStatus(
                    for: .sleep,
                    baseline: baseline,
                    hasValue: sleepMinutes != nil
                )
            )
        )

        let heartMetrics = PlanHealthSignalState(
            id: PlanHealthSignalKind.heartMetrics.rawValue,
            kind: .heartMetrics,
            title: copy.signalHeartMetrics,
            value: heartValue,
            detail: baseline.missingSignals.contains(.hrv) || baseline.missingSignals.contains(.restingHeartRate)
                ? copy.signalLimitedDetail
                : nil,
            status: heartMetricsStatus(from: baseline),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalHeartMetrics,
                value: heartValue,
                detail: nil,
                status: heartMetricsStatus(from: baseline)
            )
        )

        let weight = PlanHealthSignalState(
            id: PlanHealthSignalKind.weight.rawValue,
            kind: .weight,
            title: copy.signalWeight,
            value: input.hasRecentWeightLog ? copy.signalWeightLogged : copy.signalUnavailable,
            detail: input.hasRecentWeightLog ? nil : copy.signalLimitedDetail,
            status: input.hasRecentWeightLog ? .available : .missing,
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalWeight,
                value: input.hasRecentWeightLog ? copy.signalWeightLogged : copy.signalUnavailable,
                detail: nil,
                status: input.hasRecentWeightLog ? .available : .missing
            )
        )

        let nutrition = PlanHealthSignalState(
            id: PlanHealthSignalKind.nutritionLogs.rawValue,
            kind: .nutritionLogs,
            title: copy.signalNutrition,
            value: input.hasNutritionLogging ? copy.signalNutritionLogged : copy.signalUnavailable,
            detail: input.hasNutritionLogging ? nil : copy.signalLimitedDetail,
            status: input.hasNutritionLogging ? .available : .missing,
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalNutrition,
                value: input.hasNutritionLogging ? copy.signalNutritionLogged : copy.signalUnavailable,
                detail: nil,
                status: input.hasNutritionLogging ? .available : .missing
            )
        )

        return [workouts, steps, activeEnergy, sleep, heartMetrics, weight, nutrition]
    }

    private static func assumptionItems(from input: PlanHealthIntelligenceBuildInput) -> [PlanAssumptionItemState] {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let baseline = input.baselineContext
        let recovery = input.recovery ?? .unknown
        let stepsValue = baseline.averageSteps7d ?? baseline.averageSteps28d

        let items: [(String, String, String, Bool)] = [
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

        return items.map { id, label, value, isLimited in
            PlanAssumptionItemState(
                id: id,
                label: label,
                value: value,
                isLimited: isLimited,
                accessibilityLabel: "\(label), \(value)"
                    + (isLimited
                        ? ". \(copy.limitedStatAccessibilitySuffix)"
                        : "")
            )
        }
    }

    private static func confidenceReasons(
        from input: PlanHealthIntelligenceBuildInput,
        label: String
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

    private static func hasRenderableSignals(_ input: PlanHealthIntelligenceBuildInput) -> Bool {
        let baseline = input.baselineContext
        return input.healthConnection != .disconnected
            || !baseline.availableSignals.isEmpty
            || baseline.workoutDays7d != nil
            || input.recovery?.score != nil
            || input.hasNutritionLogging
            || input.hasRecentWeightLog
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
            missingDataActions: [],
            isLoading: true,
            accessibilityLabel: copy.loadingAccessibilityLabel
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
        var parts = [headline, summary, "Confidence, \(confidenceLabel)"]
        if let scorePercent {
            parts.append("\(scorePercent) percent")
        }
        if !reasons.isEmpty {
            parts.append(reasons.joined(separator: ". "))
        }
        parts.append(disclaimerLine)
        return parts.joined(separator: ". ")
    }

    private static func dataQualityAccessibilityLabel(
        qualityLabel: String,
        explanation: String,
        signals: [PlanHealthSignalState]
    ) -> String {
        let signalLabels = signals.map(\.accessibilityLabel).joined(separator: ". ")
        return "\(FormaProductCopy.PlanHealthIntelligencePresentation.dataQualitySectionTitle). \(qualityLabel). \(explanation). \(signalLabels)"
    }

    private static func assumptionsAccessibilityLabel(
        summary: String,
        items: [PlanAssumptionItemState]
    ) -> String {
        let itemLabels = items.map(\.accessibilityLabel).joined(separator: ". ")
        return "\(FormaProductCopy.PlanHealthIntelligencePresentation.assumptionsSectionTitle). \(summary). \(itemLabels)"
    }

    private static func signalAccessibilityLabel(
        title: String,
        value: String,
        detail: String?,
        status: PlanHealthSignalStatus
    ) -> String {
        var parts = ["\(title), \(value)"]
        if let detail {
            parts.append(detail)
        }
        if status != .available {
            parts.append(FormaProductCopy.PlanHealthIntelligencePresentation.limitedStatAccessibilitySuffix)
        }
        return parts.joined(separator: ". ")
    }

    private static func sectionAccessibilityLabel(
        confidenceCard: PlanHealthConfidenceCardState,
        assumptions: PlanHealthAssumptionsState,
        dataQuality: PlanHealthDataQualityState,
        missingDataActions: [PlanHealthMissingDataActionState]
    ) -> String {
        var parts = [
            FormaProductCopy.PlanHealthIntelligencePresentation.sectionTitle,
            confidenceCard.accessibilityLabel,
            assumptions.accessibilityLabel,
            dataQuality.accessibilityLabel
        ]
        if !missingDataActions.isEmpty {
            parts.append(
                missingDataActions.map(\.accessibilityLabel).joined(separator: ". ")
            )
        }
        return parts.joined(separator: ". ")
    }
}
