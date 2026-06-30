//
//  PlanMissionControlBuilders.swift
//  Fitness Coach
//
//  Forma — Deterministic builders for Plan Mission Control state.
//

import Foundation

enum PlanDashboardBuilder {

    private static let trainingDefaultsResolver = ActivityTrainingDefaultsResolver()

    // MARK: - Orchestrator

    static func missionControlDashboard(
        context: PlanDashboardContext,
        referenceDate: Date? = nil
    ) -> PlanMissionControlDashboard {
        let asOf = referenceDate ?? context.asOf
        let planResult = planResult(from: context.profile, referenceDate: asOf)
        let rationale = rationaleState(profile: context.profile, result: planResult, referenceDate: asOf)
        let baseline = resolveBaseline(context: context, asOf: asOf)
        let week = PlanWeekStateBuilder.build(
            context: context,
            baseline: baseline
        )

        return PlanMissionControlDashboard(
            mission: PlanMissionStateBuilder.build(
                context: context,
                baseline: baseline,
                week: week,
                planResult: planResult,
                asOf: asOf
            ),
            todayMission: PlanTodayMissionStateBuilder.build(profile: context.profile),
            week: week,
            nextMilestone: PlanNextMilestoneStateBuilder.build(
                context: context,
                baseline: baseline,
                week: week,
                asOf: asOf
            ),
            rationale: rationale,
            activityAssumptions: PlanActivityAssumptionsStateBuilder.build(context: context, asOf: asOf),
            confidence: PlanConfidenceStateBuilder.build(
                context: context,
                planResult: planResult,
                baseline: baseline
            ),
            adjustment: PlanAdjustmentStateBuilder.build(
                profile: context.profile,
                planResult: planResult,
                referenceDate: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Helpers

    private static func planResult(
        from profile: UserProfile,
        referenceDate: Date
    ) -> PlanCalculationResult? {
        try? PlanCalculationBridge.planResult(from: profile, referenceDate: referenceDate)
    }

    private static func rationaleState(
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
        week: PlanWeekState,
        planResult: PlanCalculationResult?,
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
            baseline: baseline,
            week: week,
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

// MARK: - Week

enum PlanWeekStateBuilder {

    static func build(
        context: PlanDashboardContext,
        baseline: JourneyBaseline
    ) -> PlanWeekState {
        let logs = context.weekLogs
        let profile = context.profile
        let hasData = !logs.isEmpty || !context.weekWeights.isEmpty
        let weekTotal = JourneyLogMetrics.weekDayCount

        let calorieDays = JourneyLogMetrics.calorieAdherenceDays(in: logs)
        let proteinDays = JourneyLogMetrics.proteinGoalDays(in: logs)
        let waterDays = JourneyLogMetrics.waterGoalDays(in: logs)

        let expectedTraining = max(profile.trainingFrequencyPerWeek, 0)
        let trainingDays = context.weeklyTraining.workoutDays ?? 0

        let weightDelta = JourneyLogMetrics.weightDelta(in: context.weekWeights)

        let status = overallStatus(
            hasData: hasData,
            calorieDays: calorieDays,
            proteinDays: proteinDays,
            weekTotal: weekTotal
        )

        let overallCopy = FormaProductCopy.PlanMissionControl.weekStatusCopy(
            for: status,
            hasWeeklyData: hasData
        )

        var week = PlanWeekState(
            calorieAdherence: PlanWeekAdherenceCount(
                achieved: calorieDays,
                eligible: weekTotal
            ),
            proteinAdherence: PlanWeekAdherenceCount(
                achieved: proteinDays,
                eligible: weekTotal
            ),
            waterAdherence: PlanWeekAdherenceCount(
                achieved: waterDays,
                eligible: weekTotal
            ),
            trainingDays: trainingDays,
            expectedTrainingDays: expectedTraining,
            trainingProgressLabel: trainingProgressLabel(
                achieved: trainingDays,
                expected: expectedTraining,
                training: context.weeklyTraining
            ),
            weightChangeKg: weightDelta,
            weightChangeLabel: weightDelta.map { PlanWeekPresentationBuilder.formatWeightDelta($0) },
            overallStatus: status,
            overallStatusCopy: overallCopy,
            hasWeeklyData: hasData,
            sectionTitle: FormaProductCopy.PlanMissionControl.weekSectionTitle,
            caloriesLine: "",
            proteinLine: "",
            waterLine: "",
            trainingLine: "",
            weightLine: "",
            overallHeadline: FormaProductCopy.PlanMissionControl.weekOverallHeadline,
            emptyStateCopy: hasData ? nil : FormaProductCopy.PlanMissionControl.weekEmptyState,
            showsEmptyState: !hasData,
            accessibilitySummary: ""
        )

        week = PlanWeekPresentationBuilder.applyPresentation(
            to: week,
            training: context.weeklyTraining,
            goalDirection: baseline.goalDirection
        )
        return week
    }

    private static func trainingProgressLabel(
        achieved: Int,
        expected: Int,
        training: JourneyWeeklyTrainingStatus
    ) -> String {
        switch training {
        case .hidden:
            return expected == 0
                ? "No structured training assumed"
                : "\(achieved)/\(expected) sessions planned"
        case .locked:
            return FormaProductCopy.PlanMissionControl.trainingConnectHealth
        case .connectedEmpty:
            return expected == 0
                ? "No Apple Health workouts this week"
                : "0/\(expected) planned · connect workouts in Apple Health"
        case .connected:
            return expected == 0
                ? "\(achieved) workout days logged"
                : "\(achieved)/\(expected) planned sessions"
        }
    }

    private static func overallStatus(
        hasData: Bool,
        calorieDays: Int,
        proteinDays: Int,
        weekTotal: Int
    ) -> PlanWeekOverallStatus {
        guard hasData else { return .incomplete }
        let calorieScore = Double(calorieDays) / Double(weekTotal)
        let proteinScore = Double(proteinDays) / Double(weekTotal)
        let combined = (calorieScore + proteinScore) / 2.0
        if combined >= 0.85 { return .strong }
        if combined >= 0.55 { return .onTrack }
        if combined > 0 { return .building }
        return .incomplete
    }
}

// MARK: - Next milestone

enum PlanNextMilestoneStateBuilder {

    static func build(
        context: PlanDashboardContext,
        baseline: JourneyBaseline,
        week: PlanWeekState,
        asOf: Date
    ) -> PlanNextMilestoneState {
        let candidate = PlanNextMilestoneSelector.select(
            context: context,
            baseline: baseline,
            week: week,
            asOf: asOf
        )
        return PlanNextMilestonePresentationBuilder.build(from: candidate)
    }
}

// MARK: - Activity assumptions

enum PlanActivityAssumptionsStateBuilder {

    private static let defaultsResolver = ActivityTrainingDefaultsResolver()

    static func build(context: PlanDashboardContext, asOf: Date) -> PlanActivityAssumptionsState {
        let profile = context.profile
        let defaults = defaultsResolver.defaults(for: profile.activityLevel)
        let usesDefaults = profile.trainingFrequencyPerWeek == defaults.trainingDaysPerWeek
            && profile.averageSteps == defaults.averageStepsPerDay
        let showsAppleHealth = context.dataSource == .appleHealth
        let connected = showsAppleHealth && context.integrationState.isConnected
        let stepsLabel = "\(TodayActivitySectionFormatting.formatSteps(profile.averageSteps))/day"
        let activityLevel = PlanFormatter.activityLevel(profile.activityLevel)
        let trainingLabel = trainingSessionsLabel(profile.trainingFrequencyPerWeek)
        let assumptionsNote = FormaProductCopy.PlanMissionControl.planAssumptionsNote
        let appleHealthStatus = TrainingIntegrationCopy.settingsStatusLabel(
            for: context.integrationState
        )

        var state = PlanActivityAssumptionsState(
            activityLevel: activityLevel,
            estimatedStepsPerDay: profile.averageSteps,
            estimatedStepsLabel: stepsLabel,
            trainingSessionsPerWeek: profile.trainingFrequencyPerWeek,
            trainingSessionsLabel: trainingLabel,
            usesActivityLevelDefaults: usesDefaults,
            isAppleHealthConnected: connected,
            appleHealthInsightsNote: FormaProductCopy.PlanMissionControl.appleHealthInsightsNote,
            resolvedAgeYears: profile.resolvedAge(referenceDate: asOf),
            ageLabel: PlanFormatter.age(profile.resolvedAge(referenceDate: asOf)),
            heightLabel: PlanFormatter.cm(profile.heightCm),
            sexLabel: PlanFormatter.sex(profile.sex),
            sectionTitle: FormaProductCopy.PlanMissionControl.planAssumptionsSectionTitle,
            activityFieldLabel: FormaProductCopy.PlanMissionControl.planAssumptionsActivity,
            estimatedStepsFieldLabel: FormaProductCopy.PlanMissionControl.planAssumptionsEstimatedSteps,
            trainingFieldLabel: FormaProductCopy.PlanMissionControl.planAssumptionsTraining,
            assumptionsNote: assumptionsNote,
            adjustActivityTitle: FormaProductCopy.PlanMissionControl.adjustActivity,
            showsAppleHealthStatus: showsAppleHealth,
            appleHealthFieldLabel: FormaProductCopy.PlanMissionControl.planAssumptionsAppleHealth,
            appleHealthStatusLabel: appleHealthStatus,
            showsConnectAppleHealthCTA: showsAppleHealth && !connected,
            connectAppleHealthTitle: TrainingIntegrationCopy.connectAppleHealth,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    private static func accessibilitySummary(for state: PlanActivityAssumptionsState) -> String {
        [
            state.sectionTitle,
            "\(state.activityFieldLabel), \(state.activityLevel)",
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
        parts.append(state.footerCopy)
        return parts.joined(separator: ". ")
    }
}

// MARK: - Adjustment

enum PlanAdjustmentStateBuilder {

    private static let profileEditGraceInterval: TimeInterval = 120

    static func build(
        profile: UserProfile,
        planResult: PlanCalculationResult?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> PlanAdjustmentState {
        let showsHint: Bool
        if let result = planResult {
            let stored = profile.targets.calorieTarget
            let computed = result.calorieTargetKcal
            let delta = abs(Double(stored - computed)) / Double(max(stored, 1))
            showsHint = delta > 0.05
        } else {
            showsHint = false
        }

        let relativeUpdatedLabel = PlanLastUpdatedLabelFormatter.label(
            for: profile.updatedAt,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let lastUpdateReasonCopy = resolveLastUpdateReason(profile: profile)

        let summaryRows = summaryRows(for: profile)

        var state = PlanAdjustmentState(
            canEditPlan: true,
            lastUpdated: profile.updatedAt,
            lastUpdatedLabel: FormaProductCopy.PlanMissionControl.lastUpdated(relativeUpdatedLabel),
            lastUpdateReason: lastUpdateReasonCopy,
            editSafetyCopy: FormaProductCopy.PlanMissionControl.editSafetyCopy,
            showsTargetRecalculateHint: showsHint,
            sectionTitle: FormaProductCopy.PlanMissionControl.planAdjustmentSectionTitle,
            currentHeading: FormaProductCopy.PlanMissionControl.adjustPlanCurrentHeading,
            summaryRows: summaryRows,
            lastUpdateReasonCopy: lastUpdateReasonCopy,
            lastUpdateReasonHeading: FormaProductCopy.PlanMissionControl.lastUpdateReasonHeading,
            adjustPlanTitle: FormaProductCopy.PlanMissionControl.adjustPlan,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    static func summaryRows(for profile: UserProfile) -> [PlanAdjustmentSummaryRow] {
        [
            PlanAdjustmentSummaryRow(
                id: "goal",
                label: FormaProductCopy.PlanMissionControl.adjustPlanGoalLabel,
                value: goalSummaryValue(for: profile)
            ),
            PlanAdjustmentSummaryRow(
                id: "targetWeight",
                label: FormaProductCopy.PlanMissionControl.adjustPlanTargetWeightLabel,
                value: PlanDisplayFormatter.formatKg(profile.goalWeightKg)
            ),
            PlanAdjustmentSummaryRow(
                id: "activity",
                label: FormaProductCopy.PlanMissionControl.adjustPlanActivityLabel,
                value: PlanFormatter.activityLevel(profile.activityLevel)
            ),
            PlanAdjustmentSummaryRow(
                id: "dailyTarget",
                label: FormaProductCopy.PlanMissionControl.adjustPlanDailyTargetLabel,
                value: PlanDisplayFormatter.formatKcal(profile.targets.calorieTarget)
            )
        ]
    }

    static func goalSummaryValue(for profile: UserProfile) -> String {
        switch PlanStateBuilder.goalType(for: profile) {
        case .loseFat:
            return FormaProductCopy.PlanMissionControl.adjustPlanGoalLose
        case .gainMuscle:
            return FormaProductCopy.PlanMissionControl.adjustPlanGoalGain
        case .maintain:
            return FormaProductCopy.PlanMissionControl.adjustPlanGoalMaintain
        }
    }

    static func resolveLastUpdateReason(profile: UserProfile) -> String {
        if let reason = profile.lastPlanUpdateReason {
            return FormaProductCopy.PlanMissionControl.planUpdateReason(reason)
        }

        if profile.updatedAt.timeIntervalSince(profile.createdAt) > profileEditGraceInterval {
            return FormaProductCopy.PlanMissionControl.planUpdatedAfterEdit
        }

        return FormaProductCopy.PlanMissionControl.planCreatedFromOnboarding
    }

    private static func accessibilitySummary(for state: PlanAdjustmentState) -> String {
        var parts = [
            state.sectionTitle,
            state.lastUpdatedLabel,
            "\(state.lastUpdateReasonHeading) \(state.lastUpdateReasonCopy)",
            state.currentHeading
        ]
        parts.append(contentsOf: state.summaryRows.map { "\($0.label), \($0.value)" })
        parts.append(state.editSafetyCopy)
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
