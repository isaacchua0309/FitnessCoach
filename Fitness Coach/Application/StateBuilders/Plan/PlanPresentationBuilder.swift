//
//  PlanPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic builders for Plan presentation state.
//

import Foundation

enum PlanPresentationBuilder {

    static func dashboardState(
        context: PlanDashboardContext,
        referenceDate: Date? = nil
    ) -> PlanDashboardState {
        let asOf = referenceDate ?? context.asOf
        let planResult = planResult(from: context.profile, referenceDate: asOf)
        let baseline = resolveBaseline(context: context, asOf: asOf)
        let rationale = rationaleState(
            profile: context.profile,
            result: planResult,
            referenceDate: asOf
        )
        let (strategy, status) = PlanStrategyStateBuilder.build(
            context: context,
            baseline: baseline,
            asOf: asOf
        )

        return PlanDashboardState(
            profile: context.profile,
            strategy: strategy,
            dailyTargets: DailyTargetsStateBuilder.build(profile: context.profile),
            status: status,
            explanation: PlanExplanationStateBuilder.build(from: rationale),
            confidence: PlanConfidenceStateBuilder.build(
                context: context,
                planResult: planResult,
                baseline: baseline
            ),
            adjustmentRules: AdjustmentRulesStateBuilder.build(
                profile: context.profile,
                planResult: planResult
            ),
            assumptions: PlanAssumptionsStateBuilder.build(context: context, asOf: asOf),
            review: PlanReviewStateBuilder.build(
                profile: context.profile,
                planResult: planResult,
                referenceDate: asOf,
                calendar: context.calendar
            ),
            adjustPlanCTA: AdjustPlanCTAStateBuilder.build()
        )
    }

    static func planResult(
        from profile: UserProfile,
        referenceDate: Date
    ) -> PlanCalculationResult? {
        try? PlanCalculationBridge.planResult(from: profile, referenceDate: referenceDate)
    }

    static func rationaleState(
        profile: UserProfile,
        result: PlanCalculationResult?,
        referenceDate: Date
    ) -> PlanRationaleState {
        if let result {
            return PlanRationaleCopyBuilder.build(
                profile: profile,
                result: result,
                referenceDate: referenceDate
            )
        }
        return PlanRationaleState.fallback(for: profile)
    }

    private static func resolveBaseline(
        context: PlanDashboardContext,
        asOf: Date
    ) -> JourneyBaseline {
        let projection = ProgressProjectionCalculator.projection(
            weights: context.allWeights,
            goalWeightKg: context.profile.goalWeightKg,
            asOf: asOf
        )
        return JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: context.profile,
                allWeights: context.allWeights,
                maturityLogs: context.weekLogs,
                goalProjection: projection,
                asOf: asOf,
                calendar: context.calendar
            )
        )
    }
}

// MARK: - Strategy + status

enum PlanStrategyStateBuilder {

    static func build(
        context: PlanDashboardContext,
        baseline: JourneyBaseline,
        asOf: Date
    ) -> (PlanStrategyState, PlanStatusState) {
        let profile = context.profile
        let direction = goalDirection(for: profile)
        let goalKg = profile.goalWeightKg
        let startKg = baseline.startWeightKg ?? profile.currentWeightKg
        let totalChange = abs(goalKg - startKg)
        let totalToLoseOrGain = direction == .maintain || totalChange <= 0.1 ? nil : totalChange

        return PlanMissionHeroCopyBuilder.buildPresentation(
            input: PlanMissionHeroCopyBuilder.Input(
                goalDirection: direction,
                totalChangeKg: totalToLoseOrGain,
                calorieTargetKcal: profile.targets.calorieTarget,
                expectedWeeklyChangeKg: profile.targets.expectedWeeklyWeightLossKg,
                aggressiveness: profile.targets.aggressiveness
            ),
            context: context,
            profile: profile,
            baseline: baseline,
            asOf: asOf,
            calendar: context.calendar
        )
    }

    static func goalDirection(for profile: UserProfile) -> PlanGoalDirection {
        switch PlanStateBuilder.goalType(for: profile) {
        case .loseFat: return .lose
        case .gainMuscle: return .gain
        case .maintain: return .maintain
        }
    }
}

// MARK: - Daily targets

enum DailyTargetsStateBuilder {

    static func build(profile: UserProfile) -> DailyTargetsState {
        let targets = profile.targets
        let direction = PlanStrategyStateBuilder.goalDirection(for: profile)

        let caloriesLabel = label(forKcal: targets.calorieTarget)
        let proteinLabel = macroLabel(targets.proteinTarget, suffix: "protein")
        let carbsLabel = macroLabel(targets.carbTarget, suffix: "carbs")
        let fatLabel = macroLabel(targets.fatTarget, suffix: "fat")
        let waterLabel = waterLabel(for: targets.waterTargetMl)
        let summaryCopy = summaryCopy(
            weeklyKg: targets.expectedWeeklyWeightLossKg,
            direction: direction
        )

        var state = DailyTargetsState(
            sectionTitle: FormaProductCopy.PlanMissionControl.todayMissionSectionTitle,
            caloriesLabel: caloriesLabel,
            proteinLabel: proteinLabel,
            carbsLabel: carbsLabel,
            fatLabel: fatLabel,
            waterLabel: waterLabel,
            summaryCopy: summaryCopy,
            goToTodayTitle: FormaProductCopy.PlanMissionControl.goToToday,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    static func label(forKcal kcal: Int) -> String {
        guard kcal > 0 else { return FormaProductCopy.PlanMissionControl.targetUnavailable }
        return PlanFormatter.kcal(kcal)
    }

    static func macroLabel(_ value: Double, suffix: String) -> String {
        guard value > 0 else { return FormaProductCopy.PlanMissionControl.targetUnavailable }
        return "\(PlanFormatter.gramsCompact(value)) \(suffix)"
    }

    static func waterLabel(for ml: Int) -> String {
        guard ml > 0 else { return FormaProductCopy.PlanMissionControl.targetUnavailable }
        return "\(PlanFormatter.litersCompact(ml)) water"
    }

    static func summaryCopy(weeklyKg: Double?, direction: PlanGoalDirection) -> String {
        if direction == .lose, let weeklyKg, weeklyKg > 0 {
            let formatted = weeklyKg.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(weeklyKg)) kg"
                : String(format: "%.1f kg", weeklyKg)
            return FormaProductCopy.PlanMissionControl.todayMissionDesignedForProgress(formatted)
        }
        return FormaProductCopy.PlanMissionControl.todayMissionProgressFallback(for: direction)
    }

    private static func accessibilitySummary(for state: DailyTargetsState) -> String {
        [
            state.sectionTitle,
            state.caloriesLabel,
            state.proteinLabel,
            state.carbsLabel,
            state.fatLabel,
            state.waterLabel,
            state.summaryCopy
        ].joined(separator: ". ")
    }
}

// MARK: - Explanation

enum PlanExplanationStateBuilder {

    static func build(from rationale: PlanRationaleState) -> PlanExplanationState {
        PlanExplanationState(
            sectionTitle: FormaProductCopy.PlanRationale.sectionTitle,
            summary: rationale.summary,
            highlights: rationale.highlights,
            flowSteps: rationale.flowSteps,
            basedOnItems: rationale.basedOnItems,
            seeCalculationTitle: rationale.seeCalculationTitle,
            sustainabilityNote: rationale.sustainabilityNote,
            calculationDetails: rationale.calculationDetails,
            accessibilitySummary: rationale.accessibilitySummary
        )
    }
}

// MARK: - Assumptions

enum PlanAssumptionsStateBuilder {

    private static let defaultsResolver = ActivityTrainingDefaultsResolver()

    static func build(context: PlanDashboardContext, asOf: Date) -> PlanAssumptionsState {
        let profile = context.profile
        let defaults = defaultsResolver.defaults(for: profile.activityLevel)
        let usesDefaults = profile.trainingFrequencyPerWeek == defaults.trainingDaysPerWeek
            && profile.averageSteps == defaults.averageStepsPerDay
        let stepsLabel = "\(TodayActivitySectionFormatting.formatSteps(profile.averageSteps))/day"

        var state = PlanAssumptionsState(
            activityLevel: PlanFormatter.activityLevel(profile.activityLevel),
            estimatedStepsPerDay: profile.averageSteps,
            estimatedStepsLabel: stepsLabel,
            trainingSessionsPerWeek: profile.trainingFrequencyPerWeek,
            trainingSessionsLabel: trainingSessionsLabel(profile.trainingFrequencyPerWeek),
            usesActivityLevelDefaults: usesDefaults,
            resolvedAgeYears: profile.resolvedAge(referenceDate: asOf),
            ageLabel: PlanFormatter.age(profile.resolvedAge(referenceDate: asOf)),
            heightLabel: PlanFormatter.cm(profile.heightCm),
            sexLabel: PlanFormatter.sex(profile.sex),
            sectionTitle: FormaProductCopy.PlanMissionControl.planAssumptionsSectionTitle,
            activityFieldLabel: FormaProductCopy.PlanMissionControl.planAssumptionsActivity,
            estimatedStepsFieldLabel: FormaProductCopy.PlanMissionControl.planAssumptionsEstimatedSteps,
            trainingFieldLabel: FormaProductCopy.PlanMissionControl.planAssumptionsTraining,
            assumptionsNote: FormaProductCopy.PlanMissionControl.planAssumptionsNote,
            adjustActivityTitle: FormaProductCopy.PlanMissionControl.adjustActivity,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    private static func accessibilitySummary(for state: PlanAssumptionsState) -> String {
        [
            state.sectionTitle,
            "\(state.activityFieldLabel), \(state.activityLevel)",
            "\(state.estimatedStepsFieldLabel), \(state.estimatedStepsLabel)",
            "\(state.trainingFieldLabel), \(state.trainingSessionsLabel)",
            state.assumptionsNote
        ].joined(separator: ". ")
    }

    private static func trainingSessionsLabel(_ count: Int) -> String {
        count == 1 ? "1 session/week" : "\(count) sessions/week"
    }
}

// MARK: - Confidence

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
        var whyItems: [PlanConfidenceReasonItem] = []
        var missingItems: [PlanConfidenceReasonItem] = []

        whyItems.append(
            PlanConfidenceReasonItem(
                id: "activity",
                text: FormaProductCopy.PlanMissionControl.confidenceActivityLevelSelected
            )
        )
        score += 8

        if hasBirthdayAndHeight {
            whyItems.append(
                PlanConfidenceReasonItem(
                    id: "profile",
                    text: FormaProductCopy.PlanMissionControl.confidenceBirthdayHeightAvailable
                )
            )
            score += 12
        } else {
            missingItems.append(
                PlanConfidenceReasonItem(
                    id: "profile",
                    text: FormaProductCopy.PlanMissionControl.missingBirthdayHeight
                )
            )
            if profile.birthDate != nil || profile.heightCm > 0 {
                score += 5
            }
        }

        if let result = planResult {
            switch result.safetyLevel {
            case .ok:
                score += 15
                whyItems.append(
                    PlanConfidenceReasonItem(
                        id: "targets",
                        text: FormaProductCopy.PlanMissionControl.confidenceTargetsReasonable
                    )
                )
            case .caution, .strongWarning:
                score += result.safetyLevel == .caution ? 10 : 6
                whyItems.append(
                    PlanConfidenceReasonItem(
                        id: "targets",
                        text: FormaProductCopy.PlanMissionControl.confidenceTargetsGuardrailed
                    )
                )
            case .error:
                missingItems.append(
                    PlanConfidenceReasonItem(
                        id: "targets",
                        text: FormaProductCopy.PlanMissionControl.missingCalculation
                    )
                )
            }
        } else {
            missingItems.append(
                PlanConfidenceReasonItem(
                    id: "targets",
                    text: FormaProductCopy.PlanMissionControl.missingCalculation
                )
            )
        }

        if hasRecentWeight {
            whyItems.append(
                PlanConfidenceReasonItem(
                    id: "weight",
                    text: FormaProductCopy.PlanMissionControl.confidenceRecentWeightLogged
                )
            )
            score += 12
        } else {
            missingItems.append(
                PlanConfidenceReasonItem(
                    id: "weight",
                    text: FormaProductCopy.PlanMissionControl.missingRecentWeighIn
                )
            )
            if hasAnyWeight { score += 4 }
        }

        if foodDays >= consistentFoodLogDays {
            whyItems.append(
                PlanConfidenceReasonItem(
                    id: "logging",
                    text: FormaProductCopy.PlanMissionControl.confidenceConsistentFoodLogging
                )
            )
            score += 10
        } else {
            missingItems.append(
                PlanConfidenceReasonItem(
                    id: "logging",
                    text: FormaProductCopy.PlanMissionControl.missingFoodLogs
                )
            )
            if foodDays >= partialFoodLogDays { score += 5 }
        }

        if isAppleHealthConnected {
            whyItems.append(
                PlanConfidenceReasonItem(
                    id: "appleHealth",
                    text: FormaProductCopy.PlanMissionControl.confidenceAppleHealthConnected
                )
            )
            score += 5
        } else if showsAppleHealth {
            missingItems.append(
                PlanConfidenceReasonItem(
                    id: "appleHealth",
                    text: FormaProductCopy.PlanMissionControl.missingAppleHealthConnection
                )
            )
        }

        score = applyEngagementCap(
            score: score,
            hasRecentWeight: hasRecentWeight,
            hasAnyWeight: hasAnyWeight,
            foodDays: foodDays
        )

        let clamped = min(100, max(0, score))
        let footerCopy = FormaProductCopy.PlanMissionControl.confidenceSafeCopy
        let appleHealthStatusLabel = showsAppleHealth
            ? TrainingIntegrationCopy.planCardStatusLabel(for: context.integrationState)
            : nil
        let showsAppleHealthAction = showsAppleHealth && !isAppleHealthConnected

        var state = PlanConfidenceState(
            confidenceScore: clamped,
            confidenceLevel: confidenceLevel(for: clamped),
            sectionTitle: FormaProductCopy.PlanMissionControl.planConfidenceSectionTitle,
            scoreLabel: FormaProductCopy.PlanMissionControl.planConfidenceScore(clamped),
            whyHeading: FormaProductCopy.PlanMissionControl.planConfidenceWhyHeading,
            missingHeading: FormaProductCopy.PlanMissionControl.planConfidenceMissingHeading,
            whyItems: whyItems,
            missingItems: missingItems,
            footerCopy: footerCopy,
            showsAppleHealthStatus: showsAppleHealth,
            appleHealthStatusLabel: appleHealthStatusLabel,
            showsAppleHealthAction: showsAppleHealthAction,
            appleHealthActionTitle: showsAppleHealthAction
                ? TrainingIntegrationCopy.connectAppleHealth
                : nil,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
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

    private static func confidenceLevel(for score: Int) -> ConfidenceLevel {
        switch score {
        case 75...: return .high
        case 50..<75: return .medium
        default: return .low
        }
    }

    private static func accessibilitySummary(for state: PlanConfidenceState) -> String {
        var parts = [state.sectionTitle, state.scoreLabel]
        if !state.whyItems.isEmpty {
            parts.append(state.whyHeading)
            parts.append(contentsOf: state.whyItems.map(\.text))
        }
        if !state.missingItems.isEmpty {
            parts.append(state.missingHeading)
            parts.append(contentsOf: state.missingItems.map(\.text))
        }
        if state.showsAppleHealthStatus, let appleHealthStatusLabel = state.appleHealthStatusLabel {
            parts.append(
                "\(FormaProductCopy.PlanMissionControl.planAssumptionsAppleHealth), \(appleHealthStatusLabel)"
            )
        }
        parts.append(state.footerCopy)
        return parts.joined(separator: ". ")
    }
}

// MARK: - Adjustment rules

enum AdjustmentRulesStateBuilder {

    static func build(
        profile: UserProfile,
        planResult: PlanCalculationResult?
    ) -> AdjustmentRulesState {
        let direction = PlanStrategyStateBuilder.goalDirection(for: profile)
        var rules = [
            AdjustmentRuleItem(
                id: "activity",
                text: FormaProductCopy.PlanMissionControl.adjustmentRuleActivityChange()
            ),
            AdjustmentRuleItem(
                id: "pace",
                text: FormaProductCopy.PlanMissionControl.adjustmentRulePaceReview(for: direction)
            ),
            AdjustmentRuleItem(
                id: "stall",
                text: FormaProductCopy.PlanMissionControl.adjustmentRuleWeightStall(for: direction)
            )
        ]

        if let result = planResult, result.safetyLevel == .strongWarning {
            rules.append(
                AdjustmentRuleItem(
                    id: "safety",
                    text: FormaProductCopy.PlanMissionControl.confidenceTargetsGuardrailed
                )
            )
        }

        let footerCopy = FormaProductCopy.PlanMissionControl.adjustmentRulesFooter
        var state = AdjustmentRulesState(
            sectionTitle: FormaProductCopy.PlanMissionControl.adjustmentRulesSectionTitle,
            rules: rules,
            footerCopy: footerCopy,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = [
            state.sectionTitle,
            rules.map(\.text).joined(separator: ". "),
            footerCopy
        ].joined(separator: ". ")
        return state
    }
}

// MARK: - Review

enum PlanReviewStateBuilder {

    private static let profileEditGraceInterval: TimeInterval = 120

    static func build(
        profile: UserProfile,
        planResult: PlanCalculationResult?,
        referenceDate: Date,
        calendar: Calendar
    ) -> PlanReviewState {
        let relativeUpdatedLabel = PlanLastUpdatedLabelFormatter.label(
            for: profile.updatedAt,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let lastUpdateReasonCopy = resolveLastUpdateReason(profile: profile)
        let showsRecalculateHint = showsTargetRecalculateHint(profile: profile, planResult: planResult)

        var state = PlanReviewState(
            lastUpdatedLabel: "\(FormaProductCopy.PlanMissionControl.planReviewLastUpdatedPrefix) \(relativeUpdatedLabel)",
            lastUpdateReasonCopy: lastUpdateReasonCopy,
            showsRecalculateHint: showsRecalculateHint,
            recalculateHintCopy: showsRecalculateHint
                ? FormaProductCopy.PlanMissionControl.planReviewRecalculateHint
                : nil,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = [
            state.lastUpdatedLabel,
            lastUpdateReasonCopy,
            state.recalculateHintCopy
        ].compactMap { $0 }.joined(separator: ". ")
        return state
    }

    private static func showsTargetRecalculateHint(
        profile: UserProfile,
        planResult: PlanCalculationResult?
    ) -> Bool {
        guard let result = planResult else { return false }
        let stored = profile.targets.calorieTarget
        let computed = result.calorieTargetKcal
        let delta = abs(Double(stored - computed)) / Double(max(stored, 1))
        return delta > 0.05
    }

    private static func resolveLastUpdateReason(profile: UserProfile) -> String {
        if let reason = profile.lastPlanUpdateReason {
            return FormaProductCopy.PlanMissionControl.planUpdateReason(reason)
        }
        if profile.updatedAt.timeIntervalSince(profile.createdAt) > profileEditGraceInterval {
            return FormaProductCopy.PlanMissionControl.planUpdatedAfterEdit
        }
        return FormaProductCopy.PlanMissionControl.planCreatedFromOnboarding
    }
}

// MARK: - Adjust CTA

enum AdjustPlanCTAStateBuilder {

    static func build(isEnabled: Bool = true) -> AdjustPlanCTAState {
        AdjustPlanCTAState(
            title: FormaProductCopy.PlanMissionControl.adjustPlan,
            isEnabled: isEnabled,
            accessibilityHint: FormaProductCopy.PlanMissionControl.adjustPlanAccessibilityHint
        )
    }
}

// MARK: - Rationale metrics

enum PlanRationaleMetricsBuilder {

    static func build(
        profile: UserProfile,
        result: PlanCalculationResult,
        referenceDate: Date = Date()
    ) -> PlanRationaleMetrics {
        let deficitOrSurplus: Int?
        let deficitLabel: String?

        switch result.goalDirection {
        case .cut where result.dailyDeficitKcal > 0:
            deficitOrSurplus = result.dailyDeficitKcal
            deficitLabel = FormaProductCopy.PlanRationale.healthyDeficit
        case .gain:
            let surplus = result.calorieTargetKcal - result.tdeeKcal
            if surplus > 0 {
                deficitOrSurplus = surplus
                deficitLabel = FormaProductCopy.PlanRationale.healthySurplus
            } else {
                deficitOrSurplus = nil
                deficitLabel = nil
            }
        default:
            deficitOrSurplus = nil
            deficitLabel = nil
        }

        let age = profile.resolvedAge(referenceDate: referenceDate)
        let activity = PlanFormatter.activityLevel(profile.activityLevel)
        let explanation = """
        BMR \(PlanDisplayFormatter.formatKcalPerDay(result.bmrKcal)) · TDEE \(PlanDisplayFormatter.formatKcalPerDay(result.tdeeKcal)) · \(FormaProductCopy.PlanRationale.birthdayDerivedAge) \(age) · \(activity)
        """

        return PlanRationaleMetrics(
            maintenanceCaloriesKcal: result.tdeeKcal,
            deficitOrSurplusKcal: deficitOrSurplus,
            deficitOrSurplusLabel: deficitLabel,
            targetCaloriesKcal: result.calorieTargetKcal,
            bmrKcal: result.bmrKcal,
            tdeeKcal: result.tdeeKcal,
            energyExplanation: explanation
        )
    }
}

// Legacy aliases for transitional callers.

typealias PlanDashboardBuilder = PlanPresentationBuilder
typealias PlanTodayMissionStateBuilder = DailyTargetsStateBuilder
