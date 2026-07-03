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

        let confidenceCard = confidenceCard(from: input)
        let dataQuality = dataQuality(from: input)
        let assumptions = assumptions(from: input, dataQuality: dataQuality)
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
        hasNutritionLogging: Bool = false,
        hasRecentWeightLog: Bool = false,
        calendar: Calendar = .current
    ) -> PlanHealthIntelligenceSectionState {
        buildSection(
            input: .from(
                snapshot: snapshot,
                baselineContext: baselineContext,
                hasNutritionLogging: hasNutritionLogging,
                hasRecentWeightLog: hasRecentWeightLog
            ),
            calendar: calendar
        )
    }

    // MARK: - Confidence card

    static func confidenceCard(from input: PlanHealthIntelligenceBuildInput) -> PlanHealthConfidenceCardState {
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

        return PlanHealthConfidenceCardState(
            phase: .loaded,
            sectionTitle: copy.confidenceSectionTitle,
            headline: headline,
            summary: summary,
            confidenceLabel: label,
            scorePercent: scorePercent,
            disclaimerLine: copy.disclaimer,
            accessibilityLabel: confidenceAccessibilityLabel(
                headline: headline,
                summary: summary,
                confidenceLabel: label,
                scorePercent: scorePercent,
                disclaimerLine: copy.disclaimer
            )
        )
    }

    // MARK: - Data quality

    static func dataQuality(from input: PlanHealthIntelligenceBuildInput) -> PlanHealthDataQualityState {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let signals = primarySignals(from: input) + supplementalSignals(from: input)
        let summary: String

        if signals.contains(where: { $0.status == .available }) {
            summary = copy.dataQualitySummaryAvailable
        } else if signals.contains(where: { $0.status == .limited }) {
            summary = copy.dataQualitySummaryLimited
        } else {
            summary = copy.dataQualitySummaryEmpty
        }

        return PlanHealthDataQualityState(
            sectionTitle: copy.dataQualitySectionTitle,
            summary: summary,
            signals: signals,
            accessibilityLabel: dataQualityAccessibilityLabel(summary: summary, signals: signals)
        )
    }

    // MARK: - Assumptions

    static func assumptions(
        from input: PlanHealthIntelligenceBuildInput,
        dataQuality: PlanHealthDataQualityState
    ) -> PlanHealthAssumptionsState {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let items = assumptionItems(from: input, signals: dataQuality.signals)
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

        if baseline.missingSignals.contains(.hrv) {
            actions.append(
                PlanHealthMissingDataActionState(
                    id: "hrv",
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

        if baseline.availableSignals.isEmpty, input.planConfidence.score <= 0 {
            actions.insert(
                PlanHealthMissingDataActionState(
                    id: "connect-health",
                    title: copy.actionConnectHealthTitle,
                    message: copy.actionConnectHealthMessage,
                    accessibilityLabel: "\(copy.actionConnectHealthTitle). \(copy.actionConnectHealthMessage)"
                ),
                at: 0
            )
        }

        return actions
    }

    // MARK: - Private signal builders

    private static func primarySignals(from input: PlanHealthIntelligenceBuildInput) -> [PlanHealthSignalState] {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let baseline = input.baselineContext
        let recovery = input.recovery ?? .unknown

        let recoverySignal = PlanHealthSignalState(
            id: PlanHealthSignalKind.recoveryTrend.rawValue,
            kind: .recoveryTrend,
            title: copy.signalRecoveryTrend,
            value: copy.recoveryTrendValue(score: recovery.score, status: recovery.status),
            detail: recovery.confidence == .low || recovery.confidence == .unknown
                ? copy.signalLimitedDetail
                : nil,
            status: recoveryStatus(from: recovery, baseline: baseline),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalRecoveryTrend,
                value: copy.recoveryTrendValue(score: recovery.score, status: recovery.status),
                detail: nil,
                status: recoveryStatus(from: recovery, baseline: baseline)
            )
        )

        let workoutDays = baseline.workoutDays7d ?? 0
        let workoutSignal = PlanHealthSignalState(
            id: PlanHealthSignalKind.workoutConsistency.rawValue,
            kind: .workoutConsistency,
            title: copy.signalWorkoutConsistency,
            value: copy.workoutConsistencyValue(days: workoutDays),
            detail: baseline.availableSignals.contains(.workoutLoad) ? nil : copy.signalLimitedDetail,
            status: baseline.workoutDays7d == nil ? .missing : (workoutDays > 0 ? .available : .limited),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalWorkoutConsistency,
                value: copy.workoutConsistencyValue(days: workoutDays),
                detail: nil,
                status: baseline.workoutDays7d == nil ? .missing : (workoutDays > 0 ? .available : .limited)
            )
        )

        let stepsValue = baseline.averageSteps7d ?? baseline.averageSteps28d
        let stepsSignal = PlanHealthSignalState(
            id: PlanHealthSignalKind.averageSteps.rawValue,
            kind: .averageSteps,
            title: copy.signalAverageSteps,
            value: copy.averageStepsValue(stepsValue),
            detail: baseline.averageSteps7d == nil && baseline.averageSteps28d != nil
                ? copy.signalLimitedDetail
                : nil,
            status: signalStatus(for: .steps, baseline: baseline, hasValue: stepsValue != nil && (stepsValue ?? 0) > 0),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalAverageSteps,
                value: copy.averageStepsValue(stepsValue),
                detail: nil,
                status: signalStatus(for: .steps, baseline: baseline, hasValue: stepsValue != nil && (stepsValue ?? 0) > 0)
            )
        )

        let frequencySignal = PlanHealthSignalState(
            id: PlanHealthSignalKind.trainingFrequency.rawValue,
            kind: .trainingFrequency,
            title: copy.signalTrainingFrequency,
            value: copy.trainingFrequencyValue(days: workoutDays),
            detail: nil,
            status: baseline.workoutDays7d == nil ? .missing : (workoutDays > 0 ? .available : .limited),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalTrainingFrequency,
                value: copy.trainingFrequencyValue(days: workoutDays),
                detail: nil,
                status: baseline.workoutDays7d == nil ? .missing : (workoutDays > 0 ? .available : .limited)
            )
        )

        return [recoverySignal, workoutSignal, stepsSignal, frequencySignal]
    }

    private static func supplementalSignals(from input: PlanHealthIntelligenceBuildInput) -> [PlanHealthSignalState] {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let baseline = input.baselineContext

        let sleepSignal = PlanHealthSignalState(
            id: PlanHealthSignalKind.sleep.rawValue,
            kind: .sleep,
            title: copy.signalSleep,
            value: sleepValue(from: baseline),
            detail: baseline.missingSignals.contains(.sleep) ? copy.signalLimitedDetail : nil,
            status: signalStatus(
                for: .sleep,
                baseline: baseline,
                hasValue: baseline.averageSleepDuration7d != nil || baseline.averageSleepDuration28d != nil
            ),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalSleep,
                value: sleepValue(from: baseline),
                detail: nil,
                status: signalStatus(
                    for: .sleep,
                    baseline: baseline,
                    hasValue: baseline.averageSleepDuration7d != nil || baseline.averageSleepDuration28d != nil
                )
            )
        )

        let hrvSignal = PlanHealthSignalState(
            id: PlanHealthSignalKind.heartVariability.rawValue,
            kind: .heartVariability,
            title: copy.signalHeartVariability,
            value: hrvValue(from: baseline),
            detail: baseline.missingSignals.contains(.hrv) ? copy.signalLimitedDetail : nil,
            status: signalStatus(
                for: .hrv,
                baseline: baseline,
                hasValue: baseline.averageHRV28d != nil
            ),
            accessibilityLabel: signalAccessibilityLabel(
                title: copy.signalHeartVariability,
                value: hrvValue(from: baseline),
                detail: nil,
                status: signalStatus(
                    for: .hrv,
                    baseline: baseline,
                    hasValue: baseline.averageHRV28d != nil
                )
            )
        )

        let weightSignal = PlanHealthSignalState(
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

        let nutritionSignal = PlanHealthSignalState(
            id: PlanHealthSignalKind.nutrition.rawValue,
            kind: .nutrition,
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

        return [sleepSignal, hrvSignal, weightSignal, nutritionSignal]
    }

    private static func assumptionItems(
        from input: PlanHealthIntelligenceBuildInput,
        signals: [PlanHealthSignalState]
    ) -> [PlanAssumptionItemState] {
        signals
            .filter { $0.kind != .weight && $0.kind != .nutrition }
            .map { signal in
                PlanAssumptionItemState(
                    id: signal.id,
                    label: signal.title,
                    value: signal.value,
                    isLimited: signal.status != .available,
                    accessibilityLabel: "\(signal.title), \(signal.value)"
                        + (signal.status != .available
                            ? ". \(FormaProductCopy.PlanHealthIntelligencePresentation.limitedStatAccessibilitySuffix)"
                            : "")
                )
            }
    }

    private static func recoveryStatus(
        from recovery: RecoverySummary,
        baseline: HealthBaselineContext
    ) -> PlanHealthSignalStatus {
        if recovery.status == .unknown, recovery.score == nil {
            return baseline.availableSignals.contains(.sleep) || baseline.availableSignals.contains(.hrv)
                ? .limited
                : .missing
        }
        return recovery.confidence == .low ? .limited : .available
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

    private static func sleepValue(from baseline: HealthBaselineContext) -> String {
        guard let minutes = baseline.averageSleepDuration7d ?? baseline.averageSleepDuration28d else {
            return FormaProductCopy.PlanHealthIntelligencePresentation.signalUnavailable
        }
        let hours = minutes / 60.0
        return String(format: "%.1f h avg", hours)
    }

    private static func hrvValue(from baseline: HealthBaselineContext) -> String {
        guard let hrv = baseline.averageHRV28d else {
            return FormaProductCopy.PlanHealthIntelligencePresentation.signalUnavailable
        }
        return "\(Int(hrv.rounded())) ms avg"
    }

    private static func hasRenderableSignals(_ input: PlanHealthIntelligenceBuildInput) -> Bool {
        let baseline = input.baselineContext
        return !baseline.availableSignals.isEmpty
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
                summary: copy.loadingSubtitle,
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
        disclaimerLine: String
    ) -> String {
        var parts = [headline, summary, "Confidence, \(confidenceLabel)"]
        if let scorePercent {
            parts.append("\(scorePercent) percent")
        }
        parts.append(disclaimerLine)
        return parts.joined(separator: ". ")
    }

    private static func dataQualityAccessibilityLabel(
        summary: String,
        signals: [PlanHealthSignalState]
    ) -> String {
        let signalLabels = signals.map(\.accessibilityLabel).joined(separator: ". ")
        return "\(FormaProductCopy.PlanHealthIntelligencePresentation.dataQualitySectionTitle). \(summary). \(signalLabels)"
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
