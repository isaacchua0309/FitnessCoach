//
//  TodayPresentationBuilder.swift
//  Fitness Coach
//
//  Builds Today tab presentation section models from dashboard inputs.
//

import Foundation

enum TodayPresentationBuilder {

    static let endOfDayStartHour = 20
    static let calorieTargetMetRemainingRatio = TodayMissionHeroFormatter.nearTargetRemainingRatio

    // MARK: - Dashboard

    static func dashboard(from inputs: TodayMissionControlInputs) -> TodayDashboardState {
        let emptyContext = emptyContext(from: inputs)
        let macroHydration = macroHydration(from: inputs)
        let mission = mission(
            from: inputs,
            mealsEmptyKind: emptyContext.mealsEmptyKind,
            macroHydration: macroHydration
        )
        let nextBestAction = nextBestAction(from: inputs)
        let activity = activity(from: inputs)
        let meals = meals(from: inputs, emptyContext: emptyContext)
        let victory = victory(from: inputs)
        let smartCoach = smartCoach(from: inputs)
        let yesterdayReview = yesterdayReview(from: inputs)
        let endOfDay = endOfDay(from: inputs)

        return TodayDashboardState(
            date: inputs.date,
            hasDailyLog: true,
            emptyContext: emptyContext,
            goalConnection: goalConnection(from: inputs),
            mission: mission,
            nextBestAction: nextBestAction,
            quickActions: quickActions(),
            meals: meals,
            macroHydration: macroHydration,
            activity: activity,
            victory: victory,
            smartCoach: smartCoach,
            yesterdayReview: yesterdayReview,
            endOfDay: endOfDay
        )
    }

    // MARK: - Mission

    static func mission(
        from inputs: TodayMissionControlInputs,
        mealsEmptyKind: TodayMealsEmptyKind,
        macroHydration: TodayMacroHydrationState
    ) -> TodayMissionState {
        let calories = inputs.calorieSummary
        let phase = missionPhase(
            calorieSummary: calories,
            foodEntries: inputs.foodEntries,
            hasPriorFoodLogs: inputs.hasPriorFoodLogs
        )
        let status = missionStatus(
            calorieSummary: calories,
            macroHydration: macroHydration,
            foodEntries: inputs.foodEntries
        )
        let hero = TodayMissionHeroFormatter.displayModel(
            calorieSummary: calories,
            proteinProgress: macroHydration.macroSummary.protein,
            mealsEmptyKind: mealsEmptyKind
        )

        return TodayMissionState(
            phase: phase,
            status: status,
            sectionTitle: FormaProductCopy.Today.Mission.sectionTitle,
            primaryKind: hero.primaryKind,
            primaryValue: hero.primaryValue,
            goalLine: hero.goalLine,
            consumedLine: hero.consumedLine,
            proteinRemainingLine: hero.proteinRemainingLine,
            statusLine: hero.statusLine,
            showsLogMealCTA: hero.showsLogMealCTA,
            accessibilityLabel: hero.accessibilityLabel,
            calorieSummary: calories,
            weightSummary: inputs.weightSummary,
            goalProgress: goalProgress(
                latestWeightKg: inputs.latestWeightKg,
                profileWeightKg: inputs.profileWeightKg,
                goalWeightKg: inputs.goalWeightKg
            )
        )
    }

    static func missionPhase(
        calorieSummary: CalorieSummary,
        foodEntries: [FoodEntry],
        hasPriorFoodLogs: Bool
    ) -> TodayMissionPhase {
        if calorieSummary.isOverTarget {
            return .overTarget
        }
        if foodEntries.isEmpty {
            return hasPriorFoodLogs ? .noMealsLogged : .brandNewUser
        }
        if isCalorieTargetMet(calorieSummary) {
            return .targetMet
        }
        return .inProgress
    }

    static func missionStatus(
        calorieSummary: CalorieSummary,
        macroHydration: TodayMacroHydrationState,
        foodEntries: [FoodEntry]
    ) -> TodayMissionStatus {
        if calorieSummary.isOverTarget {
            return .overBudget
        }

        switch macroHydration.focus {
        case .proteinBehind, .waterBehind, .bothBehind:
            return .needsFocus
        case .onTrack:
            break
        }

        if foodEntries.isEmpty {
            return .needsFocus
        }

        return .onTrack
    }

    static func isCalorieTargetMet(_ summary: CalorieSummary) -> Bool {
        guard !summary.isOverTarget, summary.target > 0, summary.consumed > 0 else {
            return false
        }
        return TodayMissionHeroFormatter.isNearTarget(summary)
            || summary.remaining <= Int((Double(summary.target) * calorieTargetMetRemainingRatio).rounded())
    }

    static func goalProgress(
        latestWeightKg: Double?,
        profileWeightKg: Double?,
        goalWeightKg: Double?
    ) -> TodayGoalProgressState? {
        guard let currentWeightKg = TodayGoalConnectionFormatting.resolvedCurrentWeight(
            latestWeightKg: latestWeightKg,
            profileWeightKg: profileWeightKg
        ),
              let goalWeightKg,
              goalWeightKg > 0 else {
            return nil
        }

        let direction = JourneyGoalDirection.resolve(
            startWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg
        )
        let kgToGo = abs(currentWeightKg - goalWeightKg)
        guard direction != .maintain, kgToGo > TodayGoalConnectionFormatting.maintainToleranceKg else {
            return nil
        }

        return TodayGoalProgressState(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            kgToGo: kgToGo,
            direction: direction
        )
    }

    // MARK: - Next best action

    static func nextBestAction(from inputs: TodayMissionControlInputs) -> TodayNextBestActionState {
        NextBestActionEngine.resolve(
            NextBestActionInput(
                date: inputs.date,
                calendar: .current,
                foodEntries: inputs.foodEntries,
                proteinProgress: inputs.macroSummary.protein,
                waterProgress: inputs.waterSummary.progress,
                calorieSummary: inputs.calorieSummary,
                workoutSummary: inputs.workoutSummary,
                activityContext: inputs.activityContext,
                trainingFrequencyPerWeek: inputs.trainingFrequencyPerWeek
            )
        )
    }

    // MARK: - Quick actions

    static func quickActions(
        isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady
    ) -> TodayQuickActionsState {
        let configuration = TodayQuickActionPolicy.configuration(isScanFoodAvailable: isScanFoodAvailable)
        return TodayQuickActionsState(
            sectionTitle: FormaProductCopy.Today.QuickActions.sectionTitle,
            showsScanMeal: configuration.showsScanMeal
        )
    }

    // MARK: - Meals

    static func meals(
        from inputs: TodayMissionControlInputs,
        emptyContext: TodayDashboardEmptyContext
    ) -> TodayMealsState {
        let phase: TodayMealsPhase
        switch emptyContext.mealsEmptyKind {
        case .hasMeals:
            phase = .hasMeals
        case .newProfileNoMeals:
            phase = .brandNewUser
        case .newDayNoMeals:
            phase = .noMealsToday
        }

        return TodayMealsState(
            phase: phase,
            sectionTitle: FormaProductCopy.Today.Meals.sectionTitle,
            entries: inputs.foodEntries,
            entryCount: inputs.foodEntries.count
        )
    }

    // MARK: - Macro + hydration

    static func macroHydration(from inputs: TodayMissionControlInputs) -> TodayMacroHydrationState {
        let focus = macroHydrationFocus(
            protein: inputs.macroSummary.protein,
            waterProgress: inputs.waterSummary.progress
        )

        return TodayMacroHydrationState(
            focus: focus,
            sectionTitle: FormaProductCopy.Today.MacroBalance.sectionTitle,
            macroSummary: inputs.macroSummary,
            waterSummary: inputs.waterSummary
        )
    }

    static func macroHydrationFocus(
        protein: MacroProgress,
        waterProgress: Double
    ) -> TodayMacroHydrationFocus {
        let proteinLow = protein.progress < TodayFocusBuilder.proteinOnTrackThreshold
        let waterLow = waterProgress < TodayFocusBuilder.waterOnTrackThreshold

        switch (proteinLow, waterLow) {
        case (true, true):
            return .bothBehind
        case (true, false):
            return .proteinBehind
        case (false, true):
            return .waterBehind
        case (false, false):
            return .onTrack
        }
    }

    // MARK: - Activity

    static func activity(from inputs: TodayMissionControlInputs) -> TodayActivityState {
        let context = inputs.activityContext
        let showsConnectCTA = context.trainingDataSource == .appleHealth
            && context.trainingIntegration.showsConnectionGate
        let hasWorkout = inputs.workoutSummary.hasWorkout || (context.appleHealthWorkoutCount ?? 0) > 0

        let phase: TodayActivityPhase
        switch context.trainingDataSource {
        case .unavailable:
            phase = hasWorkout ? .workoutCompleted : .healthUnavailable
        case .appleHealth:
            if showsConnectCTA {
                phase = .disconnected
            } else if hasWorkout {
                phase = .workoutCompleted
            } else if context.stepsToday == nil && (context.appleHealthWorkoutCount ?? 0) == 0 {
                phase = .empty
            } else {
                phase = .hasData
            }
        }

        return TodayActivityState(
            phase: phase,
            sectionTitle: FormaProductCopy.Today.Activity.sectionTitle,
            legacyWorkoutSummary: inputs.workoutSummary,
            trainingIntegration: context.trainingIntegration,
            trainingDataSource: context.trainingDataSource,
            appleHealthWorkoutCount: context.appleHealthWorkoutCount,
            stepsToday: context.stepsToday,
            stepGoalAssumption: inputs.stepGoalAssumption,
            showsConnectCTA: showsConnectCTA,
            date: inputs.date,
            trainingFrequencyPerWeek: inputs.trainingFrequencyPerWeek
        )
    }

    // MARK: - Victory

    static func victory(from inputs: TodayMissionControlInputs) -> TodayVictoryState {
        DailyVictoryEngine.resolve(
            DailyVictoryInput(
                foodEntries: inputs.foodEntries,
                proteinProgress: inputs.macroSummary.protein,
                waterSummary: inputs.waterSummary,
                calorieSummary: inputs.calorieSummary,
                workoutSummary: inputs.workoutSummary,
                activityContext: inputs.activityContext,
                weightLoggedToday: inputs.weightLoggedToday
            )
        )
    }

    static func smartCoach(from inputs: TodayMissionControlInputs) -> TodaySmartCoachState {
        SmartCoachEngine.resolve(
            SmartCoachInput(
                date: inputs.date,
                calendar: .current,
                foodEntries: inputs.foodEntries,
                proteinProgress: inputs.macroSummary.protein,
                waterProgress: inputs.waterSummary.progress,
                calorieSummary: inputs.calorieSummary,
                workoutSummary: inputs.workoutSummary,
                activityContext: inputs.activityContext
            )
        )
    }

    // MARK: - End of day

    static func yesterdayReview(from inputs: TodayMissionControlInputs) -> TodayYesterdayReviewState {
        guard let context = inputs.yesterdayReviewInput else {
            return .hidden
        }

        let hasEnoughLogs = DailyReviewSummaryBuilder.hasEnoughLogsForReview(
            foodEntryCount: context.foodEntryCount,
            waterConsumedMl: context.waterConsumedMl,
            workoutCaloriesBurned: context.workoutCaloriesBurned,
            weightLogged: context.weightLogged
        )

        guard hasEnoughLogs else {
            return .hidden
        }

        if let review = context.review {
            let previewLines = DailyReviewSummaryBuilder.teaserLines(from: review)
            let copy = FormaProductCopy.Today.YesterdayReview.self
            return TodayYesterdayReviewState(
                isVisible: true,
                sectionTitle: copy.sectionTitle,
                previewLines: previewLines,
                actionTitle: copy.viewAction,
                actionHint: copy.viewHint,
                cta: .viewReview,
                reviewDate: context.date,
                review: review,
                accessibilityLabel: accessibilityLabel(
                    sectionTitle: copy.sectionTitle,
                    previewLines: previewLines,
                    actionTitle: copy.viewAction
                )
            )
        }

        let copy = FormaProductCopy.Today.YesterdayReview.self
        return TodayYesterdayReviewState(
            isVisible: true,
            sectionTitle: copy.sectionTitle,
            previewLines: [],
            actionTitle: copy.generateAction,
            actionHint: copy.generateHint,
            cta: .generateReview,
            reviewDate: context.date,
            review: nil,
            accessibilityLabel: accessibilityLabel(
                sectionTitle: copy.sectionTitle,
                previewLines: [],
                actionTitle: copy.generateAction
            )
        )
    }

    static func endOfDay(from inputs: TodayMissionControlInputs) -> TodayEndOfDayState {
        EndOfDayWrapUpEngine.resolve(
            EndOfDayWrapUpInput(
                date: inputs.date,
                calendar: .current,
                foodEntries: inputs.foodEntries,
                calorieSummary: inputs.calorieSummary,
                proteinProgress: inputs.macroSummary.protein,
                waterSummary: inputs.waterSummary,
                workoutSummary: inputs.workoutSummary,
                activityContext: inputs.activityContext,
                weightLoggedToday: inputs.weightLoggedToday
            )
        )
    }

    // MARK: - Shared

    static func emptyContext(from inputs: TodayMissionControlInputs) -> TodayDashboardEmptyContext {
        TodayDashboardEmptyContext(
            mealsEmptyKind: TodayEmptyStateFormatting.mealsEmptyKind(
                mealsEmpty: inputs.foodEntries.isEmpty,
                hasPriorFoodLogs: inputs.hasPriorFoodLogs
            ),
            showsWeightReminder: TodayEmptyStateFormatting.shouldShowWeightReminder(
                weightLoggedToday: inputs.weightLoggedToday,
                hasRecentWeight: inputs.hasRecentWeight
            )
        )
    }

    static func goalConnection(from inputs: TodayMissionControlInputs) -> TodayGoalConnectionState? {
        TodayGoalConnectionFormatting.displayModel(
            for: TodayGoalConnectionInput(
                latestWeightKg: inputs.latestWeightKg,
                profileWeightKg: inputs.profileWeightKg,
                goalWeightKg: inputs.goalWeightKg
            )
        )
    }

    private static func accessibilityLabel(
        sectionTitle: String,
        previewLines: [String],
        actionTitle: String
    ) -> String {
        ([sectionTitle] + previewLines + [actionTitle]).joined(separator: ". ")
    }
}
