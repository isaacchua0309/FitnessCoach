//
//  PlanStatusStateBuilder.swift
//  Fitness Coach
//
//  Forma — Strategy classification for the Plan Status card.
//

import Foundation

enum PlanStatusStateBuilder {

    private static let aggressiveDeficitKcalThreshold = 550
    private static let gentleDeficitKcalThreshold = 400
    private static let rebuildSurplusKcalThreshold = 250

    static func build(
        profile: UserProfile,
        planResult: PlanCalculationResult?,
        referenceDate: Date
    ) -> PlanStatusState {
        guard isReviewable(profile: profile, planResult: planResult, referenceDate: referenceDate) else {
            return makeState(for: .needsReview)
        }

        guard let result = planResult else {
            return makeState(for: .needsReview)
        }

        let classification = classify(
            profile: profile,
            result: result
        )
        return makeState(for: classification)
    }

    static func classify(
        profile: UserProfile,
        result: PlanCalculationResult
    ) -> PlanStrategyClassification {
        switch result.goalDirection {
        case .cut:
            return classifyCut(
                aggressiveness: profile.targets.aggressiveness,
                dailyDeficitKcal: result.dailyDeficitKcal,
                safetyLevel: result.safetyLevel
            )
        case .maintain:
            return .maintenance
        case .gain:
            return classifyGain(
                aggressiveness: profile.targets.aggressiveness,
                surplusKcal: result.calorieTargetKcal - result.tdeeKcal
            )
        }
    }

    static func classifyCut(
        aggressiveness: CalorieAggressiveness,
        dailyDeficitKcal: Int,
        safetyLevel: PlanSafetyLevel
    ) -> PlanStrategyClassification {
        guard dailyDeficitKcal > 0 else { return .needsReview }

        if safetyLevel == .strongWarning
            || aggressiveness == .aggressive
            || dailyDeficitKcal >= aggressiveDeficitKcalThreshold {
            return .aggressiveCut
        }

        if aggressiveness == .conservative
            || dailyDeficitKcal < gentleDeficitKcalThreshold {
            return .gentleCut
        }

        return .moderateCut
    }

    static func classifyGain(
        aggressiveness: CalorieAggressiveness,
        surplusKcal: Int
    ) -> PlanStrategyClassification {
        guard surplusKcal > 0 else { return .needsReview }

        if aggressiveness == .conservative || surplusKcal <= rebuildSurplusKcalThreshold {
            return .rebuild
        }

        return .leanGain
    }

    private static func isReviewable(
        profile: UserProfile,
        planResult: PlanCalculationResult?,
        referenceDate: Date
    ) -> Bool {
        guard profile.heightCm > 0 else { return false }
        guard profile.resolvedAge(referenceDate: referenceDate) > 0 else { return false }
        guard profile.targets.calorieTarget > 0 else { return false }
        guard let planResult else { return false }
        guard planResult.safetyLevel != .error else { return false }
        return true
    }

    private static func makeState(for classification: PlanStrategyClassification) -> PlanStatusState {
        let copy = copyBundle(for: classification)
        var state = PlanStatusState(
            sectionTitle: FormaProductCopy.PlanStatus.sectionTitle,
            classification: classification,
            statusName: copy.name,
            explanation: copy.explanation,
            bestForLabel: FormaProductCopy.PlanStatus.bestForLabel,
            bestForValue: copy.bestFor,
            watchForLabel: FormaProductCopy.PlanStatus.watchForLabel,
            watchForValue: copy.watchFor,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    private static func accessibilitySummary(for state: PlanStatusState) -> String {
        [
            state.sectionTitle,
            state.statusName,
            state.explanation,
            "\(state.bestForLabel), \(state.bestForValue)",
            "\(state.watchForLabel), \(state.watchForValue)"
        ].joined(separator: ". ")
    }

    private static func copyBundle(
        for classification: PlanStrategyClassification
    ) -> (name: String, explanation: String, bestFor: String, watchFor: String) {
        switch classification {
        case .aggressiveCut:
            return (
                FormaProductCopy.PlanStatus.aggressiveCutName,
                FormaProductCopy.PlanStatus.aggressiveCutExplanation,
                FormaProductCopy.PlanStatus.aggressiveCutBestFor,
                FormaProductCopy.PlanStatus.aggressiveCutWatchFor
            )
        case .moderateCut:
            return (
                FormaProductCopy.PlanStatus.moderateCutName,
                FormaProductCopy.PlanStatus.moderateCutExplanation,
                FormaProductCopy.PlanStatus.moderateCutBestFor,
                FormaProductCopy.PlanStatus.moderateCutWatchFor
            )
        case .gentleCut:
            return (
                FormaProductCopy.PlanStatus.gentleCutName,
                FormaProductCopy.PlanStatus.gentleCutExplanation,
                FormaProductCopy.PlanStatus.gentleCutBestFor,
                FormaProductCopy.PlanStatus.gentleCutWatchFor
            )
        case .maintenance:
            return (
                FormaProductCopy.PlanStatus.maintenanceName,
                FormaProductCopy.PlanStatus.maintenanceExplanation,
                FormaProductCopy.PlanStatus.maintenanceBestFor,
                FormaProductCopy.PlanStatus.maintenanceWatchFor
            )
        case .leanGain:
            return (
                FormaProductCopy.PlanStatus.leanGainName,
                FormaProductCopy.PlanStatus.leanGainExplanation,
                FormaProductCopy.PlanStatus.leanGainBestFor,
                FormaProductCopy.PlanStatus.leanGainWatchFor
            )
        case .rebuild:
            return (
                FormaProductCopy.PlanStatus.rebuildName,
                FormaProductCopy.PlanStatus.rebuildExplanation,
                FormaProductCopy.PlanStatus.rebuildBestFor,
                FormaProductCopy.PlanStatus.rebuildWatchFor
            )
        case .needsReview:
            return (
                FormaProductCopy.PlanStatus.needsReviewName,
                FormaProductCopy.PlanStatus.needsReviewExplanation,
                FormaProductCopy.PlanStatus.needsReviewBestFor,
                FormaProductCopy.PlanStatus.needsReviewWatchFor
            )
        }
    }
}
