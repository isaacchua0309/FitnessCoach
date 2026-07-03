//
//  TodayPresentationBuilder.swift
//  Fitness Coach
//
//  Builds Today tab presentation section models from dashboard inputs.
//

import Foundation

enum TodayPresentationBuilder {

    static let endOfDayStartHour = NextBestActionEngine.reviewTodayStartHour
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
        let victory = victory(from: inputs, mission: mission, macroHydration: macroHydration)
        let smartCoach = smartCoach(
            from: inputs,
            mission: mission,
            macroHydration: macroHydration,
            activity: activity,
            mealsEmptyKind: emptyContext.mealsEmptyKind
        )
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
            primaryMetricLabel: hero.primaryMetricLabel,
            primaryMetricValue: hero.primaryMetricValue,
            statusLine: hero.statusLine,
            progress: hero.progress,
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
                weightLoggedToday: inputs.weightLoggedToday,
                hasRecentWeight: inputs.hasRecentWeight,
                activityContext: inputs.activityContext,
                hasDailyReview: inputs.dailyReview != nil
            )
        )
    }

    // MARK: - Quick actions

    static func quickActions(
        isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady
    ) -> TodayQuickActionsState {
        TodayQuickActionsState(
            sectionTitle: FormaProductCopy.Today.QuickActions.sectionTitle,
            items: TodayQuickActionPolicy.menuItems(isScanFoodAvailable: isScanFoodAvailable)
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

        let emptyCopy: TodayEmptyStateCopy?
        if phase != .hasMeals {
            emptyCopy = TodayEmptyStateFormatting.mealsEmptyCopy(for: emptyContext.mealsEmptyKind)
        } else {
            emptyCopy = nil
        }

        return TodayMealsState(
            phase: phase,
            sectionTitle: FormaProductCopy.Today.Meals.sectionTitle,
            entries: inputs.foodEntries,
            entryCount: inputs.foodEntries.count,
            emptyTitle: emptyCopy?.title,
            emptyBody: emptyCopy?.body,
            emptyActionTitle: emptyCopy?.actionTitle
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
            guidanceLine: macroHydrationGuidance(for: focus),
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

    static func macroHydrationGuidance(for focus: TodayMacroHydrationFocus) -> String? {
        switch focus {
        case .onTrack:
            return nil
        case .proteinBehind:
            return FormaProductCopy.Today.SmartCoach.proteinBehind
        case .waterBehind:
            return FormaProductCopy.Today.SmartCoach.waterBehind
        case .bothBehind:
            return FormaProductCopy.Today.SmartCoach.bothBehind
        }
    }

    // MARK: - Activity

    static func activity(from inputs: TodayMissionControlInputs) -> TodayActivityState {
        let context = inputs.activityContext
        let displayLine = activityDisplayLine(
            context: context,
            legacyWorkoutSummary: inputs.workoutSummary
        )
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
            displayLine: displayLine,
            showsConnectCTA: showsConnectCTA
        )
    }

    static func activityDisplayLine(
        context: TodayActivityContext,
        legacyWorkoutSummary: TodayWorkoutSummary
    ) -> String {
        switch context.trainingDataSource {
        case .appleHealth:
            if context.trainingIntegration.showsConnectionGate {
                switch context.trainingIntegration {
                case .denied, .failed:
                    return FormaProductCopy.Today.actionManageHealthAccess
                case .notConnected, .unavailable, .requestingPermission, .connected:
                    return FormaProductCopy.Training.Integration.connectAppleHealth
                }
            }

            if let count = context.appleHealthWorkoutCount, count > 0 {
                return FormaProductCopy.Today.workoutsToday(count)
            }

            return FormaProductCopy.Today.statusNoAppleHealthWorkoutToday

        case .unavailable:
            if legacyWorkoutSummary.hasWorkout {
                return FormaProductCopy.Today.statusWorkoutRecorded
            }
            return FormaProductCopy.Today.statusNoWorkoutToday
        }
    }

    // MARK: - Victory

    static func victory(
        from inputs: TodayMissionControlInputs,
        mission: TodayMissionState,
        macroHydration: TodayMacroHydrationState
    ) -> TodayVictoryState {
        let message: String?
        if mission.phase == .targetMet {
            message = FormaProductCopy.Today.Victory.targetMet
        } else if mission.status == .onTrack,
                  !inputs.foodEntries.isEmpty,
                  macroHydration.focus == .onTrack,
                  inputs.workoutSummary.hasWorkout || (inputs.activityContext.appleHealthWorkoutCount ?? 0) > 0 {
            message = FormaProductCopy.Today.Victory.workoutStrongDay
        } else {
            message = nil
        }

        if let message {
            return TodayVictoryState(isVisible: true, message: message)
        }
        return TodayVictoryState(isVisible: false, message: "")
    }

    // MARK: - Smart coach

    static func smartCoach(
        from inputs: TodayMissionControlInputs,
        mission: TodayMissionState,
        macroHydration: TodayMacroHydrationState,
        activity: TodayActivityState,
        mealsEmptyKind: TodayMealsEmptyKind
    ) -> TodaySmartCoachState {
        if mealsEmptyKind == .newProfileNoMeals || (inputs.foodEntries.isEmpty && mission.phase == .noMealsLogged) {
            return TodaySmartCoachState(
                isVisible: true,
                context: .logFirstMeal,
                message: FormaProductCopy.Today.SmartCoach.logFirstMeal,
                coachPrefill: TodayCoachPrompt.logMeal()
            )
        }

        if mission.phase == .overTarget {
            return TodaySmartCoachState(
                isVisible: true,
                context: .overTarget,
                message: FormaProductCopy.Today.SmartCoach.overTarget,
                coachPrefill: TodayCoachPrompt.reviewToday
            )
        }

        if activity.phase == .workoutCompleted, macroHydration.focus == .proteinBehind {
            return TodaySmartCoachState(
                isVisible: true,
                context: .workoutCompleted,
                message: FormaProductCopy.Today.SmartCoach.postWorkoutProtein,
                coachPrefill: TodayCoachPrompt.logProtein
            )
        }

        switch macroHydration.focus {
        case .proteinBehind:
            return TodaySmartCoachState(
                isVisible: true,
                context: .proteinBehind,
                message: FormaProductCopy.Today.SmartCoach.proteinBehind,
                coachPrefill: TodayCoachPrompt.logProtein
            )
        case .waterBehind:
            return TodaySmartCoachState(
                isVisible: true,
                context: .waterBehind,
                message: FormaProductCopy.Today.SmartCoach.waterBehind,
                coachPrefill: TodayCoachPrompt.logWater()
            )
        case .bothBehind:
            return TodaySmartCoachState(
                isVisible: true,
                context: .proteinBehind,
                message: FormaProductCopy.Today.SmartCoach.bothBehind,
                coachPrefill: TodayCoachPrompt.logProtein
            )
        case .onTrack:
            return TodaySmartCoachState(isVisible: false, context: nil, message: "", coachPrefill: nil)
        }
    }

    // MARK: - End of day

    static func endOfDay(from inputs: TodayMissionControlInputs) -> TodayEndOfDayState {
        let hour = Calendar.current.component(.hour, from: inputs.date)
        let isEvening = hour >= endOfDayStartHour
        let hasMeals = !inputs.foodEntries.isEmpty
        let suggestsReview = isEvening && hasMeals && inputs.dailyReview == nil

        guard isEvening, hasMeals else {
            return TodayEndOfDayState(
                isVisible: false,
                message: "",
                suggestsReview: false,
                reviewCTATitle: nil
            )
        }

        return TodayEndOfDayState(
            isVisible: true,
            message: suggestsReview
                ? FormaProductCopy.Today.EndOfDay.reviewPrompt
                : FormaProductCopy.Today.EndOfDay.wrapUp,
            suggestsReview: suggestsReview,
            reviewCTATitle: suggestsReview ? FormaProductCopy.Today.EndOfDay.reviewAction : nil
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
}
