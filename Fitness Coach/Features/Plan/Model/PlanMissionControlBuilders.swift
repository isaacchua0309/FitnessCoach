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

        return PlanMissionControlDashboard(
            mission: PlanMissionStateBuilder.build(
                context: context,
                baseline: baseline,
                planResult: planResult
            ),
            todayMission: PlanTodayMissionStateBuilder.build(profile: context.profile),
            week: PlanWeekStateBuilder.build(context: context),
            nextMilestone: PlanNextMilestoneStateBuilder.build(
                context: context,
                baseline: baseline,
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
                planResult: planResult
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
        planResult: PlanCalculationResult?
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
        let weeklyLabel = weeklyChangeLabel(weeklyKg: weeklyKg, direction: direction)

        let completionDate = baseline.estimatedCompletionDate
        let completionLabel = completionDate.map {
            FormaProductCopy.PlanMissionControl.estimatedCompletion($0.formatted(.dateTime.month(.abbreviated).year()))
        }

        return PlanMissionState(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg,
            startWeightKg: baseline.startWeightKg,
            totalToLoseOrGainKg: totalToLoseOrGain,
            progressPercent: baseline.progressPercent.map { $0 / 100.0 },
            expectedCompletionDate: completionDate,
            expectedCompletionLabel: completionLabel,
            expectedWeeklyChangeKg: weeklyKg,
            expectedWeeklyChangeLabel: weeklyLabel,
            goalDirection: direction,
            strategyName: strategyName,
            statusCopy: PlanStateBuilder.strategySummary(for: profile),
            usesLoggedCurrentWeight: baseline.hasRealWeightEntries,
            currentWeightLabel: ProfileFormatter.kg(currentKg),
            goalWeightLabel: ProfileFormatter.kg(goalKg),
            startWeightLabel: baseline.startWeightKg.map { ProfileFormatter.kg($0) },
            progressPercentLabel: progressPercentLabel(baseline.progressPercent),
            totalChangeLabel: totalChangeLabel(
                startKg: startKg,
                goalKg: goalKg,
                direction: direction
            )
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
            return FormaProductCopy.PlanMissionControl.totalToLose(ProfileFormatter.kg(delta))
        case .gain:
            return FormaProductCopy.PlanMissionControl.totalToGain(ProfileFormatter.kg(delta))
        case .maintain:
            return nil
        }
    }

    private static func weeklyChangeLabel(
        weeklyKg: Double?,
        direction: PlanMissionGoalDirection
    ) -> String? {
        guard let weeklyKg, weeklyKg > 0, direction == .lose else { return nil }
        return FormaProductCopy.PlanMissionControl.expectedWeeklyLoss(ProfileFormatter.kg(weeklyKg))
    }
}

// MARK: - Today’s mission

enum PlanTodayMissionStateBuilder {

    static func build(profile: UserProfile) -> PlanTodayMissionState {
        let targets = profile.targets
        let direction = PlanMissionStateBuilder.missionGoalDirection(for: profile)

        return PlanTodayMissionState(
            calorieTarget: targets.calorieTarget,
            proteinTargetG: targets.proteinTarget,
            carbTargetG: targets.carbTarget,
            fatTargetG: targets.fatTarget,
            waterTargetMl: targets.waterTargetMl,
            caloriesLabel: ProfileFormatter.kcal(targets.calorieTarget),
            proteinLabel: ProfileFormatter.gramsCompact(targets.proteinTarget),
            carbsLabel: ProfileFormatter.gramsCompact(targets.carbTarget),
            fatLabel: ProfileFormatter.gramsCompact(targets.fatTarget),
            waterLabel: ProfileFormatter.mlCompact(targets.waterTargetMl),
            progressCopy: FormaProductCopy.PlanMissionControl.todayProgressCopy(for: direction)
        )
    }
}

// MARK: - Week

enum PlanWeekStateBuilder {

    static func build(context: PlanDashboardContext) -> PlanWeekState {
        let logs = context.weekLogs
        let profile = context.profile
        let hasData = !logs.isEmpty || !context.weekWeights.isEmpty

        let calorieDays = JourneyLogMetrics.calorieAdherenceDays(in: logs)
        let proteinDays = JourneyLogMetrics.proteinGoalDays(in: logs)
        let waterDays = JourneyLogMetrics.waterGoalDays(in: logs)

        let calorieEligible = logs.filter { $0.targets.calorieTarget > 0 }.count
        let proteinEligible = logs.filter { $0.targets.proteinTarget > 0 }.count
        let waterEligible = logs.filter { $0.targets.waterTargetMl > 0 }.count
        let weekTotal = JourneyLogMetrics.weekDayCount

        let expectedTraining = max(profile.trainingFrequencyPerWeek, 0)
        let trainingDays = context.weeklyTraining.workoutDays ?? 0
        let trainingLabel = trainingProgressLabel(
            achieved: trainingDays,
            expected: expectedTraining,
            training: context.weeklyTraining
        )

        let weightDelta = JourneyLogMetrics.weightDelta(in: context.weekWeights)
        let weightLabel = weightDelta.map { delta in
            let sign = delta >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.1f", delta)) kg this week"
        }

        let status = overallStatus(
            hasData: hasData,
            calorieDays: calorieDays,
            proteinDays: proteinDays,
            weekTotal: weekTotal
        )

        return PlanWeekState(
            calorieAdherence: PlanWeekAdherenceCount(
                achieved: calorieDays,
                eligible: max(calorieEligible, weekTotal)
            ),
            proteinAdherence: PlanWeekAdherenceCount(
                achieved: proteinDays,
                eligible: max(proteinEligible, weekTotal)
            ),
            waterAdherence: PlanWeekAdherenceCount(
                achieved: waterDays,
                eligible: max(waterEligible, weekTotal)
            ),
            trainingDays: trainingDays,
            expectedTrainingDays: expectedTraining,
            trainingProgressLabel: trainingLabel,
            weightChangeKg: weightDelta,
            weightChangeLabel: weightLabel,
            overallStatus: status,
            overallStatusCopy: FormaProductCopy.PlanMissionControl.weekStatusCopy(for: status),
            hasWeeklyData: hasData
        )
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
        asOf: Date
    ) -> PlanNextMilestoneState {
        guard let startWeight = baseline.startWeightKg,
              let goalWeight = baseline.goalWeightKg,
              abs(startWeight - goalWeight) > 0.1 else {
            return emptyState(focus: FormaProductCopy.WhatHappensNext.maintenanceFocus)
        }

        let items = milestoneItems(baseline: baseline)
        guard let next = ProgressFormatter.nextMilestone(from: items) else {
            return emptyState(focus: FormaProductCopy.WhatHappensNext.defaultCheckpoint)
        }

        let current = baseline.currentWeightKg ?? startWeight
        let remaining = abs(current - next.weightKg)
        let isGoal = abs(next.weightKg - goalWeight) < 0.15
        let type: PlanMilestoneType = isGoal ? .goalWeight : .weightCheckpoint

        let projection = ProgressProjectionCalculator.projection(
            weights: context.allWeights,
            goalWeightKg: next.weightKg,
            asOf: asOf
        )

        return PlanNextMilestoneState(
            milestoneLabel: ProgressFormatter.journeyKg(next.weightKg),
            remainingKg: remaining > 0.05 ? remaining : nil,
            remainingLabel: remaining > 0.05
                ? FormaProductCopy.PlanMissionControl.remainingToMilestone(ProfileFormatter.kg(remaining))
                : nil,
            expectedDate: projection.projectedGoalDate,
            expectedDateLabel: projection.projectedGoalDate.map {
                $0.formatted(.dateTime.month(.abbreviated).day().year())
            },
            milestoneType: type,
            detailCopy: isGoal
                ? FormaProductCopy.PlanMissionControl.goalMilestoneDetail
                : FormaProductCopy.PlanMissionControl.checkpointMilestoneDetail,
            showsEmptyState: false
        )
    }

    private static func emptyState(focus: String) -> PlanNextMilestoneState {
        PlanNextMilestoneState(
            milestoneLabel: nil,
            remainingKg: nil,
            remainingLabel: nil,
            expectedDate: nil,
            expectedDateLabel: nil,
            milestoneType: nil,
            detailCopy: focus,
            showsEmptyState: true
        )
    }

    private static func milestoneItems(baseline: JourneyBaseline) -> [JourneyMilestone] {
        guard let startWeight = baseline.startWeightKg,
              let goalWeight = baseline.goalWeightKg else {
            return []
        }

        let descending = baseline.goalDirection == .lose
        let span = abs(startWeight - goalWeight)
        let stepCount = 4
        let weights: [Double] = (0...stepCount).map { index in
            let fraction = Double(index) / Double(stepCount)
            let value = descending
                ? startWeight - span * fraction
                : startWeight + span * fraction
            return (value * 10).rounded() / 10
        }

        let current = baseline.currentWeightKg ?? startWeight

        return weights.enumerated().map { index, weight in
            let nextIndex = nextMilestoneIndex(
                weights: weights,
                current: current,
                descending: descending
            )

            let status: JourneyMilestoneStatus
            if index < nextIndex {
                status = .completed
            } else if index == nextIndex {
                status = .current
            } else {
                status = .upcoming
            }

            return JourneyMilestone(
                id: "milestone-\(index)",
                title: ProgressFormatter.journeyKg(weight),
                weightKg: weight,
                status: status
            )
        }
    }

    private static func nextMilestoneIndex(
        weights: [Double],
        current: Double,
        descending: Bool
    ) -> Int {
        if descending {
            if current >= weights[0] - 0.05 { return 0 }
            if let idx = weights.firstIndex(where: { $0 < current - 0.05 }) { return idx }
            return weights.count - 1
        }
        if current <= weights[0] + 0.05 { return 0 }
        if let idx = weights.firstIndex(where: { $0 > current + 0.05 }) { return idx }
        return weights.count - 1
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
        let connected = context.dataSource == .appleHealth && context.integrationState.isConnected

        return PlanActivityAssumptionsState(
            activityLevel: ProfileFormatter.activityLevel(profile.activityLevel),
            estimatedStepsPerDay: profile.averageSteps,
            estimatedStepsLabel: ProfileFormatter.steps(profile.averageSteps),
            trainingSessionsPerWeek: profile.trainingFrequencyPerWeek,
            trainingSessionsLabel: trainingSessionsLabel(profile.trainingFrequencyPerWeek),
            usesActivityLevelDefaults: usesDefaults,
            isAppleHealthConnected: connected,
            appleHealthInsightsNote: FormaProductCopy.PlanMissionControl.appleHealthInsightsNote,
            resolvedAgeYears: profile.resolvedAge(referenceDate: asOf),
            ageLabel: ProfileFormatter.age(profile.resolvedAge(referenceDate: asOf)),
            heightLabel: ProfileFormatter.cm(profile.heightCm),
            sexLabel: ProfileFormatter.sex(profile.sex)
        )
    }

    private static func trainingSessionsLabel(_ count: Int) -> String {
        count == 1 ? "1 session/week" : "\(count) sessions/week"
    }
}

// MARK: - Confidence

enum PlanConfidenceStateBuilder {

    static func build(
        context: PlanDashboardContext,
        planResult: PlanCalculationResult?,
        baseline: JourneyBaseline
    ) -> PlanConfidenceState {
        var score = 60
        var reasons: [String] = []
        var missing: [String] = []

        if let result = planResult {
            switch result.safetyLevel {
            case .ok:
                score += 20
                reasons.append(FormaProductCopy.PlanMissionControl.confidenceSafetyOk)
            case .caution:
                score += 8
                reasons.append(FormaProductCopy.PlanMissionControl.confidenceSafetyCaution)
            case .strongWarning:
                score -= 15
                reasons.append(FormaProductCopy.PlanMissionControl.confidenceSafetyWarning)
            case .error:
                score -= 25
            }
        } else {
            score -= 20
            missing.append(FormaProductCopy.PlanMissionControl.missingCalculation)
        }

        if context.profile.birthDate != nil {
            score += 5
            reasons.append(FormaProductCopy.PlanMissionControl.confidenceBirthdayAge)
        } else {
            missing.append(FormaProductCopy.PlanMissionControl.missingBirthday)
        }

        if baseline.hasRealWeightEntries {
            score += 10
            reasons.append(FormaProductCopy.PlanMissionControl.confidenceWeightTrend)
        } else {
            missing.append(FormaProductCopy.PlanMissionControl.missingWeightLogs)
        }

        if context.weekLogs.filter({ $0.totals.calories > 0 }).count >= 3 {
            score += 5
            reasons.append(FormaProductCopy.PlanMissionControl.confidenceWeeklyLogging)
        } else {
            missing.append(FormaProductCopy.PlanMissionControl.missingWeeklyLogs)
        }

        let clamped = min(100, max(0, score))
        let level = confidenceLevel(for: clamped)

        return PlanConfidenceState(
            confidenceScore: clamped,
            confidenceLevel: level,
            confidenceReasons: reasons,
            missingSignals: missing,
            safeCopy: FormaProductCopy.PlanMissionControl.confidenceSafeCopy
        )
    }

    private static func confidenceLevel(for score: Int) -> ConfidenceLevel {
        switch score {
        case 75...: return .high
        case 50..<75: return .medium
        default: return .low
        }
    }
}

// MARK: - Adjustment

enum PlanAdjustmentStateBuilder {

    static func build(
        profile: UserProfile,
        planResult: PlanCalculationResult?
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

        return PlanAdjustmentState(
            canEditPlan: true,
            lastUpdated: profile.updatedAt,
            lastUpdatedLabel: FormaProductCopy.PlanMissionControl.lastUpdated(
                profile.updatedAt.formatted(.dateTime.month(.abbreviated).day().year())
            ),
            lastUpdateReason: nil,
            editSafetyCopy: FormaProductCopy.PlanMissionControl.editSafetyCopy,
            showsTargetRecalculateHint: showsHint
        )
    }
}

// MARK: - Rationale metrics

enum PlanRationaleMetricsBuilder {

    static func build(profile: UserProfile, result: PlanCalculationResult) -> PlanRationaleMetrics {
        let deficitOrSurplus: Int?
        let deficitLabel: String?

        switch result.goalDirection {
        case .cut where result.dailyDeficitKcal > 0:
            deficitOrSurplus = result.dailyDeficitKcal
            deficitLabel = FormaProductCopy.PlanRationale.dailyDeficit
        case .gain:
            let surplus = result.calorieTargetKcal - result.tdeeKcal
            if surplus > 0 {
                deficitOrSurplus = surplus
                deficitLabel = FormaProductCopy.PlanMissionControl.dailySurplus
            } else {
                deficitOrSurplus = nil
                deficitLabel = nil
            }
        default:
            deficitOrSurplus = nil
            deficitLabel = nil
        }

        let age = profile.resolvedAge()
        let activity = ProfileFormatter.activityLevel(profile.activityLevel).lowercased()
        let explanation = """
        BMR \(PlanDisplayFormatter.formatKcalPerDay(result.bmrKcal)) · TDEE \(PlanDisplayFormatter.formatKcalPerDay(result.tdeeKcal)) · Age \(age) · \(activity) activity
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
