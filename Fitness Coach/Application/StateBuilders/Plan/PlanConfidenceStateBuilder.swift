//
//  PlanConfidenceStateBuilder.swift
//  Fitness Coach
//
//  Forma — Compact, actionable Plan Confidence presentation state.
//

import Foundation

enum PlanConfidenceStateBuilder {

    private static let recentWeightWindowDays = 14
    private static let consistentFoodLogDays = 5
    private static let partialFoodLogDays = 3

    static func build(
        context: PlanDashboardContext,
        planResult: PlanCalculationResult?,
        baseline: JourneyBaseline
    ) -> PlanConfidenceState {
        let profile = context.profile
        let foodDays = JourneyLogMetrics.foodLoggedDays(in: context.weekLogs)
        let hasRecentWeight = hasRecentWeightLog(
            in: context.allWeights,
            asOf: context.asOf,
            calendar: context.calendar
        )
        let hasAnyWeight = baseline.hasRealWeightEntries
        let hasBirthdayAndHeight = profile.birthDate != nil && profile.heightCm > 0
        let showsAppleHealth = context.dataSource == .appleHealth
        let isAppleHealthConnected = showsAppleHealth && context.integrationState.isConnected

        var score = 52
        score += 8

        if hasBirthdayAndHeight {
            score += 12
        } else if profile.birthDate != nil || profile.heightCm > 0 {
            score += 5
        }

        if let result = planResult {
            switch result.safetyLevel {
            case .ok:
                score += 15
            case .caution, .strongWarning:
                score += result.safetyLevel == .caution ? 10 : 6
            case .error:
                break
            }
        }

        if hasRecentWeight {
            score += 12
        } else if hasAnyWeight {
            score += 4
        }

        if foodDays >= consistentFoodLogDays {
            score += 10
        } else if foodDays >= partialFoodLogDays {
            score += 5
        }

        if isAppleHealthConnected {
            score += 5
        }

        score = applyEngagementCap(
            score: score,
            hasRecentWeight: hasRecentWeight,
            hasAnyWeight: hasAnyWeight,
            foodDays: foodDays
        )

        let clamped = min(100, max(0, score))
        let bucket = estimateBucket(for: clamped)
        let improvementActions = improvementActions(
            hasBirthdayAndHeight: hasBirthdayAndHeight,
            hasRecentWeight: hasRecentWeight,
            foodDays: foodDays,
            showsAppleHealth: showsAppleHealth,
            isAppleHealthConnected: isAppleHealthConnected,
            hasPlanResult: planResult != nil
        )
        let compactSignals = compactSignals(
            showsAppleHealth: showsAppleHealth,
            isAppleHealthConnected: isAppleHealthConnected,
            hasRecentWeight: hasRecentWeight,
            foodDays: foodDays
        )
        let showsAppleHealthAction = showsAppleHealth && !isAppleHealthConnected

        var state = PlanConfidenceState(
            confidenceScore: clamped,
            estimateBucket: bucket,
            sectionTitle: FormaProductCopy.PlanMissionControl.planConfidenceSectionTitle,
            scoreHeadline: FormaProductCopy.PlanMissionControl.planConfidenceScoreHeadline(
                score: clamped,
                bucket: bucket
            ),
            improveAccuracyHeading: FormaProductCopy.PlanMissionControl.planConfidenceImproveAccuracyHeading,
            improvementActions: improvementActions,
            compactSignalsHeading: FormaProductCopy.PlanMissionControl.planConfidenceCompactSignalsHeading,
            compactSignals: compactSignals,
            showsAppleHealthAction: showsAppleHealthAction,
            appleHealthActionTitle: showsAppleHealthAction
                ? TrainingIntegrationCopy.connectAppleHealth
                : nil,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    static func estimateBucket(for score: Int) -> PlanConfidenceEstimateBucket {
        switch score {
        case 85...: return .strong
        case 65..<85: return .good
        case 45..<65: return .fair
        default: return .low
        }
    }

    static func hasRecentWeightLog(
        in weights: [WeightEntry],
        asOf: Date,
        calendar: Calendar,
        windowDays: Int = recentWeightWindowDays
    ) -> Bool {
        guard let latest = weights
            .filter({ $0.weightKg > 0 })
            .max(by: { $0.date < $1.date }) else {
            return false
        }
        let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: asOf) ?? asOf
        return latest.date >= windowStart
    }

    static func applyEngagementCap(
        score: Int,
        hasRecentWeight: Bool,
        hasAnyWeight: Bool,
        foodDays: Int
    ) -> Int {
        let weightEngagement = hasRecentWeight ? 2 : (hasAnyWeight ? 1 : 0)
        let loggingEngagement = foodDays >= consistentFoodLogDays ? 2
            : (foodDays >= partialFoodLogDays ? 1 : 0)
        let engagement = weightEngagement + loggingEngagement

        switch engagement {
        case 0: return min(score, 68)
        case 1: return min(score, 78)
        default: return score
        }
    }

    private static func improvementActions(
        hasBirthdayAndHeight: Bool,
        hasRecentWeight: Bool,
        foodDays: Int,
        showsAppleHealth: Bool,
        isAppleHealthConnected: Bool,
        hasPlanResult: Bool
    ) -> [PlanConfidenceAction] {
        var candidates: [(priority: Int, action: PlanConfidenceAction)] = []

        if !hasBirthdayAndHeight {
            candidates.append((
                1,
                PlanConfidenceAction(
                    id: "profile",
                    text: FormaProductCopy.PlanMissionControl.planConfidenceActionAddProfileDetails
                )
            ))
        }

        if !hasRecentWeight {
            candidates.append((
                2,
                PlanConfidenceAction(
                    id: "weight",
                    text: FormaProductCopy.PlanMissionControl.planConfidenceActionLogWeight
                )
            ))
        }

        if foodDays < consistentFoodLogDays {
            candidates.append((
                3,
                PlanConfidenceAction(
                    id: "logging",
                    text: FormaProductCopy.PlanMissionControl.planConfidenceActionLogMeals
                )
            ))
        }

        if showsAppleHealth && !isAppleHealthConnected {
            candidates.append((
                4,
                PlanConfidenceAction(
                    id: "appleHealth",
                    text: FormaProductCopy.PlanMissionControl.planConfidenceActionConnectAppleHealth
                )
            ))
        }

        if !hasPlanResult {
            candidates.append((
                5,
                PlanConfidenceAction(
                    id: "calculation",
                    text: FormaProductCopy.PlanMissionControl.missingCalculation
                )
            ))
        }

        return candidates
            .sorted { $0.priority < $1.priority }
            .prefix(3)
            .map(\.action)
    }

    private static func compactSignals(
        showsAppleHealth: Bool,
        isAppleHealthConnected: Bool,
        hasRecentWeight: Bool,
        foodDays: Int
    ) -> [PlanConfidenceSignal] {
        var signals: [PlanConfidenceSignal] = []

        if showsAppleHealth {
            signals.append(
                PlanConfidenceSignal(
                    id: "appleHealth",
                    label: FormaProductCopy.PlanMissionControl.planConfidenceSignalAppleHealth,
                    value: isAppleHealthConnected
                        ? FormaProductCopy.PlanMissionControl.planConfidenceSignalConnected
                        : FormaProductCopy.PlanMissionControl.planConfidenceSignalNotConnected
                )
            )
        }

        signals.append(
            PlanConfidenceSignal(
                id: "weighIn",
                label: FormaProductCopy.PlanMissionControl.planConfidenceSignalRecentWeighIn,
                value: hasRecentWeight
                    ? FormaProductCopy.PlanMissionControl.planConfidenceSignalYes
                    : FormaProductCopy.PlanMissionControl.planConfidenceSignalNo
            )
        )

        signals.append(
            PlanConfidenceSignal(
                id: "foodLogs",
                label: FormaProductCopy.PlanMissionControl.planConfidenceSignalFoodLogs,
                value: foodDays >= consistentFoodLogDays
                    ? FormaProductCopy.PlanMissionControl.planConfidenceSignalEnough
                    : FormaProductCopy.PlanMissionControl.planConfidenceSignalNotEnough
            )
        )

        return signals
    }

    private static func accessibilitySummary(for state: PlanConfidenceState) -> String {
        var parts = [state.sectionTitle, state.scoreHeadline]

        if !state.improvementActions.isEmpty {
            parts.append(state.improveAccuracyHeading)
            parts.append(contentsOf: state.improvementActions.map(\.text))
        }

        parts.append(state.compactSignalsHeading)
        parts.append(contentsOf: state.compactSignals.map { "\($0.label), \($0.value)" })

        if state.showsAppleHealthAction, let actionTitle = state.appleHealthActionTitle {
            parts.append(actionTitle)
        }

        return parts.joined(separator: ". ")
    }
}
