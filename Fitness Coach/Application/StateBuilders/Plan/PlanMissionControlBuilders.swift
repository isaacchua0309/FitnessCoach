//
//  PlanMissionControlBuilders.swift
//  Fitness Coach
//
//  Forma — Deterministic builders for Plan strategy state.
//

import Foundation

enum PlanDashboardBuilder {

    // MARK: - Orchestrator

    static func missionControlDashboard(
        context: PlanDashboardContext,
        referenceDate: Date? = nil
    ) -> PlanMissionControlDashboard {
        let asOf = referenceDate ?? context.asOf
        let planResult = planResult(from: context.profile, referenceDate: asOf)
        let baseline = resolveBaseline(context: context, asOf: asOf)

        return PlanMissionControlDashboard(
            mission: PlanMissionStateBuilder.build(
                context: context,
                baseline: baseline,
                asOf: asOf
            ),
            todayMission: PlanTodayMissionStateBuilder.build(profile: context.profile),
            assumptions: PlanAssumptionsStateBuilder.build(context: context, asOf: asOf),
            confidence: PlanConfidenceStateBuilder.build(
                context: context,
                planResult: planResult,
                baseline: baseline
            )
        )
    }

    // MARK: - Helpers

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

// MARK: - Mission

enum PlanMissionStateBuilder {

    static func build(
        context: PlanDashboardContext,
        baseline: JourneyBaseline,
        asOf: Date
    ) -> PlanMissionState {
        let profile = context.profile
        let direction = missionGoalDirection(for: profile)
        let strategyName = PlanStateBuilder.strategyName(for: profile)
        let currentKg = baseline.currentWeightKg ?? profile.currentWeightKg
        let goalKg = profile.goalWeightKg
        let startKg = baseline.startWeightKg ?? profile.currentWeightKg

        let totalChange = abs(goalKg - startKg)
        let totalToLoseOrGain: Double?
        if direction == .maintain {
            totalToLoseOrGain = nil
        } else {
            totalToLoseOrGain = totalChange > 0.1 ? totalChange : nil
        }

        let weeklyKg = profile.targets.expectedWeeklyWeightLossKg

        let core = PlanMissionState(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg,
            startWeightKg: baseline.startWeightKg,
            totalToLoseOrGainKg: totalToLoseOrGain,
            progressPercent: baseline.progressPercent.map { $0 / 100.0 },
            expectedCompletionDate: baseline.estimatedCompletionDate,
            expectedCompletionLabel: nil,
            expectedWeeklyChangeKg: weeklyKg,
            expectedWeeklyChangeLabel: nil,
            goalDirection: direction,
            strategyName: strategyName,
            statusCopy: "",
            usesLoggedCurrentWeight: baseline.hasRealWeightEntries,
            currentWeightLabel: PlanFormatter.kg(currentKg),
            goalWeightLabel: PlanFormatter.kg(goalKg),
            startWeightLabel: baseline.startWeightKg.map { PlanFormatter.kg($0) },
            progressPercentLabel: progressPercentLabel(baseline.progressPercent),
            totalChangeLabel: totalChangeLabel(
                startKg: startKg,
                goalKg: goalKg,
                direction: direction
            ),
            sectionTitle: "",
            headlineValue: "",
            progressRouteLabel: "",
            progressCompleteLabel: nil,
            progressBarFill: 0,
            showsProgressBar: false,
            accessibilitySummary: "",
            adjustPlanTitle: ""
        )

        return PlanMissionHeroCopyBuilder.applyHeroPresentation(
            to: core,
            profile: profile,
            baseline: baseline,
            asOf: asOf,
            calendar: context.calendar
        )
    }

    static func missionGoalDirection(for profile: UserProfile) -> PlanMissionGoalDirection {
        switch PlanStateBuilder.goalType(for: profile) {
        case .loseFat: return .lose
        case .gainMuscle: return .gain
        case .maintain: return .maintain
        }
    }

    private static func progressPercentLabel(_ percent: Double?) -> String? {
        guard let percent else { return nil }
        return "\(Int(percent.rounded()))%"
    }

    private static func totalChangeLabel(
        startKg: Double,
        goalKg: Double,
        direction: PlanMissionGoalDirection
    ) -> String? {
        let delta = abs(startKg - goalKg)
        guard delta > 0.1 else { return nil }
        switch direction {
        case .lose:
            return FormaProductCopy.PlanMissionControl.totalToLose(PlanFormatter.kg(delta))
        case .gain:
            return FormaProductCopy.PlanMissionControl.totalToGain(PlanFormatter.kg(delta))
        case .maintain:
            return nil
        }
    }
}

// MARK: - Today’s mission

enum PlanTodayMissionStateBuilder {

    static func build(profile: UserProfile) -> PlanTodayMissionState {
        let targets = profile.targets
        let direction = PlanMissionStateBuilder.missionGoalDirection(for: profile)

        let caloriesLabel = caloriesLabel(for: targets.calorieTarget)
        let proteinLabel = macroLabel(
            value: targets.proteinTarget,
            formatted: PlanFormatter.gramsCompact,
            suffix: "protein"
        )
        let carbsLabel = macroLabel(
            value: targets.carbTarget,
            formatted: PlanFormatter.gramsCompact,
            suffix: "carbs"
        )
        let fatLabel = macroLabel(
            value: targets.fatTarget,
            formatted: PlanFormatter.gramsCompact,
            suffix: "fat"
        )
        let waterLabel = waterLabel(for: targets.waterTargetMl)
        let progressCopy = progressCopy(
            weeklyKg: targets.expectedWeeklyWeightLossKg,
            direction: direction
        )

        var mission = PlanTodayMissionState(
            calorieTarget: targets.calorieTarget,
            proteinTargetG: targets.proteinTarget,
            carbTargetG: targets.carbTarget,
            fatTargetG: targets.fatTarget,
            waterTargetMl: targets.waterTargetMl,
            caloriesLabel: caloriesLabel,
            proteinLabel: proteinLabel,
            carbsLabel: carbsLabel,
            fatLabel: fatLabel,
            waterLabel: waterLabel,
            progressCopy: progressCopy,
            sectionTitle: FormaProductCopy.PlanMissionControl.todayMissionSectionTitle,
            goToTodayTitle: FormaProductCopy.PlanMissionControl.goToToday,
            accessibilitySummary: ""
        )
        mission.accessibilitySummary = accessibilitySummary(for: mission)
        return mission
    }

    static func caloriesLabel(for kcal: Int) -> String {
        guard kcal > 0 else {
            return FormaProductCopy.PlanMissionControl.targetUnavailable
        }
        return PlanFormatter.kcal(kcal)
    }

    static func macroLabel(
        value: Double,
        formatted: (Double) -> String,
        suffix: String
    ) -> String {
        guard value > 0 else {
            return FormaProductCopy.PlanMissionControl.targetUnavailable
        }
        return "\(formatted(value)) \(suffix)"
    }

    static func waterLabel(for ml: Int) -> String {
        guard ml > 0 else {
            return FormaProductCopy.PlanMissionControl.targetUnavailable
        }
        return "\(PlanFormatter.litersCompact(ml)) water"
    }

    static func progressCopy(
        weeklyKg: Double?,
        direction: PlanMissionGoalDirection
    ) -> String {
        if direction == .lose, let weeklyKg, weeklyKg > 0 {
            return FormaProductCopy.PlanMissionControl.todayMissionDesignedForProgress(
                formatWeeklyKg(weeklyKg)
            )
        }
        return FormaProductCopy.PlanMissionControl.todayMissionProgressFallback(for: direction)
    }

    static func accessibilitySummary(for mission: PlanTodayMissionState) -> String {
        [
            mission.sectionTitle,
            mission.caloriesLabel,
            mission.proteinLabel,
            mission.carbsLabel,
            mission.fatLabel,
            mission.waterLabel,
            mission.progressCopy
        ].joined(separator: ". ")
    }

    private static func formatWeeklyKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }
}

// MARK: - Plan assumptions

enum PlanAssumptionsStateBuilder {

    private static let defaultsResolver = ActivityTrainingDefaultsResolver()

    static func build(context: PlanDashboardContext, asOf: Date) -> PlanAssumptionsState {
        let profile = context.profile
        let defaults = defaultsResolver.defaults(for: profile.activityLevel)
        let usesDefaults = profile.trainingFrequencyPerWeek == defaults.trainingDaysPerWeek
            && profile.averageSteps == defaults.averageStepsPerDay
        let stepsLabel = "\(TodayActivitySectionFormatting.formatSteps(profile.averageSteps))/day"
        let activityLevel = PlanFormatter.activityLevel(profile.activityLevel)
        let trainingLabel = trainingSessionsLabel(profile.trainingFrequencyPerWeek)

        var state = PlanAssumptionsState(
            activityLevel: activityLevel,
            estimatedStepsPerDay: profile.averageSteps,
            estimatedStepsLabel: stepsLabel,
            trainingSessionsPerWeek: profile.trainingFrequencyPerWeek,
            trainingSessionsLabel: trainingLabel,
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
            case .caution:
                score += 10
                whyItems.append(
                    PlanConfidenceReasonItem(
                        id: "targets",
                        text: FormaProductCopy.PlanMissionControl.confidenceTargetsGuardrailed
                    )
                )
            case .strongWarning:
                score += 6
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
            if hasAnyWeight {
                score += 4
            }
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
            if foodDays >= partialFoodLogDays {
                score += 5
            }
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
        let level = confidenceLevel(for: clamped)
        let footerCopy = FormaProductCopy.PlanMissionControl.confidenceSafeCopy
        let appleHealthStatusLabel = showsAppleHealth
            ? TrainingIntegrationCopy.planCardStatusLabel(for: context.integrationState)
            : nil
        let showsAppleHealthAction = showsAppleHealth && !isAppleHealthConnected

        var state = PlanConfidenceState(
            confidenceScore: clamped,
            confidenceLevel: level,
            confidenceReasons: whyItems.map(\.text),
            missingSignals: missingItems.map(\.text),
            safeCopy: footerCopy,
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
        case 0:
            return min(score, 68)
        case 1:
            return min(score, 78)
        default:
            return score
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
