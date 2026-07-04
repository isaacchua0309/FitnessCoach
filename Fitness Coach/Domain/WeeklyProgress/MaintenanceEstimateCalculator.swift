//
//  MaintenanceEstimateCalculator.swift
//  Fitness Coach
//
//  Forma — Learned maintenance estimation from real intake and weight trend (PRD §9.11).
//

import Foundation

// MARK: - Types

enum MaintenanceEstimateMethod: String, Codable, Equatable {
    case unavailable
    case trendBucketOnly
    case learnedEnergyBalance
    case conservativeBlend
}

enum MaintenanceTrendDirection: String, Codable, Equatable {
    case losingFasterThanExpected
    case losingAboutAsExpected
    case losingSlowerThanExpected
    case maintaining
    case gaining
    case unclear
}

struct MaintenanceEstimateInput: Equatable {
    let startDate: Date
    let endDate: Date
    let averageDailyCalories: Double?
    let foodLoggedDays: Int
    let totalDays: Int
    /// Logging-history span used for confidence tiers. Defaults to `totalDays` when nil.
    let calendarSpanDays: Int?
    let startingWeightKg: Double?
    let endingWeightKg: Double?
    let currentSevenDayAverageKg: Double?
    let previousSevenDayAverageKg: Double?
    let weightEntryCount: Int
    let staticTDEE: Double?
    let calorieTarget: Double?
    let goalWeightKg: Double?
    let currentWeightKg: Double?
    let hasSuddenSpike: Bool
}

struct MaintenanceEstimate: Equatable {
    let method: MaintenanceEstimateMethod
    let confidence: WeeklyProgressConfidenceLevel
    let estimatedMaintenanceKcal: Int?
    let staticTDEEKcal: Int?
    let averageDailyCalories: Int?
    let estimatedDailyEnergyBalanceKcal: Int?
    let weightChangeKg: Double?
    let weeklyWeightChangeKg: Double?
    let trendDirection: MaintenanceTrendDirection
    let sufficiency: WeeklyProgressDataSufficiency
    let shouldShowWaterWeightDisclaimer: Bool
    let explanation: String
    let caveats: [String]
}

// MARK: - Calculator

enum MaintenanceEstimateCalculator {

    // MARK: Constants

    /// Energy density used in Formula A (matches `FormaCalculationConstants.kcalPerKgFat`).
    private static let kcalPerKgBodyWeightChange = FormaCalculationConstants.kcalPerKgFat

    /// Rounds displayed maintenance to the nearest 25 kcal for readability.
    private static let maintenanceRoundingKcal = 25

    /// Plausible adult maintenance display range (kcal/day).
    private static let plausibleMaintenanceMinimumKcal = 1200
    private static let plausibleMaintenanceMaximumKcal = 4500

    /// Conservative blend weighting for medium confidence when static TDEE is available.
    private static let mediumConfidenceLearnedBlendWeight = 0.60
    private static let mediumConfidenceStaticBlendWeight = 0.40

    // MARK: Trend thresholds (fraction of body weight per week)

    /// Lower bound of a generally reasonable weekly loss rate during a cut (0.25%/week).
    private static let reasonableWeeklyLossRateMin = 0.0025

    /// Upper bound of a generally reasonable weekly loss rate during a cut (1.0%/week).
    private static let reasonableWeeklyLossRateMax = 0.0100

    /// Band for treating weekly change as maintenance (±0.25%/week).
    private static let maintenanceWeeklyChangeBand = 0.0025

    /// Minimum logging ratio treated as “good adherence” when interpreting flat/up scale trends.
    private static let goodAdherenceLoggingRatio = 0.60

    // MARK: Public

    static func estimate(_ input: MaintenanceEstimateInput) -> MaintenanceEstimate {
        let calendarSpanDays = resolvedCalendarSpanDays(for: input)
        let windowDays = max(input.totalDays, 1)
        let consistencySpanDays = max(calendarSpanDays, windowDays)
        let loggingConsistencyRatio = Double(max(input.foodLoggedDays, 0)) / Double(consistencySpanDays)

        let sufficiency = WeeklyProgressConfidencePolicy.evaluate(
            foodLoggedDays: input.foodLoggedDays,
            weightEntryCount: input.weightEntryCount,
            calendarSpanDays: calendarSpanDays,
            hasSuddenSpike: input.hasSuddenSpike,
            loggingConsistencyRatio: loggingConsistencyRatio
        )

        let staticTDEEKcal = roundedKcal(from: input.staticTDEE)
        let averageDailyCalories = roundedKcal(from: input.averageDailyCalories)
        let shouldShowWaterWeightDisclaimer = input.hasSuddenSpike

        guard sufficiency.confidence != .unavailable else {
            return unavailableEstimate(
                input: input,
                sufficiency: sufficiency,
                staticTDEEKcal: staticTDEEKcal,
                averageDailyCalories: averageDailyCalories,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer
            )
        }

        let resolvedWeights = resolvedWeightChange(for: input)
        let weeklyWeightChangeKg = resolvedWeeklyWeightChange(
            for: input,
            weightChangeKg: resolvedWeights.changeKg,
            totalDays: windowDays
        )
        let goalDirection = resolvedGoalDirection(for: input)
        let trendDirection = resolveTrendDirection(
            weeklyWeightChangeKg: weeklyWeightChangeKg,
            bodyWeightKg: resolvedBodyWeightKg(for: input),
            goalDirection: goalDirection,
            loggingConsistencyRatio: loggingConsistencyRatio
        )

        let energyBalance = estimatedDailyEnergyBalanceKcal(
            weightChangeKg: resolvedWeights.changeKg,
            totalDays: windowDays
        )

        if sufficiency.confidence == .low
            || !sufficiency.isEligibleForKcalMaintenanceDisplay {
            return lowConfidenceEstimate(
                input: input,
                sufficiency: sufficiency,
                staticTDEEKcal: staticTDEEKcal,
                averageDailyCalories: averageDailyCalories,
                energyBalance: energyBalance,
                weightChangeKg: resolvedWeights.changeKg,
                weeklyWeightChangeKg: weeklyWeightChangeKg,
                trendDirection: trendDirection,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer
            )
        }

        guard let averageIntake = input.averageDailyCalories,
              let weightChangeKg = resolvedWeights.changeKg,
              let dailyEnergyBalance = energyBalance else {
            return incompleteInputsEstimate(
                input: input,
                sufficiency: sufficiency,
                staticTDEEKcal: staticTDEEKcal,
                averageDailyCalories: averageDailyCalories,
                weightChangeKg: resolvedWeights.changeKg,
                weeklyWeightChangeKg: weeklyWeightChangeKg,
                trendDirection: trendDirection,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer
            )
        }

        let learnedMaintenance = averageIntake + dailyEnergyBalance
        let methodAndValue = resolvedMethodAndMaintenanceKcal(
            learnedMaintenanceKcal: learnedMaintenance,
            staticTDEE: input.staticTDEE,
            confidence: sufficiency.confidence
        )

        guard let displayMaintenance = methodAndValue.maintenanceKcal else {
            return implausibleMaintenanceEstimate(
                input: input,
                sufficiency: sufficiency,
                staticTDEEKcal: staticTDEEKcal,
                averageDailyCalories: averageDailyCalories,
                energyBalance: energyBalance,
                weightChangeKg: weightChangeKg,
                weeklyWeightChangeKg: weeklyWeightChangeKg,
                trendDirection: trendDirection,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
                learnedMaintenanceKcal: learnedMaintenance
            )
        }

        let caveats = buildCaveats(
            sufficiency: sufficiency,
            shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
            method: methodAndValue.method
        )

        return MaintenanceEstimate(
            method: methodAndValue.method,
            confidence: sufficiency.confidence,
            estimatedMaintenanceKcal: displayMaintenance,
            staticTDEEKcal: staticTDEEKcal,
            averageDailyCalories: averageDailyCalories,
            estimatedDailyEnergyBalanceKcal: roundedKcal(from: dailyEnergyBalance),
            weightChangeKg: weightChangeKg,
            weeklyWeightChangeKg: weeklyWeightChangeKg,
            trendDirection: trendDirection,
            sufficiency: sufficiency,
            shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
            explanation: explanation(
                method: methodAndValue.method,
                confidence: sufficiency.confidence,
                estimatedMaintenanceKcal: displayMaintenance,
                staticTDEEKcal: staticTDEEKcal,
                trendDirection: trendDirection
            ),
            caveats: caveats
        )
    }

    // MARK: Formula A

    private static func estimatedDailyEnergyBalanceKcal(
        weightChangeKg: Double?,
        totalDays: Int
    ) -> Double? {
        guard let weightChangeKg, totalDays > 0 else {
            return nil
        }

        // Positive balance means the body was in net deficit over the window (weight fell).
        return -(weightChangeKg * kcalPerKgBodyWeightChange) / Double(totalDays)
    }

    private static func resolvedMethodAndMaintenanceKcal(
        learnedMaintenanceKcal: Double,
        staticTDEE: Double?,
        confidence: WeeklyProgressConfidenceLevel
    ) -> (method: MaintenanceEstimateMethod, maintenanceKcal: Int?) {
        let roundedLearned = roundMaintenanceKcal(learnedMaintenanceKcal)

        switch confidence {
        case .unavailable, .low:
            return (.trendBucketOnly, nil)

        case .medium:
            if let staticTDEE, staticTDEE > 0 {
                let blended = learnedMaintenanceKcal * mediumConfidenceLearnedBlendWeight
                    + staticTDEE * mediumConfidenceStaticBlendWeight
                let rounded = roundMaintenanceKcal(blended)
                guard isPlausibleMaintenanceKcal(rounded) else {
                    return (.unavailable, nil)
                }
                return (.conservativeBlend, rounded)
            }

            guard isPlausibleMaintenanceKcal(roundedLearned) else {
                return (.unavailable, nil)
            }
            return (.learnedEnergyBalance, roundedLearned)

        case .high:
            guard isPlausibleMaintenanceKcal(roundedLearned) else {
                return (.unavailable, nil)
            }
            return (.learnedEnergyBalance, roundedLearned)
        }
    }

    // MARK: Weight resolution

    private struct ResolvedWeightChange {
        let changeKg: Double?
    }

    private static func resolvedWeightChange(for input: MaintenanceEstimateInput) -> ResolvedWeightChange {
        let ending = positiveWeight(input.currentSevenDayAverageKg)
            ?? positiveWeight(input.endingWeightKg)
        let starting = positiveWeight(input.startingWeightKg)

        guard let ending, let starting else {
            return ResolvedWeightChange(changeKg: nil)
        }

        return ResolvedWeightChange(changeKg: ending - starting)
    }

    private static func resolvedWeeklyWeightChange(
        for input: MaintenanceEstimateInput,
        weightChangeKg: Double?,
        totalDays: Int
    ) -> Double? {
        if let current = positiveWeight(input.currentSevenDayAverageKg),
           let previous = positiveWeight(input.previousSevenDayAverageKg) {
            return current - previous
        }

        guard let weightChangeKg, totalDays > 0 else {
            return nil
        }

        let weeks = Double(totalDays) / 7.0
        guard weeks > 0 else { return nil }
        return weightChangeKg / weeks
    }

    // MARK: Trend direction

    private static func resolveTrendDirection(
        weeklyWeightChangeKg: Double?,
        bodyWeightKg: Double?,
        goalDirection: JourneyGoalDirection,
        loggingConsistencyRatio: Double
    ) -> MaintenanceTrendDirection {
        guard let weeklyWeightChangeKg,
              let bodyWeightKg,
              bodyWeightKg > 0 else {
            return .unclear
        }

        let weeklyRate = weeklyWeightChangeKg / bodyWeightKg

        switch goalDirection {
        case .lose:
            let lossRate = -weeklyRate
            if lossRate > reasonableWeeklyLossRateMax {
                return .losingFasterThanExpected
            }
            if lossRate >= reasonableWeeklyLossRateMin {
                return .losingAboutAsExpected
            }
            if loggingConsistencyRatio >= goodAdherenceLoggingRatio {
                return .losingSlowerThanExpected
            }
            return .unclear

        case .maintain:
            if abs(weeklyRate) <= maintenanceWeeklyChangeBand {
                return .maintaining
            }
            if weeklyRate > maintenanceWeeklyChangeBand {
                return .gaining
            }
            return .losingSlowerThanExpected

        case .gain:
            if weeklyRate > reasonableWeeklyLossRateMin {
                return .gaining
            }
            if abs(weeklyRate) <= maintenanceWeeklyChangeBand {
                return .maintaining
            }
            return .unclear
        }
    }

    // MARK: Estimate builders

    private static func unavailableEstimate(
        input: MaintenanceEstimateInput,
        sufficiency: WeeklyProgressDataSufficiency,
        staticTDEEKcal: Int?,
        averageDailyCalories: Int?,
        shouldShowWaterWeightDisclaimer: Bool
    ) -> MaintenanceEstimate {
        MaintenanceEstimate(
            method: .unavailable,
            confidence: .unavailable,
            estimatedMaintenanceKcal: nil,
            staticTDEEKcal: staticTDEEKcal,
            averageDailyCalories: averageDailyCalories,
            estimatedDailyEnergyBalanceKcal: nil,
            weightChangeKg: nil,
            weeklyWeightChangeKg: nil,
            trendDirection: .unclear,
            sufficiency: sufficiency,
            shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
            explanation: sufficiency.userFacingSummary,
            caveats: buildCaveats(
                sufficiency: sufficiency,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
                method: .unavailable
            )
        )
    }

    private static func lowConfidenceEstimate(
        input: MaintenanceEstimateInput,
        sufficiency: WeeklyProgressDataSufficiency,
        staticTDEEKcal: Int?,
        averageDailyCalories: Int?,
        energyBalance: Double?,
        weightChangeKg: Double?,
        weeklyWeightChangeKg: Double?,
        trendDirection: MaintenanceTrendDirection,
        shouldShowWaterWeightDisclaimer: Bool
    ) -> MaintenanceEstimate {
        MaintenanceEstimate(
            method: .trendBucketOnly,
            confidence: sufficiency.confidence,
            estimatedMaintenanceKcal: nil,
            staticTDEEKcal: staticTDEEKcal,
            averageDailyCalories: averageDailyCalories,
            estimatedDailyEnergyBalanceKcal: roundedKcal(from: energyBalance),
            weightChangeKg: weightChangeKg,
            weeklyWeightChangeKg: weeklyWeightChangeKg,
            trendDirection: trendDirection,
            sufficiency: sufficiency,
            shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
            explanation: trendBucketExplanation(
                trendDirection: trendDirection,
                sufficiency: sufficiency,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer
            ),
            caveats: buildCaveats(
                sufficiency: sufficiency,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
                method: .trendBucketOnly
            )
        )
    }

    private static func incompleteInputsEstimate(
        input: MaintenanceEstimateInput,
        sufficiency: WeeklyProgressDataSufficiency,
        staticTDEEKcal: Int?,
        averageDailyCalories: Int?,
        weightChangeKg: Double?,
        weeklyWeightChangeKg: Double?,
        trendDirection: MaintenanceTrendDirection,
        shouldShowWaterWeightDisclaimer: Bool
    ) -> MaintenanceEstimate {
        MaintenanceEstimate(
            method: .trendBucketOnly,
            confidence: sufficiency.confidence,
            estimatedMaintenanceKcal: nil,
            staticTDEEKcal: staticTDEEKcal,
            averageDailyCalories: averageDailyCalories,
            estimatedDailyEnergyBalanceKcal: nil,
            weightChangeKg: weightChangeKg,
            weeklyWeightChangeKg: weeklyWeightChangeKg,
            trendDirection: trendDirection,
            sufficiency: sufficiency,
            shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
            explanation: "We need both consistent food logs and weigh-ins before estimating maintenance.",
            caveats: buildCaveats(
                sufficiency: sufficiency,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
                method: .trendBucketOnly,
                extra: ["Average intake or weight trend is incomplete for this window."]
            )
        )
    }

    private static func implausibleMaintenanceEstimate(
        input: MaintenanceEstimateInput,
        sufficiency: WeeklyProgressDataSufficiency,
        staticTDEEKcal: Int?,
        averageDailyCalories: Int?,
        energyBalance: Double?,
        weightChangeKg: Double?,
        weeklyWeightChangeKg: Double?,
        trendDirection: MaintenanceTrendDirection,
        shouldShowWaterWeightDisclaimer: Bool,
        learnedMaintenanceKcal: Double
    ) -> MaintenanceEstimate {
        return MaintenanceEstimate(
            method: .trendBucketOnly,
            confidence: sufficiency.confidence,
            estimatedMaintenanceKcal: nil,
            staticTDEEKcal: staticTDEEKcal,
            averageDailyCalories: averageDailyCalories,
            estimatedDailyEnergyBalanceKcal: roundedKcal(from: energyBalance),
            weightChangeKg: weightChangeKg,
            weeklyWeightChangeKg: weeklyWeightChangeKg,
            trendDirection: trendDirection,
            sufficiency: sufficiency,
            shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
            explanation: trendBucketExplanation(
                trendDirection: trendDirection,
                sufficiency: sufficiency,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer
            ),
            caveats: buildCaveats(
                sufficiency: sufficiency,
                shouldShowWaterWeightDisclaimer: shouldShowWaterWeightDisclaimer,
                method: .trendBucketOnly,
                extra: [
                    "The calculated maintenance (\(Int(learnedMaintenanceKcal.rounded())) kcal) looked unrealistic for this window, so we are showing trend guidance only."
                ]
            )
        )
    }

    // MARK: Copy

    private static func explanation(
        method: MaintenanceEstimateMethod,
        confidence: WeeklyProgressConfidenceLevel,
        estimatedMaintenanceKcal: Int,
        staticTDEEKcal: Int?,
        trendDirection: MaintenanceTrendDirection
    ) -> String {
        var parts: [String] = []

        switch method {
        case .learnedEnergyBalance:
            parts.append(
                "Based on your logged intake and weight trend, your learned maintenance is about \(estimatedMaintenanceKcal) kcal per day."
            )
        case .conservativeBlend:
            parts.append(
                "Based on your logs blended with your formula estimate, your maintenance is about \(estimatedMaintenanceKcal) kcal per day."
            )
        case .trendBucketOnly, .unavailable:
            break
        }

        if let staticTDEEKcal {
            parts.append("Your formula maintenance estimate is \(staticTDEEKcal) kcal per day.")
        }

        parts.append(trendDirectionSummary(trendDirection))

        if confidence == .medium {
            parts.append("This is a medium-confidence estimate — another week of steady logging will sharpen it.")
        }

        return parts.joined(separator: " ")
    }

    private static func trendBucketExplanation(
        trendDirection: MaintenanceTrendDirection,
        sufficiency: WeeklyProgressDataSufficiency,
        shouldShowWaterWeightDisclaimer: Bool
    ) -> String {
        var parts = [sufficiency.userFacingSummary, trendDirectionSummary(trendDirection)]

        if shouldShowWaterWeightDisclaimer {
            parts.append(WeeklyProgressConfidencePolicy.waterWeightNoiseWarningCopy())
        }

        parts.append("Keep logging — we need a bit more data before showing a precise maintenance number.")
        return parts.joined(separator: " ")
    }

    private static func trendDirectionSummary(_ direction: MaintenanceTrendDirection) -> String {
        switch direction {
        case .losingFasterThanExpected:
            return "Weight is moving faster than a typical weekly pace."
        case .losingAboutAsExpected:
            return "Weight trend looks broadly in line with a steady weekly pace."
        case .losingSlowerThanExpected:
            return "Weight trend is flat or slow for your goal this week."
        case .maintaining:
            return "Weight is holding steady within a small weekly band."
        case .gaining:
            return "Weight trend is moving up this week."
        case .unclear:
            return "Weight trend is still unclear — keep logging weigh-ins."
        }
    }

    private static func buildCaveats(
        sufficiency: WeeklyProgressDataSufficiency,
        shouldShowWaterWeightDisclaimer: Bool,
        method: MaintenanceEstimateMethod,
        extra: [String] = []
    ) -> [String] {
        var caveats: [String] = []

        if shouldShowWaterWeightDisclaimer {
            caveats.append(FormaProductCopy.WeightSpikeEducation.holdSteadyNote)
        }

        if sufficiency.reasons.contains(.inconsistentLogging) {
            caveats.append(
                "Logging was uneven this week, which can make maintenance estimates less reliable."
            )
        }

        if method == .conservativeBlend {
            caveats.append(
                "This estimate blends your real-world trend with your formula maintenance for a steadier read."
            )
        }

        if method == .trendBucketOnly {
            caveats.append(
                "Short windows and limited weigh-ins can hide day-to-day scale swings — weekly averages matter more than one reading."
            )
        }

        caveats.append(contentsOf: extra)
        return caveats
    }

    // MARK: Helpers

    private static func resolvedCalendarSpanDays(for input: MaintenanceEstimateInput) -> Int {
        if let calendarSpanDays = input.calendarSpanDays, calendarSpanDays > 0 {
            return calendarSpanDays
        }

        if input.totalDays > 0 {
            return input.totalDays
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: input.startDate)
        let end = calendar.startOfDay(for: input.endDate)
        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(dayCount + 1, 0)
    }

    private static func resolvedGoalDirection(for input: MaintenanceEstimateInput) -> JourneyGoalDirection {
        JourneyGoalDirection.resolve(
            startWeightKg: input.currentWeightKg,
            goalWeightKg: input.goalWeightKg
        )
    }

    private static func resolvedBodyWeightKg(for input: MaintenanceEstimateInput) -> Double? {
        positiveWeight(input.currentWeightKg)
            ?? positiveWeight(input.currentSevenDayAverageKg)
            ?? positiveWeight(input.endingWeightKg)
            ?? positiveWeight(input.startingWeightKg)
    }

    private static func positiveWeight(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private static func roundMaintenanceKcal(_ value: Double) -> Int {
        let rounded = (value / Double(maintenanceRoundingKcal)).rounded() * Double(maintenanceRoundingKcal)
        return Int(rounded)
    }

    private static func roundedKcal(from value: Double?) -> Int? {
        guard let value else { return nil }
        return Int(value.rounded())
    }

    private static func isPlausibleMaintenanceKcal(_ value: Int) -> Bool {
        value >= plausibleMaintenanceMinimumKcal && value <= plausibleMaintenanceMaximumKcal
    }
}
