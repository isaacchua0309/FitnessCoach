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
        let strategy = PlanStrategyStateBuilder.build(
            context: context,
            baseline: baseline,
            asOf: asOf
        )
        let status = PlanStatusStateBuilder.build(
            profile: context.profile,
            planResult: planResult,
            referenceDate: asOf
        )

        return PlanDashboardState(
            profile: context.profile,
            header: PlanHeaderStateBuilder.build(),
            strategy: strategy,
            dailyTargets: DailyTargetsStateBuilder.build(profile: context.profile),
            status: status,
            explanation: PlanExplanationStateBuilder.build(
                profile: context.profile,
                planResult: planResult,
                referenceDate: asOf
            ),
            confidence: PlanConfidenceStateBuilder.build(
                context: context,
                planResult: planResult,
                baseline: baseline
            ),
            adjustmentRules: PlanAdjustmentRulesStateBuilder.build(
                profile: context.profile,
                planResult: planResult,
                allWeights: context.allWeights,
                referenceDate: asOf,
                calendar: context.calendar
            ),
            assumptions: PlanAssumptionsStateBuilder.build(context: context, asOf: asOf),
            review: PlanReviewStateBuilder.build(
                profile: context.profile,
                weekLogs: context.weekLogs,
                allWeights: context.allWeights,
                referenceDate: asOf,
                calendar: context.calendar
            ),
            adjustPlanCTA: PlanAdjustPlanCTAStateBuilder.build()
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
    ) -> PlanStrategyState {
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
            )
        )
    }

    static func goalDirection(for profile: UserProfile) -> PlanGoalDirection {
        switch PlanStateBuilder.goalType(for: profile) {
        case .loseFat: return .cut
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
        let trainingTargetLabel = trainingTargetLabel(
            sessionsPerWeek: profile.trainingFrequencyPerWeek
        )
        let prescriptionCopy = prescriptionCopy(for: direction)

        var state = DailyTargetsState(
            sectionTitle: FormaProductCopy.PlanDailyTargets.sectionTitle,
            caloriesLabel: caloriesLabel,
            proteinLabel: proteinLabel,
            carbsLabel: carbsLabel,
            fatLabel: fatLabel,
            waterLabel: waterLabel,
            trainingTargetLabel: trainingTargetLabel,
            prescriptionCopy: prescriptionCopy,
            goToTodayTitle: FormaProductCopy.PlanDailyTargets.goToToday,
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

    static func trainingTargetLabel(sessionsPerWeek: Int) -> String? {
        guard sessionsPerWeek > 0 else { return nil }
        return FormaProductCopy.PlanDailyTargets.trainingTarget(sessionsPerWeek: sessionsPerWeek)
    }

    static func prescriptionCopy(for direction: PlanGoalDirection) -> String {
        switch direction {
        case .cut:
            return FormaProductCopy.PlanDailyTargets.prescriptionLose
        case .gain:
            return FormaProductCopy.PlanDailyTargets.prescriptionGain
        case .maintain:
            return FormaProductCopy.PlanDailyTargets.prescriptionMaintain
        }
    }

    private static func accessibilitySummary(for state: DailyTargetsState) -> String {
        var parts = [
            state.sectionTitle,
            state.caloriesLabel,
            state.proteinLabel,
            state.carbsLabel,
            state.fatLabel,
            state.waterLabel,
            state.prescriptionCopy
        ]
        if let trainingTargetLabel = state.trainingTargetLabel {
            parts.insert(trainingTargetLabel, at: parts.count - 1)
        }
        return parts.joined(separator: ". ")
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
