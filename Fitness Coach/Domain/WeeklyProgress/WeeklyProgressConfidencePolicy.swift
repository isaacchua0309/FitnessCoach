//
//  WeeklyProgressConfidencePolicy.swift
//  Fitness Coach
//
//  Forma — Shared confidence and data sufficiency gates for Weekly Progress Loop v1.
//

import Foundation

// MARK: - Types

enum WeeklyProgressConfidenceLevel: String, Codable, Equatable, CaseIterable {
    case unavailable
    case low
    case medium
    case high
}

enum WeeklyProgressInsufficientDataReason: String, Codable, Equatable, CaseIterable {
    case notEnoughFoodLoggedDays
    case notEnoughWeightEntries
    case notEnoughCalendarSpan
    case inconsistentLogging
    case weightTrendTooNoisy
    case missingProfile
    case missingTargets
}

struct WeeklyProgressDataSufficiency: Equatable {
    let confidence: WeeklyProgressConfidenceLevel
    let isEligibleForMaintenanceEstimate: Bool
    let isEligibleForKcalMaintenanceDisplay: Bool
    let isEligibleForPlanRecommendation: Bool
    let foodLoggedDays: Int
    let weightEntryCount: Int
    let calendarSpanDays: Int
    let reasons: [WeeklyProgressInsufficientDataReason]
    let userFacingSummary: String
}

// MARK: - Policy

enum WeeklyProgressConfidencePolicy {

    // MARK: Thresholds

    static let minimumCalendarSpanDays = 7
    static let minimumFoodLoggedDays = 5
    static let minimumWeightEntries = 3

    static let lowConfidenceMaximumDays = 13
    static let mediumConfidenceMaximumDays = 27

    /// Minimum ratio of food-logged days to calendar span for kcal maintenance display.
    static let minimumLoggingConsistencyRatioForKcalDisplay = 0.70

    /// Minimum ratio of food-logged days to calendar span for any plan recommendation.
    static let minimumLoggingConsistencyRatioForPlanRecommendation = 0.60

    // MARK: Evaluate

    static func evaluate(
        foodLoggedDays: Int,
        weightEntryCount: Int,
        calendarSpanDays: Int,
        hasSuddenSpike: Bool,
        loggingConsistencyRatio: Double
    ) -> WeeklyProgressDataSufficiency {
        let normalizedFoodDays = max(foodLoggedDays, 0)
        let normalizedWeightCount = max(weightEntryCount, 0)
        let normalizedSpanDays = max(calendarSpanDays, 0)
        let normalizedConsistency = clampedRatio(loggingConsistencyRatio)

        var blockingReasons: [WeeklyProgressInsufficientDataReason] = []

        if normalizedSpanDays < minimumCalendarSpanDays {
            blockingReasons.append(.notEnoughCalendarSpan)
        }
        if normalizedFoodDays < minimumFoodLoggedDays {
            blockingReasons.append(.notEnoughFoodLoggedDays)
        }
        if normalizedWeightCount < minimumWeightEntries {
            blockingReasons.append(.notEnoughWeightEntries)
        }

        if !blockingReasons.isEmpty {
            return makeUnavailable(
                foodLoggedDays: normalizedFoodDays,
                weightEntryCount: normalizedWeightCount,
                calendarSpanDays: normalizedSpanDays,
                reasons: blockingReasons
            )
        }

        var reasons: [WeeklyProgressInsufficientDataReason] = []

        let hasPoorLoggingConsistency = normalizedConsistency
            < minimumLoggingConsistencyRatioForPlanRecommendation
        if hasPoorLoggingConsistency {
            reasons.append(.inconsistentLogging)
        }

        if hasSuddenSpike {
            reasons.append(.weightTrendTooNoisy)
        }

        var confidence = confidenceLevel(forCalendarSpanDays: normalizedSpanDays)

        if confidence == .high,
           normalizedConsistency < minimumLoggingConsistencyRatioForKcalDisplay {
            confidence = .medium
        }

        let isEligibleForMaintenanceEstimate = true
        let isEligibleForKcalMaintenanceDisplay = canShowLearnedMaintenance(
            confidence: confidence,
            loggingConsistencyRatio: normalizedConsistency
        )
        let isEligibleForPlanRecommendation = canShowPlanRecommendation(
            confidence: confidence,
            loggingConsistencyRatio: normalizedConsistency
        )

        let summary = userFacingSummary(
            confidence: confidence,
            reasons: reasons,
            hasSuddenSpike: hasSuddenSpike
        )

        return WeeklyProgressDataSufficiency(
            confidence: confidence,
            isEligibleForMaintenanceEstimate: isEligibleForMaintenanceEstimate,
            isEligibleForKcalMaintenanceDisplay: isEligibleForKcalMaintenanceDisplay,
            isEligibleForPlanRecommendation: isEligibleForPlanRecommendation,
            foodLoggedDays: normalizedFoodDays,
            weightEntryCount: normalizedWeightCount,
            calendarSpanDays: normalizedSpanDays,
            reasons: reasons,
            userFacingSummary: summary
        )
    }

    /// Evaluates sufficiency when profile or target context is missing.
    static func evaluate(
        foodLoggedDays: Int,
        weightEntryCount: Int,
        calendarSpanDays: Int,
        hasSuddenSpike: Bool,
        loggingConsistencyRatio: Double,
        hasProfile: Bool,
        hasTargets: Bool
    ) -> WeeklyProgressDataSufficiency {
        let result = evaluate(
            foodLoggedDays: foodLoggedDays,
            weightEntryCount: weightEntryCount,
            calendarSpanDays: calendarSpanDays,
            hasSuddenSpike: hasSuddenSpike,
            loggingConsistencyRatio: loggingConsistencyRatio
        )

        guard result.confidence != .unavailable else {
            return result
        }

        var reasons = result.reasons
        if !hasProfile {
            reasons.append(.missingProfile)
        }
        if !hasTargets {
            reasons.append(.missingTargets)
        }

        guard !reasons.contains(.missingProfile), !reasons.contains(.missingTargets) else {
            return WeeklyProgressDataSufficiency(
                confidence: .unavailable,
                isEligibleForMaintenanceEstimate: false,
                isEligibleForKcalMaintenanceDisplay: false,
                isEligibleForPlanRecommendation: false,
                foodLoggedDays: result.foodLoggedDays,
                weightEntryCount: result.weightEntryCount,
                calendarSpanDays: result.calendarSpanDays,
                reasons: orderedUniqueReasons(reasons),
                userFacingSummary: insufficientDataCopy(
                for: orderedUniqueReasons(reasons),
                foodLoggedDays: result.foodLoggedDays
            )
            )
        }

        return result
    }

    // MARK: Eligibility helpers

    static func canShowLearnedMaintenance(
        confidence: WeeklyProgressConfidenceLevel,
        loggingConsistencyRatio: Double
    ) -> Bool {
        guard confidence == .medium || confidence == .high else {
            return false
        }
        return clampedRatio(loggingConsistencyRatio)
            >= minimumLoggingConsistencyRatioForKcalDisplay
    }

    static func canShowLearnedMaintenance(_ sufficiency: WeeklyProgressDataSufficiency) -> Bool {
        sufficiency.isEligibleForKcalMaintenanceDisplay
    }

    static func canShowPlanRecommendation(
        confidence: WeeklyProgressConfidenceLevel,
        loggingConsistencyRatio: Double
    ) -> Bool {
        guard confidence != .unavailable else {
            return false
        }
        return clampedRatio(loggingConsistencyRatio)
            >= minimumLoggingConsistencyRatioForPlanRecommendation
    }

    static func canShowPlanRecommendation(_ sufficiency: WeeklyProgressDataSufficiency) -> Bool {
        sufficiency.isEligibleForPlanRecommendation
    }

    /// Whether a precise calorie adjustment (not hold-steady) is appropriate.
    static func canRecommendPreciseCalorieAdjustment(_ sufficiency: WeeklyProgressDataSufficiency) -> Bool {
        guard sufficiency.isEligibleForPlanRecommendation else {
            return false
        }
        guard sufficiency.confidence == .medium || sufficiency.confidence == .high else {
            return false
        }
        return !sufficiency.reasons.contains(.weightTrendTooNoisy)
            && !sufficiency.reasons.contains(.inconsistentLogging)
    }

    // MARK: Copy helpers

    static func confidenceCopy(
        for confidence: WeeklyProgressConfidenceLevel,
        hasSuddenSpike: Bool = false
    ) -> String {
        let base: String
        switch confidence {
        case .unavailable:
            base = "Keep logging a few more days before we estimate maintenance."
        case .low:
            base = "Your estimate is still low confidence because the week has limited weight data."
        case .medium:
            base = "Medium confidence — based on two weeks of consistent logging."
        case .high:
            base = "High confidence — based on a month of steady logging and weigh-ins."
        }

        if hasSuddenSpike, confidence != .unavailable {
            return base + FormaProductCopy.WeightSpikeEducation.confidenceSuffix
        }

        return base
    }

    static func insufficientDataCopy(
        for reasons: [WeeklyProgressInsufficientDataReason],
        foodLoggedDays: Int = 0
    ) -> String {
        let ordered = orderedUniqueReasons(reasons)
        guard let primary = ordered.first else {
            return "Keep logging a few more days before we estimate maintenance."
        }

        switch primary {
        case .notEnoughCalendarSpan:
            return "Keep logging a few more days before we estimate maintenance."
        case .notEnoughFoodLoggedDays:
            if foodLoggedDays == 0 {
                return FormaProductCopy.Journey.NextBestAction.logFirstMealDetail
            }
            return FormaProductCopy.Journey.NextBestAction.logMealsConsistentlyDetail
        case .notEnoughWeightEntries:
            return "Add a few more weigh-ins this week before we estimate maintenance."
        case .inconsistentLogging:
            return "Logging has been uneven this week. A steadier week will make your estimate clearer."
        case .weightTrendTooNoisy:
            return FormaProductCopy.WeightSpikeEducation.shortBody
        case .missingProfile:
            return "Finish setting up your plan before we estimate maintenance."
        case .missingTargets:
            return "Your calorie targets are not set yet. Update your plan to unlock weekly guidance."
        }
    }

    static func waterWeightNoiseWarningCopy() -> String {
        FormaProductCopy.WeightSpikeEducation.shortBody
    }

    static func holdSteadyDespiteNoiseCopy() -> String {
        FormaProductCopy.WeightSpikeEducation.holdSteadyNote
    }

    // MARK: Private

    private static func confidenceLevel(
        forCalendarSpanDays spanDays: Int
    ) -> WeeklyProgressConfidenceLevel {
        if spanDays >= highConfidenceMinimumDays {
            return .high
        }
        if spanDays >= mediumConfidenceMinimumDays {
            return .medium
        }
        return .low
    }

    private static var mediumConfidenceMinimumDays: Int { minimumCalendarSpanDays + 7 }
    private static var highConfidenceMinimumDays: Int { 28 }

    private static func makeUnavailable(
        foodLoggedDays: Int,
        weightEntryCount: Int,
        calendarSpanDays: Int,
        reasons: [WeeklyProgressInsufficientDataReason]
    ) -> WeeklyProgressDataSufficiency {
        let ordered = orderedUniqueReasons(reasons)
        return WeeklyProgressDataSufficiency(
            confidence: .unavailable,
            isEligibleForMaintenanceEstimate: false,
            isEligibleForKcalMaintenanceDisplay: false,
            isEligibleForPlanRecommendation: false,
            foodLoggedDays: foodLoggedDays,
            weightEntryCount: weightEntryCount,
            calendarSpanDays: calendarSpanDays,
            reasons: ordered,
            userFacingSummary: insufficientDataCopy(for: ordered, foodLoggedDays: foodLoggedDays)
        )
    }

    private static func userFacingSummary(
        confidence: WeeklyProgressConfidenceLevel,
        reasons: [WeeklyProgressInsufficientDataReason],
        hasSuddenSpike: Bool
    ) -> String {
        if reasons.contains(.inconsistentLogging) {
            return insufficientDataCopy(for: [.inconsistentLogging])
        }

        return confidenceCopy(for: confidence, hasSuddenSpike: hasSuddenSpike)
    }

    private static func orderedUniqueReasons(
        _ reasons: [WeeklyProgressInsufficientDataReason]
    ) -> [WeeklyProgressInsufficientDataReason] {
        var seen = Set<WeeklyProgressInsufficientDataReason>()
        var ordered: [WeeklyProgressInsufficientDataReason] = []
        for reason in reasons where seen.insert(reason).inserted {
            ordered.append(reason)
        }
        return ordered
    }

    private static func clampedRatio(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
