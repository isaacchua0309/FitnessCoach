//
//  PlanRecommendationPolicy.swift
//  Fitness Coach
//
//  Forma — Safe, non-automatic plan recommendations from weekly progress data.
//

import Foundation

// MARK: - Types

enum WeeklyPlanRecommendationKind: String, Codable, Equatable {
    case notEnoughData
    case holdSteady
    case improveConsistencyFirst
    case considerSmallIncrease
    case considerSmallDecrease
    case reviewPlanManually
    case waitBecauseScaleIsNoisy
}

struct WeeklyPlanRecommendation: Equatable {
    let kind: WeeklyPlanRecommendationKind
    let confidence: WeeklyProgressConfidenceLevel
    let title: String
    let message: String
    let suggestedCalorieDelta: Int?
    let shouldShowPlanCTA: Bool
    let ctaTitle: String?
    let reasons: [String]
    let safetyNotes: [String]
}

struct PlanRecommendationInput: Equatable {
    let summary: WeeklyProgressSummary
    let currentCalorieTargetKcal: Int?
    let staticTDEEKcal: Int?
    /// Optional calorie floor from the active plan. Used to validate suggested targets.
    let calorieFloorKcal: Int?
    let goalDirection: JourneyGoalDirection
}

// MARK: - Policy

enum PlanRecommendationPolicy {

    // MARK: Thresholds

    /// Calorie adherence rate required before suggesting a target decrease.
    private static let goodCalorieAdherenceRate = 0.60

    /// Weekly body-weight loss rate above which a larger increase is suggested (1.5%/week).
    private static let aggressiveWeeklyLossRate = 0.015

    private static let standardIncreaseDeltaKcal = 100
    private static let largerIncreaseDeltaKcal = 150
    private static let standardDecreaseDeltaKcal = -100

    private static let automaticChangeDisclaimer =
        "Forma will not change your plan automatically — review and confirm any update."

    // MARK: Public

    static func recommend(_ input: PlanRecommendationInput) -> WeeklyPlanRecommendation {
        let summary = input.summary
        let maintenance = summary.maintenanceEstimate
        let sufficiency = maintenance.sufficiency
        let confidence = summary.confidence

        if !sufficiency.isEligibleForPlanRecommendation
            || confidence == .unavailable {
            return notEnoughDataRecommendation(
                summary: summary,
                reasons: blockingReasons(from: sufficiency)
            )
        }

        if sufficiency.reasons.contains(.inconsistentLogging)
            || summary.verdict == .needsConsistencyFirst {
            return improveConsistencyRecommendation(summary: summary)
        }

        if summary.hasSuddenSpike
            || maintenance.shouldShowWaterWeightDisclaimer
            || summary.verdict == .noisyButLikelyOkay
            || sufficiency.reasons.contains(.weightTrendTooNoisy) {
            return waitForNoiseRecommendation(summary: summary)
        }

        if maintenance.method == .unavailable
            || (!sufficiency.isEligibleForMaintenanceEstimate && maintenance.estimatedMaintenanceKcal == nil) {
            return holdSteadyRecommendation(
                summary: summary,
                title: "Hold steady this week.",
                message: "Keep logging a few more days before we estimate maintenance.",
                reasons: ["Learned maintenance is not available yet for this window."],
                showPlanCTA: false
            )
        }

        let adherenceRate = calorieAdherenceRate(summary: summary)
        let canSuggestDelta = WeeklyProgressConfidencePolicy.canRecommendPreciseCalorieAdjustment(
            sufficiency
        )

        switch summary.verdict {
        case .notEnoughData, .unclear:
            return notEnoughDataRecommendation(
                summary: summary,
                reasons: ["Weekly progress is still too limited for a calorie recommendation."]
            )

        case .onTrack, .maintaining:
            return holdSteadyRecommendation(
                summary: summary,
                title: "Hold steady this week.",
                message: "Your plan looks reasonable based on your trend.",
                reasons: ["Weight trend and logging look aligned with your goal."],
                showPlanCTA: false
            )

        case .likelyTooAggressive:
            guard canSuggestDelta, input.goalDirection == .lose else {
                return reviewManuallyRecommendation(
                    summary: summary,
                    message: "Your weight is moving faster than planned. Consider reviewing your calories before pushing harder.",
                    reasons: ["Weight trend is faster than a typical weekly pace."]
                )
            }

            let delta = proposedIncreaseDelta(
                summary: summary,
                currentTargetKcal: input.currentCalorieTargetKcal
            )
            return calorieChangeRecommendation(
                input: input,
                kind: .considerSmallIncrease,
                proposedDelta: delta,
                title: "Consider a small calorie increase",
                message: "Your weight is moving faster than planned. Consider reviewing your calories before pushing harder.",
                reasons: [
                    "Weight trend is faster than a typical weekly pace for your goal.",
                    "A small increase may be easier to sustain than pushing the current deficit."
                ]
            )

        case .likelyTooSlow:
            if adherenceRate < goodCalorieAdherenceRate {
                return improveConsistencyRecommendation(
                    summary: summary,
                    extraReason: "Calorie adherence was uneven, so focus on consistency before lowering targets."
                )
            }

            guard canSuggestDelta, input.goalDirection == .lose else {
                return reviewManuallyRecommendation(
                    summary: summary,
                    message: "Progress looks slower than expected. Review your plan before making changes.",
                    reasons: ["Weight trend is slower than expected for your goal."]
                )
            }

            if hasReasonableDeficit(input: input) {
                return reviewManuallyRecommendation(
                    summary: summary,
                    message: "Progress looks slower than expected, but your current deficit already looks reasonable. Review your plan before changing calories.",
                    reasons: [
                        "Weight trend is slower than expected.",
                        "Current target already implies a meaningful deficit."
                    ]
                )
            }

            return calorieChangeRecommendation(
                input: input,
                kind: .considerSmallDecrease,
                proposedDelta: standardDecreaseDeltaKcal,
                title: "Consider reviewing your calorie target",
                message: "Weight loss looks slower than expected despite solid logging. A small review may help — not an automatic change.",
                reasons: [
                    "Weight trend is slower than expected with good calorie adherence.",
                    "A small decrease is optional and must be confirmed in Plan."
                ]
            )

        case .noisyButLikelyOkay:
            return waitForNoiseRecommendation(summary: summary)

        case .needsConsistencyFirst:
            return improveConsistencyRecommendation(summary: summary)
        }
    }

    // MARK: Safety metadata

    /// Validates a proposed target using the same deficit cap as `PlanSafetyValidator` pace warnings.
    static func isProposedTargetSafe(
        proposedTargetKcal: Int,
        tdeeKcal: Int?,
        calorieFloorKcal: Int?
    ) -> Bool {
        guard proposedTargetKcal > 0 else { return false }

        if let floor = calorieFloorKcal, proposedTargetKcal < floor {
            return false
        }

        guard let tdeeKcal, tdeeKcal > 0 else {
            return true
        }

        let deficit = tdeeKcal - proposedTargetKcal
        if deficit <= 0 {
            return true
        }

        let maxDeficit = Int(
            (Double(tdeeKcal) * FormaCalculationConstants.maxDeficitFractionOfTDEE).rounded()
        )
        return deficit <= maxDeficit
    }

    /// Returns a clamped delta that respects allowed step sizes and safety bounds, or `nil` if unsafe.
    static func validatedCalorieDelta(
        proposedDelta: Int,
        currentTargetKcal: Int?,
        tdeeKcal: Int?,
        calorieFloorKcal: Int?
    ) -> Int? {
        guard let currentTargetKcal, currentTargetKcal > 0 else {
            return nil
        }

        let allowedDelta = allowedDeltaMagnitude(for: proposedDelta)
        guard allowedDelta != 0 else { return nil }

        let signedDelta = proposedDelta > 0 ? allowedDelta : -allowedDelta
        let proposedTarget = currentTargetKcal + signedDelta

        guard isProposedTargetSafe(
            proposedTargetKcal: proposedTarget,
            tdeeKcal: tdeeKcal,
            calorieFloorKcal: calorieFloorKcal
        ) else {
            return nil
        }

        return signedDelta
    }

    // MARK: Recommendation builders

    private static func notEnoughDataRecommendation(
        summary: WeeklyProgressSummary,
        reasons: [String]
    ) -> WeeklyPlanRecommendation {
        WeeklyPlanRecommendation(
            kind: .notEnoughData,
            confidence: summary.confidence,
            title: "Not enough data yet",
            message: "Your logs are too incomplete for a calorie recommendation yet.",
            suggestedCalorieDelta: nil,
            shouldShowPlanCTA: false,
            ctaTitle: nil,
            reasons: reasons,
            safetyNotes: [automaticChangeDisclaimer]
        )
    }

    private static func holdSteadyRecommendation(
        summary: WeeklyProgressSummary,
        title: String,
        message: String,
        reasons: [String],
        showPlanCTA: Bool
    ) -> WeeklyPlanRecommendation {
        WeeklyPlanRecommendation(
            kind: .holdSteady,
            confidence: summary.confidence,
            title: title,
            message: message,
            suggestedCalorieDelta: nil,
            shouldShowPlanCTA: showPlanCTA,
            ctaTitle: showPlanCTA ? "Review plan" : nil,
            reasons: reasons,
            safetyNotes: [automaticChangeDisclaimer]
        )
    }

    private static func improveConsistencyRecommendation(
        summary: WeeklyProgressSummary,
        extraReason: String? = nil
    ) -> WeeklyPlanRecommendation {
        var reasons = ["Food logging was inconsistent this week."]
        if let extraReason {
            reasons.append(extraReason)
        }

        return WeeklyPlanRecommendation(
            kind: .improveConsistencyFirst,
            confidence: summary.confidence,
            title: "Build consistency first",
            message: "Focus on logging and daily habits before changing your calorie target.",
            suggestedCalorieDelta: nil,
            shouldShowPlanCTA: false,
            ctaTitle: nil,
            reasons: reasons,
            safetyNotes: [
                automaticChangeDisclaimer,
                "Improving consistency is safer than lowering calories when adherence is uneven."
            ]
        )
    }

    private static func waitForNoiseRecommendation(
        summary: WeeklyProgressSummary
    ) -> WeeklyPlanRecommendation {
        WeeklyPlanRecommendation(
            kind: .waitBecauseScaleIsNoisy,
            confidence: summary.confidence,
            title: "Wait before changing calories",
            message: "The scale looks noisy this week, so avoid changing the plan from one weigh-in.",
            suggestedCalorieDelta: nil,
            shouldShowPlanCTA: false,
            ctaTitle: nil,
            reasons: [
                "A sudden weigh-in change can reflect water weight, sodium, or recovery — not true fat trend."
            ],
            safetyNotes: [
                automaticChangeDisclaimer,
                WeeklyProgressConfidencePolicy.holdSteadyDespiteNoiseCopy()
            ]
        )
    }

    private static func reviewManuallyRecommendation(
        summary: WeeklyProgressSummary,
        message: String,
        reasons: [String]
    ) -> WeeklyPlanRecommendation {
        WeeklyPlanRecommendation(
            kind: .reviewPlanManually,
            confidence: summary.confidence,
            title: "Review your plan",
            message: message,
            suggestedCalorieDelta: nil,
            shouldShowPlanCTA: true,
            ctaTitle: "Review plan",
            reasons: reasons,
            safetyNotes: [automaticChangeDisclaimer]
        )
    }

    private static func calorieChangeRecommendation(
        input: PlanRecommendationInput,
        kind: WeeklyPlanRecommendationKind,
        proposedDelta: Int,
        title: String,
        message: String,
        reasons: [String]
    ) -> WeeklyPlanRecommendation {
        let tdee = resolvedTDEE(input: input)

        if let validated = validatedCalorieDelta(
            proposedDelta: proposedDelta,
            currentTargetKcal: input.currentCalorieTargetKcal,
            tdeeKcal: tdee,
            calorieFloorKcal: input.calorieFloorKcal
        ) {
            var notes = [automaticChangeDisclaimer]
            notes.append("Suggested change: \(formattedDelta(validated)) kcal per day if you choose to update.")

            return WeeklyPlanRecommendation(
                kind: kind,
                confidence: input.summary.confidence,
                title: title,
                message: message,
                suggestedCalorieDelta: validated,
                shouldShowPlanCTA: true,
                ctaTitle: "Review plan",
                reasons: reasons,
                safetyNotes: notes
            )
        }

        return reviewManuallyRecommendation(
            summary: input.summary,
            message: "\(message) Open Plan to review safely — an automatic-sized change is not recommended with your current bounds.",
            reasons: reasons + ["Suggested calorie step did not pass safety bounds."]
        )
    }

    // MARK: Helpers

    private static func blockingReasons(
        from sufficiency: WeeklyProgressDataSufficiency
    ) -> [String] {
        if sufficiency.reasons.isEmpty {
            return [sufficiency.userFacingSummary]
        }

        return sufficiency.reasons.map {
            WeeklyProgressConfidencePolicy.insufficientDataCopy(for: [$0])
        }
    }

    private static func calorieAdherenceRate(summary: WeeklyProgressSummary) -> Double {
        guard summary.foodLoggedDays > 0 else { return 0 }
        return Double(summary.calorieTargetHitDays) / Double(summary.foodLoggedDays)
    }

    private static func proposedIncreaseDelta(
        summary: WeeklyProgressSummary,
        currentTargetKcal: Int?
    ) -> Int {
        if weeklyLossRate(summary: summary) >= aggressiveWeeklyLossRate {
            return largerIncreaseDeltaKcal
        }
        return standardIncreaseDeltaKcal
    }

    private static func weeklyLossRate(summary: WeeklyProgressSummary) -> Double {
        guard let weeklyChange = summary.weeklyWeightChangeKg,
              let bodyWeight = summary.endingWeightKg ?? summary.startingWeightKg,
              bodyWeight > 0,
              weeklyChange < 0 else {
            return 0
        }
        return abs(weeklyChange) / bodyWeight
    }

    private static func hasReasonableDeficit(input: PlanRecommendationInput) -> Bool {
        guard let target = input.currentCalorieTargetKcal,
              let tdee = resolvedTDEE(input: input),
              tdee > 0,
              input.goalDirection == .lose else {
            return false
        }

        let deficit = tdee - target
        guard deficit > 0 else { return false }

        let minMeaningfulDeficit = Int(
            (Double(tdee) * FormaCalculationConstants.presetGentleWeeklyLossFraction
                * FormaCalculationConstants.kcalPerKgFat / 7.0).rounded()
        )
        return deficit >= max(minMeaningfulDeficit, 150)
    }

    private static func resolvedTDEE(input: PlanRecommendationInput) -> Int? {
        input.staticTDEEKcal
            ?? input.summary.maintenanceEstimate.staticTDEEKcal
    }

    private static func allowedDeltaMagnitude(for proposedDelta: Int) -> Int {
        switch proposedDelta {
        case ..<0:
            return standardDecreaseDeltaKcal
        case standardIncreaseDeltaKcal:
            return standardIncreaseDeltaKcal
        case largerIncreaseDeltaKcal...:
            return largerIncreaseDeltaKcal
        default:
            return standardIncreaseDeltaKcal
        }
    }

    private static func formattedDelta(_ delta: Int) -> String {
        delta > 0 ? "+\(delta)" : "\(delta)"
    }
}
