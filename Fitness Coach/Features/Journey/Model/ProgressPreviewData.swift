//
//  ProgressPreviewData.swift
//  Fitness Coach
//
//  Forma — Deterministic Journey preview fixtures for UI previews and tests.
//

import Foundation

enum ProgressPreviewData {

    // MARK: - Scenarios

    /// Canonical Journey personas for previews and snapshot-style testing.
    enum Scenario: String, CaseIterable, Sendable {
        case brandNewUser
        case weekOne
        case strongMomentum
        case plateau
        case nearGoal
        case gainGoal
        case maintainGoal
        case healthDisconnected
        case healthConnected
        case sparseData
    }

    /// Fixed reference instant so previews stay stable across runs.
    static let today = TrainingInsightsPreviewData.referenceNow

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// Default rich lose-goal dashboard (backward compatible).
    static let strongMomentum = dashboard(.strongMomentum)
    static let state = strongMomentum
    static let baseline = strongMomentum.baseline

    static let brandNewUser = dashboard(.brandNewUser)
    static let weekOne = dashboard(.weekOne)
    static let plateau = dashboard(.plateau)
    static let nearGoal = dashboard(.nearGoal)
    static let gainGoal = dashboard(.gainGoal)
    static let maintainGoal = dashboard(.maintainGoal)
    static let healthDisconnected = dashboard(.healthDisconnected)
    static let healthConnected = dashboard(.healthConnected)
    static let sparseData = dashboard(.sparseData)

    static func dashboard(_ scenario: Scenario) -> ProgressDashboardState {
        switch scenario {
        case .brandNewUser:
            return makeBrandNewUserDashboard()
        case .weekOne:
            return makeWeekOneDashboard()
        case .strongMomentum:
            return makeStrongMomentumDashboard()
        case .plateau:
            return makePlateauDashboard()
        case .nearGoal:
            return makeNearGoalDashboard()
        case .gainGoal:
            return makeGainGoalDashboard()
        case .maintainGoal:
            return makeMaintainGoalDashboard()
        case .healthDisconnected:
            return makeHealthDisconnectedDashboard()
        case .healthConnected:
            return makeHealthConnectedDashboard()
        case .sparseData:
            return makeSparseDataDashboard()
        }
    }

    // MARK: - Section fixtures (derived from scenarios)

    static var transformationNewUser: JourneyTransformationHeroState {
        brandNewUser.transformation
    }

    static var transformationActiveFatLoss: JourneyTransformationHeroState {
        strongMomentum.transformation
    }

    static var transformationNearGoal: JourneyTransformationHeroState {
        nearGoal.transformation
    }

    static var transformationGainGoal: JourneyTransformationHeroState {
        gainGoal.transformation
    }

    static var transformationMaintainGoal: JourneyTransformationHeroState {
        maintainGoal.transformation
    }

    static var transformationPlateau: JourneyTransformationHeroState {
        plateau.transformation
    }

    static var weeklyReviewFullWeek: JourneyWeeklyReviewState {
        strongMomentum.weeklyReview
    }

    static var weeklyReviewPartialWeek: JourneyWeeklyReviewState {
        weekOne.weeklyReview
    }

    static var weeklyReviewTrainingLocked: JourneyWeeklyReviewState {
        healthDisconnected.weeklyReview
    }

    static var milestonesNewUser: JourneyMilestonesState {
        brandNewUser.milestones
    }

    static var milestonesActive: JourneyMilestonesState {
        strongMomentum.milestones
    }

    static var milestonesNearGoal: JourneyMilestonesState {
        nearGoal.milestones
    }

    static var storyTimelineNewUser: JourneyStoryTimelineState {
        brandNewUser.storyTimeline
    }

    static var storyTimelineActive: JourneyStoryTimelineState {
        strongMomentum.storyTimeline
    }

    static var habitInsightsActive: JourneyHabitInsightsState {
        strongMomentum.habitInsights
    }

    static var habitInsightsWeekOne: JourneyHabitInsightsState {
        weekOne.habitInsights
    }

    static var progressAttributionActive: JourneyProgressAttributionState {
        strongMomentum.progressAttribution
    }

    static var progressAttributionPlateau: JourneyProgressAttributionState {
        plateau.progressAttribution
    }

    static var beforeTodayActive: JourneyBeforeTodayState {
        strongMomentum.beforeToday
    }

    static var beforeTodayWeightsOnly: JourneyBeforeTodayState {
        brandNewUser.beforeToday
    }

    static var personalRecordsActive: JourneyPersonalRecordsState {
        strongMomentum.personalRecords
    }

    static var monthlyRecapActive: JourneyMonthlyRecapState {
        strongMomentum.monthlyRecap
    }

    static var journeyLevelActive: JourneyLevelState {
        strongMomentum.journeyLevel
    }

    // MARK: - Dashboard builders

    private static func makeBrandNewUserDashboard() -> ProgressDashboardState {
        let direction: JourneyGoalDirection = .lose
        let baseline = makeBaseline(
            startWeight: 82,
            currentWeight: 82,
            goalWeight: 74,
            direction: direction,
            progressPercent: 0,
            daysOnJourney: 0,
            hasRealWeightEntries: false,
            usesSyntheticBaseline: true,
            chartPoints: syntheticChartPoints(startKg: 82)
        )

        return ProgressDashboardState(
            selectedRangeDays: 28,
            hasProfile: true,
            baseline: baseline,
            transformation: makeTransformation(
                baseline: baseline,
                loggedDays: 0,
                loggingStreak: 0,
                weightTrendDirection: .insufficientData
            ),
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 0,
                proteinGoalDays: 0,
                waterGoalDays: 0,
                trainingDays: 0,
                expectedTrainingDays: 4,
                training: .locked,
                weightDeltaThisWeekKg: nil,
                calorieAdherenceDays: 0,
                goalDirection: direction,
                loggingStreak: 0
            ),
            streaks: makeStreaks(
                currentLogging: 0,
                longestLogging: 0,
                proteinStreak: 0,
                waterStreak: 0,
                trainingWeeks: nil,
                isTodayLogged: false
            ),
            milestones: makeMilestones(
                foodLogDays: 0,
                proteinGoalDays: 0,
                startWeight: 82,
                currentWeight: 82,
                goalWeight: 74,
                direction: direction,
                progressPercent: 0,
                loggingStreak: 0,
                longestStreak: 0
            ),
            storyTimeline: makeStoryTimeline(
                foodLogDays: 0,
                startWeight: 82,
                currentWeight: 82,
                goalWeight: 74,
                direction: direction,
                progressPercent: 0,
                loggingStreak: 0,
                longestStreak: 0
            ),
            habitInsights: .locked,
            progressAttribution: .insufficientData,
            beforeToday: makeBeforeToday(
                startedWeight: 82,
                currentWeight: 82,
                goalWeight: 74,
                daysOnJourney: 0,
                showsMacros: false
            ),
            personalRecords: .locked,
            monthlyRecap: makeMonthlyRecapBuilding(loggedDays: 0),
            journeyLevel: makeJourneyLevelEmpty(),
            detailedAnalytics: makeDetailedAnalytics(
                loggedDays: 0,
                showsWeightChart: true,
                weightPoints: syntheticChartPoints(startKg: 82),
                interpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.insufficientData,
                weightLogCTA: .logWeight,
                trainingDisplay: .hidden
            )
        )
    }

    private static func makeWeekOneDashboard() -> ProgressDashboardState {
        let direction: JourneyGoalDirection = .lose
        let baseline = makeBaseline(
            startWeight: 84,
            currentWeight: 83.6,
            goalWeight: 74,
            direction: direction,
            progressPercent: 4,
            daysOnJourney: 7,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: decliningWeightPoints(startKg: 84, dropPerStep: 0.08, count: 4)
        )

        return ProgressDashboardState(
            selectedRangeDays: 28,
            hasProfile: true,
            baseline: baseline,
            transformation: makeTransformation(
                baseline: baseline,
                loggedDays: 3,
                loggingStreak: 3,
                weightTrendDirection: .decreasing
            ),
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 3,
                proteinGoalDays: 2,
                waterGoalDays: 2,
                trainingDays: 1,
                expectedTrainingDays: 4,
                training: .connected(workoutDays: 1, averageCaloriesBurned: 180, averageTrainingDurationMinutes: 30),
                weightDeltaThisWeekKg: -0.3,
                calorieAdherenceDays: 2,
                goalDirection: direction,
                loggingStreak: 3
            ),
            streaks: makeStreaks(
                currentLogging: 3,
                longestLogging: 3,
                proteinStreak: 2,
                waterStreak: 1,
                trainingWeeks: 1,
                isTodayLogged: true
            ),
            milestones: makeMilestones(
                foodLogDays: 3,
                proteinGoalDays: 2,
                startWeight: 84,
                currentWeight: 83.6,
                goalWeight: 74,
                direction: direction,
                progressPercent: 4,
                loggingStreak: 3,
                longestStreak: 3
            ),
            storyTimeline: makeStoryTimeline(
                foodLogDays: 3,
                startWeight: 84,
                currentWeight: 83.6,
                goalWeight: 74,
                direction: direction,
                progressPercent: 4,
                loggingStreak: 3,
                longestStreak: 3,
                weightEntries: [(daysAgo: 5, kg: 84.0), (daysAgo: 1, kg: 83.6)]
            ),
            habitInsights: makeHabitInsightsWeekOne(),
            progressAttribution: .insufficientData,
            beforeToday: makeBeforeToday(
                startedWeight: 84,
                currentWeight: 83.6,
                goalWeight: 74,
                daysOnJourney: 7,
                showsMacros: true
            ),
            personalRecords: makePersonalRecordsEarly(),
            monthlyRecap: makeMonthlyRecapBuilding(loggedDays: 3),
            journeyLevel: makeJourneyLevelStarter(),
            detailedAnalytics: makeDetailedAnalytics(
                loggedDays: 3,
                showsWeightChart: true,
                weightPoints: decliningWeightPoints(startKg: 84, dropPerStep: 0.08, count: 4),
                interpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.decreasing,
                weightLogCTA: nil,
                trainingDisplay: .metrics(
                    ProgressWorkoutSummary(
                        workoutCount: 1,
                        workoutDays: 1,
                        totalEstimatedCaloriesBurned: 180,
                        averageWorkoutsPerWeek: 1,
                        averageDurationMinutes: 30,
                        isFromAppleHealth: true
                    )
                )
            )
        )
    }

    private static func makeStrongMomentumDashboard() -> ProgressDashboardState {
        let direction: JourneyGoalDirection = .lose
        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 86.2,
            goalWeight: 75,
            direction: direction,
            progressPercent: 42,
            daysOnJourney: 40,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: decliningWeightPoints(startKg: 90.2, dropPerStep: 0.14, count: 10),
            estimatedMonth: "October"
        )

        return assembleRichDashboard(
            baseline: baseline,
            direction: direction,
            loggedDays: 18,
            loggingStreak: 7,
            longestStreak: 21,
            weightTrend: .decreasing,
            foodLogDays: 32,
            proteinGoalDays: 8,
            currentWeight: 86.2,
            progressPercent: 42,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 7,
                proteinGoalDays: 6,
                waterGoalDays: 5,
                trainingDays: 4,
                expectedTrainingDays: 4,
                training: .connected(
                    workoutDays: 4,
                    averageCaloriesBurned: 310,
                    averageTrainingDurationMinutes: 45
                ),
                weightDeltaThisWeekKg: -0.6,
                calorieAdherenceDays: 6,
                goalDirection: direction,
                loggingStreak: 7,
                previousWeek: JourneyWeeklyReviewPreviousWeek(
                    foodLoggedDays: 5,
                    proteinGoalDays: 4,
                    waterGoalDays: 3,
                    calorieAdherenceDays: 4,
                    trainingDays: 3,
                    weightDeltaKg: -0.3
                )
            ),
            trainingDisplay: .metrics(
                ProgressWorkoutSummary(
                    workoutCount: 9,
                    workoutDays: 6,
                    totalEstimatedCaloriesBurned: 2_850,
                    averageWorkoutsPerWeek: 2.25,
                    averageDurationMinutes: 42,
                    isFromAppleHealth: true
                )
            ),
            weightInterpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.decreasing,
            progressAttribution: makeProgressAttributionActive(),
            journeyLevel: makeJourneyLevelActive(),
            monthlyRecap: makeMonthlyRecapActive(direction: direction, loggedDays: 18),
            personalRecords: makePersonalRecordsActive(direction: direction)
        )
    }

    private static func makePlateauDashboard() -> ProgressDashboardState {
        let direction: JourneyGoalDirection = .lose
        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 86.1,
            goalWeight: 75,
            direction: direction,
            progressPercent: 41,
            daysOnJourney: 38,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: flatWeightPoints(kg: 86.1, count: 10)
        )

        return assembleRichDashboard(
            baseline: baseline,
            direction: direction,
            loggedDays: 20,
            loggingStreak: 7,
            longestStreak: 14,
            weightTrend: .stable,
            foodLogDays: 28,
            proteinGoalDays: 7,
            currentWeight: 86.1,
            progressPercent: 41,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 6,
                proteinGoalDays: 5,
                waterGoalDays: 5,
                trainingDays: 3,
                expectedTrainingDays: 4,
                training: .connected(
                    workoutDays: 3,
                    averageCaloriesBurned: 280,
                    averageTrainingDurationMinutes: 40
                ),
                weightDeltaThisWeekKg: 0.0,
                calorieAdherenceDays: 5,
                goalDirection: direction,
                loggingStreak: 7,
                previousWeek: JourneyWeeklyReviewPreviousWeek(
                    foodLoggedDays: 6,
                    proteinGoalDays: 5,
                    waterGoalDays: 4,
                    calorieAdherenceDays: 5,
                    trainingDays: 3,
                    weightDeltaKg: 0.1
                )
            ),
            trainingDisplay: .metrics(
                ProgressWorkoutSummary(
                    workoutCount: 6,
                    workoutDays: 4,
                    totalEstimatedCaloriesBurned: 1_680,
                    averageWorkoutsPerWeek: 1.5,
                    averageDurationMinutes: 38,
                    isFromAppleHealth: true
                )
            ),
            weightInterpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.stable,
            progressAttribution: makeProgressAttributionPlateau(),
            journeyLevel: makeJourneyLevelMid(),
            monthlyRecap: makeMonthlyRecapActive(direction: direction, loggedDays: 16, weightDelta: -0.2),
            personalRecords: makePersonalRecordsActive(direction: direction)
        )
    }

    private static func makeNearGoalDashboard() -> ProgressDashboardState {
        let direction: JourneyGoalDirection = .lose
        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 76.5,
            goalWeight: 75,
            direction: direction,
            progressPercent: 90,
            daysOnJourney: 60,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: decliningWeightPoints(startKg: 90, dropPerStep: 0.22, count: 12),
            estimatedMonth: "July"
        )

        return assembleRichDashboard(
            baseline: baseline,
            direction: direction,
            loggedDays: 42,
            loggingStreak: 12,
            longestStreak: 21,
            weightTrend: .decreasing,
            foodLogDays: 105,
            proteinGoalDays: 40,
            currentWeight: 76.5,
            progressPercent: 93,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 7,
                proteinGoalDays: 7,
                waterGoalDays: 6,
                trainingDays: 4,
                expectedTrainingDays: 4,
                training: .connected(
                    workoutDays: 4,
                    averageCaloriesBurned: 320,
                    averageTrainingDurationMinutes: 48
                ),
                weightDeltaThisWeekKg: -0.4,
                calorieAdherenceDays: 7,
                goalDirection: direction,
                loggingStreak: 12
            ),
            trainingDisplay: .metrics(
                ProgressWorkoutSummary(
                    workoutCount: 11,
                    workoutDays: 7,
                    totalEstimatedCaloriesBurned: 3_520,
                    averageWorkoutsPerWeek: 2.75,
                    averageDurationMinutes: 44,
                    isFromAppleHealth: true
                )
            ),
            weightInterpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.decreasing,
            progressAttribution: makeProgressAttributionActive(),
            journeyLevel: makeJourneyLevelHigh(),
            monthlyRecap: makeMonthlyRecapActive(direction: direction, loggedDays: 22, weightDelta: -1.1),
            personalRecords: makePersonalRecordsActive(direction: direction)
        )
    }

    private static func makeGainGoalDashboard() -> ProgressDashboardState {
        let direction: JourneyGoalDirection = .gain
        let baseline = makeBaseline(
            startWeight: 62,
            currentWeight: 65.8,
            goalWeight: 70,
            direction: direction,
            progressPercent: 48,
            daysOnJourney: 30,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: risingWeightPoints(startKg: 62, risePerStep: 0.12, count: 10),
            estimatedMonth: "August"
        )

        return assembleRichDashboard(
            baseline: baseline,
            direction: direction,
            loggedDays: 20,
            loggingStreak: 5,
            longestStreak: 10,
            weightTrend: .increasing,
            foodLogDays: 24,
            proteinGoalDays: 6,
            currentWeight: 65.8,
            progressPercent: 48,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 6,
                proteinGoalDays: 5,
                waterGoalDays: 4,
                trainingDays: 3,
                expectedTrainingDays: 4,
                training: .connected(
                    workoutDays: 3,
                    averageCaloriesBurned: 350,
                    averageTrainingDurationMinutes: 50
                ),
                weightDeltaThisWeekKg: 0.5,
                calorieAdherenceDays: 5,
                goalDirection: direction,
                loggingStreak: 5
            ),
            trainingDisplay: .metrics(
                ProgressWorkoutSummary(
                    workoutCount: 7,
                    workoutDays: 5,
                    totalEstimatedCaloriesBurned: 2_450,
                    averageWorkoutsPerWeek: 1.75,
                    averageDurationMinutes: 48,
                    isFromAppleHealth: true
                )
            ),
            weightInterpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.increasing,
            progressAttribution: JourneyProgressAttributionState(
                primaryReasonTitle: FormaProductCopy.Journey.WhyProgress.proteinAnchorTitle,
                primaryReasonDetail: FormaProductCopy.Journey.WhyProgress.weightTrendTowardGoal(direction: .gain),
                supportingReasons: [
                    FormaProductCopy.Journey.WhyProgress.loggedFoodDaysThisWeek(6)
                ],
                confidence: .medium
            ),
            journeyLevel: makeJourneyLevelMid(),
            monthlyRecap: makeMonthlyRecapActive(direction: direction, loggedDays: 14, weightDelta: 1.2),
            personalRecords: makePersonalRecordsActive(direction: direction)
        )
    }

    private static func makeMaintainGoalDashboard() -> ProgressDashboardState {
        let direction: JourneyGoalDirection = .maintain
        let baseline = makeBaseline(
            startWeight: 72,
            currentWeight: 72.4,
            goalWeight: 72,
            direction: direction,
            progressPercent: nil,
            daysOnJourney: 45,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: flatWeightPoints(kg: 72.2, count: 10)
        )

        return assembleRichDashboard(
            baseline: baseline,
            direction: direction,
            loggedDays: 25,
            loggingStreak: 4,
            longestStreak: 12,
            weightTrend: .stable,
            foodLogDays: 30,
            proteinGoalDays: 6,
            currentWeight: 72.4,
            progressPercent: 0,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 6,
                proteinGoalDays: 5,
                waterGoalDays: 5,
                trainingDays: 3,
                expectedTrainingDays: 3,
                training: .connected(
                    workoutDays: 3,
                    averageCaloriesBurned: 260,
                    averageTrainingDurationMinutes: 35
                ),
                weightDeltaThisWeekKg: 0.1,
                calorieAdherenceDays: 5,
                goalDirection: direction,
                loggingStreak: 4
            ),
            trainingDisplay: .metrics(
                ProgressWorkoutSummary(
                    workoutCount: 5,
                    workoutDays: 3,
                    totalEstimatedCaloriesBurned: 1_300,
                    averageWorkoutsPerWeek: 1.25,
                    averageDurationMinutes: 35,
                    isFromAppleHealth: true
                )
            ),
            weightInterpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.stable,
            progressAttribution: JourneyProgressAttributionState(
                primaryReasonTitle: FormaProductCopy.Journey.WhyProgress.loggingControlTitle,
                primaryReasonDetail: FormaProductCopy.Journey.WhyProgress.weightTrendTowardGoal(direction: .maintain),
                supportingReasons: [
                    FormaProductCopy.Journey.WhyProgress.improvedWaterConsistency(percent: 8)
                ],
                confidence: .medium
            ),
            journeyLevel: makeJourneyLevelMid(),
            monthlyRecap: makeMonthlyRecapActive(direction: direction, loggedDays: 15, weightDelta: 0.2),
            personalRecords: makePersonalRecordsActive(direction: direction)
        )
    }

    private static func makeHealthDisconnectedDashboard() -> ProgressDashboardState {
        var dashboard = makeStrongMomentumDashboard()
        dashboard.weeklyReview = makeWeeklyReview(
            foodLoggedDays: 5,
            proteinGoalDays: 4,
            waterGoalDays: 3,
            trainingDays: 0,
            expectedTrainingDays: 4,
            training: .locked,
            weightDeltaThisWeekKg: -0.2,
            calorieAdherenceDays: 4,
            goalDirection: .lose,
            loggingStreak: 5
        )
        dashboard.detailedAnalytics.trainingDisplay = .hidden
        return dashboard
    }

    private static func makeHealthConnectedDashboard() -> ProgressDashboardState {
        makeStrongMomentumDashboard()
    }

    private static func makeSparseDataDashboard() -> ProgressDashboardState {
        let direction: JourneyGoalDirection = .lose
        let baseline = makeBaseline(
            startWeight: 88,
            currentWeight: 87.8,
            goalWeight: 75,
            direction: direction,
            progressPercent: 2,
            daysOnJourney: 5,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: decliningWeightPoints(startKg: 88, dropPerStep: 0.05, count: 2)
        )

        return ProgressDashboardState(
            selectedRangeDays: 28,
            hasProfile: true,
            baseline: baseline,
            transformation: makeTransformation(
                baseline: baseline,
                loggedDays: 2,
                loggingStreak: 0,
                weightTrendDirection: .insufficientData
            ),
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 2,
                proteinGoalDays: 1,
                waterGoalDays: 1,
                trainingDays: 0,
                expectedTrainingDays: 4,
                training: .locked,
                weightDeltaThisWeekKg: nil,
                calorieAdherenceDays: 1,
                goalDirection: direction,
                loggingStreak: 0
            ),
            streaks: makeStreaks(
                currentLogging: 0,
                longestLogging: 2,
                proteinStreak: 1,
                waterStreak: 0,
                trainingWeeks: nil,
                isTodayLogged: false
            ),
            milestones: makeMilestones(
                foodLogDays: 2,
                proteinGoalDays: 1,
                startWeight: 88,
                currentWeight: 87.8,
                goalWeight: 75,
                direction: direction,
                progressPercent: 2,
                loggingStreak: 0,
                longestStreak: 2
            ),
            storyTimeline: makeStoryTimeline(
                foodLogDays: 2,
                startWeight: 88,
                currentWeight: 87.8,
                goalWeight: 75,
                direction: direction,
                progressPercent: 2,
                loggingStreak: 0,
                longestStreak: 2,
                weightEntries: [(daysAgo: 3, kg: 88.0)]
            ),
            habitInsights: .locked,
            progressAttribution: .insufficientData,
            beforeToday: makeBeforeToday(
                startedWeight: 88,
                currentWeight: 87.8,
                goalWeight: 75,
                daysOnJourney: 5,
                showsMacros: false
            ),
            personalRecords: .locked,
            monthlyRecap: makeMonthlyRecapBuilding(loggedDays: 2),
            journeyLevel: makeJourneyLevelEmpty(),
            detailedAnalytics: makeDetailedAnalytics(
                loggedDays: 2,
                showsWeightChart: false,
                weightPoints: decliningWeightPoints(startKg: 88, dropPerStep: 0.05, count: 2),
                interpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.insufficientData,
                weightLogCTA: .logWeight,
                trainingDisplay: .hidden
            )
        )
    }

    // MARK: - Shared assembly

    private static func assembleRichDashboard(
        baseline: JourneyBaseline,
        direction: JourneyGoalDirection,
        loggedDays: Int,
        loggingStreak: Int,
        longestStreak: Int,
        weightTrend: WeightTrendDirection,
        foodLogDays: Int,
        proteinGoalDays: Int,
        currentWeight: Double,
        progressPercent: Double,
        weeklyReview: JourneyWeeklyReviewState,
        trainingDisplay: JourneyDetailedAnalyticsTrainingDisplay,
        weightInterpretation: String,
        progressAttribution: JourneyProgressAttributionState,
        journeyLevel: JourneyLevelState,
        monthlyRecap: JourneyMonthlyRecapState,
        personalRecords: JourneyPersonalRecordsState
    ) -> ProgressDashboardState {
        ProgressDashboardState(
            selectedRangeDays: 28,
            hasProfile: true,
            baseline: baseline,
            transformation: makeTransformation(
                baseline: baseline,
                loggedDays: loggedDays,
                loggingStreak: loggingStreak,
                weightTrendDirection: weightTrend
            ),
            weeklyReview: weeklyReview,
            streaks: makeStreaks(
                currentLogging: loggingStreak,
                longestLogging: longestStreak,
                proteinStreak: min(proteinGoalDays, 5),
                waterStreak: 4,
                trainingWeeks: loggingStreak > 0 ? 3 : nil,
                isTodayLogged: loggingStreak > 0
            ),
            milestones: makeMilestones(
                foodLogDays: foodLogDays,
                proteinGoalDays: proteinGoalDays,
                startWeight: baseline.startWeightKg ?? currentWeight,
                currentWeight: currentWeight,
                goalWeight: baseline.goalWeightKg ?? currentWeight,
                direction: direction,
                progressPercent: progressPercent,
                loggingStreak: loggingStreak,
                longestStreak: longestStreak
            ),
            storyTimeline: makeStoryTimeline(
                foodLogDays: foodLogDays,
                startWeight: baseline.startWeightKg ?? currentWeight,
                currentWeight: currentWeight,
                goalWeight: baseline.goalWeightKg ?? currentWeight,
                direction: direction,
                progressPercent: progressPercent,
                loggingStreak: loggingStreak,
                longestStreak: longestStreak,
                weightEntries: weightEntriesFromChart(baseline.chartPoints)
            ),
            habitInsights: makeHabitInsightsActive(),
            progressAttribution: progressAttribution,
            beforeToday: makeBeforeToday(
                startedWeight: baseline.startWeightKg,
                currentWeight: currentWeight,
                goalWeight: baseline.goalWeightKg,
                daysOnJourney: loggedDays,
                showsMacros: true
            ),
            personalRecords: personalRecords,
            monthlyRecap: monthlyRecap,
            journeyLevel: journeyLevel,
            detailedAnalytics: makeDetailedAnalytics(
                loggedDays: loggedDays,
                showsWeightChart: baseline.showsWeightChart,
                weightPoints: baseline.chartPoints,
                interpretation: weightInterpretation,
                weightLogCTA: nil,
                trainingDisplay: trainingDisplay
            )
        )
    }

    // MARK: - Component factories

    private static var previewTargets: UserTargets {
        UserTargets(
            calorieTarget: 1_800,
            proteinTarget: 130,
            carbTarget: 170,
            fatTarget: 55,
            waterTargetMl: 2_400,
            expectedWeeklyWeightLossKg: 0.34,
            aggressiveness: .moderate
        )
    }

    private static var previewProfile: UserProfile {
        UserProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Alex",
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 86.2,
            goalWeightKg: 75,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7_000,
            unitSystem: .metric,
            targets: previewTargets,
            createdAt: calendar.date(byAdding: .day, value: -40, to: today) ?? today,
            updatedAt: today
        )
    }

    private static func makeBaseline(
        startWeight: Double,
        currentWeight: Double,
        goalWeight: Double,
        direction: JourneyGoalDirection,
        progressPercent: Double?,
        daysOnJourney: Int,
        hasRealWeightEntries: Bool,
        usesSyntheticBaseline: Bool,
        chartPoints: [WeightChartPoint],
        estimatedMonth: String? = nil
    ) -> JourneyBaseline {
        let traveled: Double
        switch direction {
        case .lose:
            traveled = max(0, startWeight - currentWeight)
        case .gain:
            traveled = max(0, currentWeight - startWeight)
        case .maintain:
            traveled = abs(currentWeight - startWeight)
        }

        return JourneyBaseline(
            startWeightKg: startWeight,
            startDate: calendar.date(byAdding: .day, value: -max(daysOnJourney, 1), to: today) ?? today,
            currentWeightKg: currentWeight,
            goalWeightKg: goalWeight,
            goalDirection: direction,
            totalChangeKg: direction == .maintain ? traveled : currentWeight - startWeight,
            remainingChangeKg: abs(currentWeight - goalWeight),
            progressPercent: progressPercent,
            estimatedCompletionDate: estimatedMonth.map { _ in
                calendar.date(byAdding: .month, value: 3, to: today) ?? today
            },
            estimatedCompletionMonthLabel: estimatedMonth,
            hasRealWeightEntries: hasRealWeightEntries,
            usesSyntheticBaselinePoint: usesSyntheticBaseline,
            onboardingBaselineWeightKg: startWeight,
            chartPoints: chartPoints,
            showsWeightChart: true
        )
    }

    private static func makeBeforeToday(
        startedWeight: Double?,
        currentWeight: Double?,
        goalWeight: Double?,
        daysOnJourney: Int,
        showsMacros: Bool
    ) -> JourneyBeforeTodayState {
        let startedWeightCopy = ProgressFormatter.journeyKg(startedWeight)
        let currentWeightCopy = ProgressFormatter.journeyKg(currentWeight)
        let goalWeightCopy = ProgressFormatter.journeyKg(goalWeight)
        let startingMaintenance = showsMacros ? 3_100 : nil
        let currentMaintenance = showsMacros ? 2_950 : nil
        let startingTarget = showsMacros ? 1_600 : nil
        let currentTarget = showsMacros ? 2_100 : nil
        let startingMaintenanceCopy = startingMaintenance.map {
            PlanDisplayFormatter.formatGroupedInteger($0)
        }
        let currentMaintenanceCopy = currentMaintenance.map {
            PlanDisplayFormatter.formatGroupedInteger($0)
        }
        let startingTargetCopy = startingTarget.map {
            PlanDisplayFormatter.formatGroupedInteger($0)
        }
        let currentTargetCopy = currentTarget.map {
            PlanDisplayFormatter.formatGroupedInteger($0)
        }

        return JourneyBeforeTodayState(
            startedWeightKg: startedWeight,
            currentWeightKg: currentWeight,
            startingMaintenanceCaloriesKcal: startingMaintenance,
            currentMaintenanceCaloriesKcal: currentMaintenance,
            startingTargetCaloriesKcal: startingTarget,
            currentTargetCaloriesKcal: currentTarget,
            goalWeightKg: goalWeight,
            daysOnJourney: daysOnJourney,
            showsMaintenanceRow: showsMacros,
            showsTargetRow: showsMacros,
            showsAdaptedTargetCopy: showsMacros,
            startedWeightCopy: startedWeightCopy,
            currentWeightCopy: currentWeightCopy,
            goalWeightCopy: goalWeightCopy,
            startingMaintenanceCopy: startingMaintenanceCopy,
            currentMaintenanceCopy: currentMaintenanceCopy,
            startingTargetCopy: startingTargetCopy,
            currentTargetCopy: currentTargetCopy,
            accessibilitySummary: "\(startedWeightCopy) to \(currentWeightCopy), goal \(goalWeightCopy)"
        )
    }

    private static func makeProgressAttributionActive() -> JourneyProgressAttributionState {
        JourneyProgressAttributionState(
            primaryReasonTitle: FormaProductCopy.Journey.WhyProgress.calorieLikelyHelpedTitle,
            primaryReasonDetail: FormaProductCopy.Journey.WhyProgress.stayedWithinCalories(
                achieved: 19,
                eligible: 23
            ),
            supportingReasons: [
                FormaProductCopy.Journey.WhyProgress.increasedProteinConsistency(percent: 42),
                FormaProductCopy.Journey.WhyProgress.loggedFoodDaysThisWeek(7)
            ],
            confidence: .high
        )
    }

    private static func makeProgressAttributionPlateau() -> JourneyProgressAttributionState {
        JourneyProgressAttributionState(
            primaryReasonTitle: FormaProductCopy.Journey.WhyProgress.habitsBeforeScaleTitle,
            primaryReasonDetail: FormaProductCopy.Journey.WhyProgress.loggedFoodDaysThisWeek(6),
            supportingReasons: [
                FormaProductCopy.Journey.WhyProgress.improvedWaterConsistency(percent: 12)
            ],
            confidence: .medium
        )
    }

    private static func makeHabitInsightsWeekOne() -> JourneyHabitInsightsState {
        JourneyHabitInsightsState(
            isUnlocked: true,
            lockedMessage: nil,
            strongestHabitLabel: FormaProductCopy.Journey.HabitInsights.foodLoggingLabel,
            strongestScorePercent: 68,
            strongestQualitative: FormaProductCopy.Journey.HabitInsights.strongestQualitative(percent: 68),
            weakestHabitLabel: FormaProductCopy.Journey.HabitInsights.waterLabel,
            weakestHabitKind: .water,
            weakestScorePercent: 33,
            weakestScorePrefix: nil,
            suggestedNextAction: FormaProductCopy.Journey.HabitInsights.suggestWaterCheckIn,
            suggestionCTA: .logWater
        )
    }

    private static func makeHabitInsightsActive() -> JourneyHabitInsightsState {
        JourneyHabitInsightsState(
            isUnlocked: true,
            lockedMessage: nil,
            strongestHabitLabel: FormaProductCopy.Journey.HabitInsights.proteinLabel,
            strongestScorePercent: 91,
            strongestQualitative: FormaProductCopy.Journey.HabitInsights.strongestQualitative(percent: 91),
            weakestHabitLabel: FormaProductCopy.Journey.HabitInsights.weekendLabel,
            weakestHabitKind: .weekendLogging,
            weakestScorePercent: 42,
            weakestScorePrefix: nil,
            suggestedNextAction: FormaProductCopy.Journey.HabitInsights.suggestWeekendLogging,
            suggestionCTA: .logFood
        )
    }

    private static func makePersonalRecordsActive(
        direction: JourneyGoalDirection
    ) -> JourneyPersonalRecordsState {
        let weightTitle = direction == .gain
            ? FormaProductCopy.Journey.PersonalRecords.largestWeeklyGainTitle
            : FormaProductCopy.Journey.PersonalRecords.largestWeeklyLossTitle

        return JourneyPersonalRecordsState(
            isUnlocked: true,
            lockedMessage: nil,
            records: [
                JourneyPersonalRecord(
                    id: "logging-streak",
                    title: FormaProductCopy.Journey.PersonalRecords.longestStreakTitle,
                    value: "21 days",
                    subtitle: nil,
                    periodLabel: "Jun 6",
                    isActive: true,
                    isEarlyRecord: false
                ),
                JourneyPersonalRecord(
                    id: "protein-week",
                    title: FormaProductCopy.Journey.PersonalRecords.highestProteinWeekTitle,
                    value: "142g/day",
                    subtitle: FormaProductCopy.Journey.PersonalRecords.averageOverDays(7),
                    periodLabel: "Jun 1–7",
                    isActive: true,
                    isEarlyRecord: false
                ),
                JourneyPersonalRecord(
                    id: "weight-week",
                    title: weightTitle,
                    value: direction == .gain ? "0.9 kg" : "1.3 kg",
                    subtitle: nil,
                    periodLabel: "May 25–31",
                    isActive: true,
                    isEarlyRecord: false
                ),
                JourneyPersonalRecord(
                    id: "water-week",
                    title: FormaProductCopy.Journey.PersonalRecords.bestWaterWeekTitle,
                    value: "6/7 days",
                    subtitle: nil,
                    periodLabel: "Jun 8–14",
                    isActive: true,
                    isEarlyRecord: false
                )
            ]
        )
    }

    private static func makePersonalRecordsEarly() -> JourneyPersonalRecordsState {
        JourneyPersonalRecordsState(
            isUnlocked: true,
            lockedMessage: nil,
            records: [
                JourneyPersonalRecord(
                    id: "logging-streak",
                    title: FormaProductCopy.Journey.PersonalRecords.longestStreakTitle,
                    value: "3 days",
                    subtitle: FormaProductCopy.Journey.PersonalRecords.earlyRecord,
                    periodLabel: nil,
                    isActive: true,
                    isEarlyRecord: true
                )
            ]
        )
    }

    private static func makeMonthlyRecapBuilding(loggedDays: Int) -> JourneyMonthlyRecapState {
        let monthName = today.formatted(.dateTime.month(.wide))
        return JourneyMonthlyRecapState(
            sectionTitle: FormaProductCopy.Journey.MonthlyRecap.sectionTitle(monthName: monthName),
            isComplete: false,
            buildingMessage: FormaProductCopy.Journey.MonthlyRecap.buildingBody,
            monthWeightDeltaKg: nil,
            calorieAdherencePercent: nil,
            proteinAdherencePercent: nil,
            waterAdherencePercent: nil,
            trainingSessions: nil,
            showsTrainingRow: false,
            loggedDays: loggedDays,
            bestHabitCopy: nil,
            summaryCopy: loggedDays > 0
                ? FormaProductCopy.Journey.MonthlyRecap.loggedDaysSummary(loggedDays)
                : "",
            rows: []
        )
    }

    private static func makeMonthlyRecapActive(
        direction: JourneyGoalDirection,
        loggedDays: Int,
        weightDelta: Double? = -2.4
    ) -> JourneyMonthlyRecapState {
        let monthName = today.formatted(.dateTime.month(.wide))
        let deltaLabel = weightDelta.map {
            FormaProductCopy.Journey.MonthlyRecap.weightDelta(deltaKg: $0, direction: direction)
        } ?? "—"

        return JourneyMonthlyRecapState(
            sectionTitle: FormaProductCopy.Journey.MonthlyRecap.sectionTitle(monthName: monthName),
            isComplete: true,
            buildingMessage: nil,
            monthWeightDeltaKg: weightDelta,
            calorieAdherencePercent: 0.91,
            proteinAdherencePercent: 0.87,
            waterAdherencePercent: 0.72,
            trainingSessions: 13,
            showsTrainingRow: true,
            loggedDays: loggedDays,
            bestHabitCopy: FormaProductCopy.Journey.MonthlyRecap.bestHabit(for: .protein),
            summaryCopy: FormaProductCopy.Journey.MonthlyRecap.loggedDaysSummary(loggedDays),
            rows: [
                JourneyMonthlyRecapMetricRow(
                    id: "weight",
                    title: FormaProductCopy.Journey.MonthlyRecap.weightTitle,
                    value: deltaLabel
                ),
                JourneyMonthlyRecapMetricRow(
                    id: "calories",
                    title: FormaProductCopy.Journey.MonthlyRecap.caloriesTitle,
                    value: FormaProductCopy.Journey.MonthlyRecap.calorieAdherence(percent: 91)
                ),
                JourneyMonthlyRecapMetricRow(
                    id: "protein",
                    title: FormaProductCopy.Journey.MonthlyRecap.proteinTitle,
                    value: FormaProductCopy.Journey.MonthlyRecap.adherencePercent(87)
                ),
                JourneyMonthlyRecapMetricRow(
                    id: "water",
                    title: FormaProductCopy.Journey.MonthlyRecap.waterTitle,
                    value: FormaProductCopy.Journey.MonthlyRecap.adherencePercent(72)
                ),
                JourneyMonthlyRecapMetricRow(
                    id: "training",
                    title: FormaProductCopy.Journey.MonthlyRecap.trainingTitle,
                    value: FormaProductCopy.Journey.MonthlyRecap.trainingSessions(13)
                )
            ]
        )
    }

    private static func makeJourneyLevelEmpty() -> JourneyLevelState {
        JourneyLevelState(
            currentLevel: 1,
            levelTitle: FormaProductCopy.Journey.Level.title(for: 1),
            currentXP: 0,
            xpRequiredForNextLevel: 100,
            totalXP: 0,
            progressPercent: 0,
            xpEarnedExplanation: FormaProductCopy.Journey.Level.emptyBody,
            hasData: false
        )
    }

    private static func makeJourneyLevelStarter() -> JourneyLevelState {
        JourneyLevelState(
            currentLevel: 2,
            levelTitle: FormaProductCopy.Journey.Level.title(for: 2),
            currentXP: 35,
            xpRequiredForNextLevel: 150,
            totalXP: 135,
            progressPercent: 35.0 / 150.0 * 100,
            xpEarnedExplanation: FormaProductCopy.Journey.Level.earnExplanation,
            hasData: true
        )
    }

    private static func makeJourneyLevelMid() -> JourneyLevelState {
        JourneyLevelState(
            currentLevel: 5,
            levelTitle: FormaProductCopy.Journey.Level.title(for: 5),
            currentXP: 180,
            xpRequiredForNextLevel: 350,
            totalXP: 880,
            progressPercent: 180.0 / 350.0 * 100,
            xpEarnedExplanation: FormaProductCopy.Journey.Level.earnExplanation,
            hasData: true
        )
    }

    private static func makeJourneyLevelActive() -> JourneyLevelState {
        JourneyLevelState(
            currentLevel: 7,
            levelTitle: FormaProductCopy.Journey.Level.title(for: 7),
            currentXP: 350,
            xpRequiredForNextLevel: 450,
            totalXP: 2_000,
            progressPercent: 350.0 / 450.0 * 100,
            xpEarnedExplanation: FormaProductCopy.Journey.Level.earnExplanation,
            hasData: true
        )
    }

    private static func makeJourneyLevelHigh() -> JourneyLevelState {
        JourneyLevelState(
            currentLevel: 9,
            levelTitle: FormaProductCopy.Journey.Level.title(for: 9),
            currentXP: 420,
            xpRequiredForNextLevel: 500,
            totalXP: 3_400,
            progressPercent: 420.0 / 500.0 * 100,
            xpEarnedExplanation: FormaProductCopy.Journey.Level.earnExplanation,
            hasData: true
        )
    }

    private static func makeDetailedAnalytics(
        loggedDays: Int,
        showsWeightChart: Bool,
        weightPoints: [WeightChartPoint],
        interpretation: String,
        weightLogCTA: JourneyCTA?,
        trainingDisplay: JourneyDetailedAnalyticsTrainingDisplay
    ) -> JourneyDetailedAnalyticsState {
        JourneyDetailedAnalyticsState(
            isCollapsedByDefault: true,
            nutritionSummary: ProgressNutritionSummary(
                loggedDays: loggedDays,
                averageCalories: loggedDays > 0 ? 1_735 : 0,
                averageProtein: loggedDays > 0 ? 128 : 0,
                averageCarbs: loggedDays > 0 ? 148 : 0,
                averageFat: loggedDays > 0 ? 58 : 0,
                averageFiber: loggedDays > 2 ? 22 : nil
            ),
            waterSummary: ProgressWaterSummary(
                loggedDays: loggedDays,
                averageWaterMl: loggedDays > 0 ? 2_400 : 0,
                averageWaterTargetMl: 2_400,
                consistencyPercent: loggedDays > 0 ? 0.72 : 0
            ),
            trainingDisplay: trainingDisplay,
            weightChartPoints: weightPoints,
            weightTrendInterpretation: interpretation,
            showsWeightChart: showsWeightChart,
            weightLogCTA: weightLogCTA
        )
    }

    // MARK: - Builder delegates

    private static func makeMilestones(
        foodLogDays: Int,
        proteinGoalDays: Int,
        startWeight: Double,
        currentWeight: Double,
        goalWeight: Double,
        direction: JourneyGoalDirection,
        progressPercent: Double,
        loggingStreak: Int,
        longestStreak: Int
    ) -> JourneyMilestonesState {
        let logs = makeLogs(count: foodLogDays, proteinGoalDays: proteinGoalDays)
        let baseline = makeBaseline(
            startWeight: startWeight,
            currentWeight: currentWeight,
            goalWeight: goalWeight,
            direction: direction,
            progressPercent: progressPercent,
            daysOnJourney: max(foodLogDays, 1),
            hasRealWeightEntries: foodLogDays > 0,
            usesSyntheticBaseline: foodLogDays == 0,
            chartPoints: []
        )
        let streaks = makeStreaks(
            currentLogging: loggingStreak,
            longestLogging: longestStreak,
            proteinStreak: min(proteinGoalDays, 5),
            waterStreak: 2,
            trainingWeeks: loggingStreak > 0 ? 2 : nil,
            isTodayLogged: loggingStreak > 0
        )

        return JourneyMilestonesBuilder.build(
            JourneyMilestonesBuilder.Input(
                baseline: baseline,
                maturityLogs: logs,
                journeyStreaks: streaks,
                healthWorkoutDayStarts: [],
                calendar: calendar
            )
        )
    }

    private static func makeStoryTimeline(
        foodLogDays: Int,
        startWeight: Double,
        currentWeight: Double,
        goalWeight: Double,
        direction: JourneyGoalDirection,
        progressPercent: Double,
        loggingStreak: Int,
        longestStreak: Int,
        weightEntries: [(daysAgo: Int, kg: Double)] = []
    ) -> JourneyStoryTimelineState {
        let logs = makeLogs(count: foodLogDays, proteinGoalDays: foodLogDays)
        let weights: [WeightEntry] = weightEntries.compactMap { entry in
            guard let date = calendar.date(byAdding: .day, value: -entry.daysAgo, to: today) else { return nil }
            return WeightEntry(
                id: UUID(),
                date: date,
                weightKg: entry.kg,
                note: nil,
                createdAt: date
            )
        }

        let baseline = makeBaseline(
            startWeight: startWeight,
            currentWeight: currentWeight,
            goalWeight: goalWeight,
            direction: direction,
            progressPercent: progressPercent,
            daysOnJourney: max(foodLogDays, 1),
            hasRealWeightEntries: !weights.isEmpty,
            usesSyntheticBaseline: weights.isEmpty,
            chartPoints: []
        )

        return JourneyTimelineBuilder.build(
            JourneyTimelineBuilder.Input(
                profile: previewProfile,
                baseline: baseline,
                maturityLogs: logs,
                allWeights: weights,
                healthWorkoutDayStarts: [],
                isAppleHealthConnected: false,
                journeyStreaks: makeStreaks(
                    currentLogging: loggingStreak,
                    longestLogging: longestStreak,
                    proteinStreak: min(foodLogDays, 5),
                    waterStreak: min(foodLogDays, 4),
                    trainingWeeks: foodLogDays > 0 ? 2 : nil,
                    isTodayLogged: loggingStreak > 0
                ),
                asOf: today,
                calendar: calendar
            )
        )
    }

    private static func makeWeeklyReview(
        foodLoggedDays: Int,
        proteinGoalDays: Int,
        waterGoalDays: Int,
        trainingDays: Int,
        expectedTrainingDays: Int,
        training: JourneyWeeklyTrainingStatus,
        weightDeltaThisWeekKg: Double?,
        calorieAdherenceDays: Int,
        goalDirection: JourneyGoalDirection,
        loggingStreak: Int,
        previousWeek: JourneyWeeklyReviewPreviousWeek? = nil
    ) -> JourneyWeeklyReviewState {
        let base = JourneyWeeklyReviewState(
            foodLoggedDays: foodLoggedDays,
            foodLoggedDaysTotal: 7,
            proteinGoalDays: proteinGoalDays,
            proteinGoalDaysTotal: 7,
            waterGoalDays: waterGoalDays,
            waterGoalDaysTotal: 7,
            trainingDays: trainingDays,
            expectedTrainingDays: expectedTrainingDays,
            training: training,
            weightDeltaThisWeekKg: weightDeltaThisWeekKg,
            calorieAdherenceDays: calorieAdherenceDays,
            calorieAdherenceDaysTotal: 7,
            weekSummaryCopy: JourneyWeeklyReviewBuilder.weekSummaryCopy(
                foodDays: foodLoggedDays,
                proteinDays: proteinGoalDays,
                trainingDays: trainingDays,
                goalDirection: goalDirection,
                weightDelta: weightDeltaThisWeekKg
            ),
            rows: [],
            weekOverWeekDetail: nil
        )

        return JourneyWeeklyReviewBuilder.enrich(
            review: base,
            previousWeek: previousWeek,
            goalDirection: goalDirection,
            streaks: makeStreaks(
                currentLogging: loggingStreak,
                longestLogging: max(loggingStreak, 14),
                proteinStreak: proteinGoalDays,
                waterStreak: waterGoalDays,
                trainingWeeks: trainingDays > 0 ? 2 : nil,
                isTodayLogged: loggingStreak > 0
            )
        )
    }

    private static func makeStreaks(
        currentLogging: Int,
        longestLogging: Int,
        proteinStreak: Int,
        waterStreak: Int,
        trainingWeeks: Int?,
        isTodayLogged: Bool
    ) -> JourneyStreakState {
        let copy = FormaProductCopy.Journey.Streaks.self
        let heroChip: JourneyStreakChipState = currentLogging > 0
            ? JourneyStreakChipState(
                isVisible: true,
                days: currentLogging,
                label: copy.loggingStreak(days: currentLogging)
            )
            : .hidden
        let weekly = currentLogging > 0
            ? (copy.loggingStreak(days: currentLogging), copy.longestLoggingStreak(days: longestLogging))
            : (copy.buildingConsistency, copy.longestLoggingStreak(days: longestLogging))

        return JourneyStreakState(
            currentLoggingStreakDays: currentLogging,
            longestLoggingStreakDays: longestLogging,
            currentProteinStreakDays: proteinStreak,
            currentWaterStreakDays: waterStreak,
            currentTrainingStreakWeeks: trainingWeeks,
            isTodayLogged: isTodayLogged,
            heroStreakChip: heroChip,
            weeklyConsistencyHeadline: weekly.0,
            weeklyConsistencyDetail: weekly.1,
            keepStreakAliveCopy: nil
        )
    }

    private static func makeTransformation(
        baseline: JourneyBaseline,
        loggedDays: Int,
        loggingStreak: Int,
        weightTrendDirection: WeightTrendDirection
    ) -> JourneyTransformationHeroState {
        let streaks = makeStreaks(
            currentLogging: loggingStreak,
            longestLogging: max(loggingStreak, 12),
            proteinStreak: 3,
            waterStreak: 2,
            trainingWeeks: loggingStreak > 0 ? 2 : nil,
            isTodayLogged: loggingStreak > 0
        )
        return JourneyTransformationHeroBuilder.build(
            JourneyTransformationHeroBuilder.Input(
                baseline: baseline,
                loggedDays: loggedDays,
                heroStreakChip: streaks.heroStreakChip,
                weightTrendDirection: weightTrendDirection,
                asOf: today,
                calendar: calendar
            )
        )
    }

    private static func makeLogs(count: Int, proteinGoalDays: Int) -> [DailyLog] {
        guard count > 0 else { return [] }
        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyLog(
                id: UUID(),
                date: date,
                weightKg: nil,
                targets: previewTargets,
                totals: MacroTotals(
                    calories: 1_800,
                    protein: proteinGoalDays > offset ? 140 : 80,
                    carbs: 120,
                    fat: 50,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: 2_000,
                steps: nil,
                workoutCaloriesBurned: 0,
                dailyReviewId: nil,
                createdAt: date,
                updatedAt: date
            )
        }
    }

    // MARK: - Chart helpers

    private static func syntheticChartPoints(startKg: Double) -> [WeightChartPoint] {
        [
            WeightChartPoint(
                date: calendar.startOfDay(for: today),
                weightKg: startKg,
                isSynthetic: true,
                pointLabel: .onboarding
            )
        ]
    }

    private static func decliningWeightPoints(
        startKg: Double,
        dropPerStep: Double,
        count: Int
    ) -> [WeightChartPoint] {
        (0..<count).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -(count - 1) + index, to: today) else {
                return nil
            }
            return WeightChartPoint(
                date: date,
                weightKg: startKg - (Double(index) * dropPerStep),
                isSynthetic: index == 0,
                pointLabel: index == 0 ? .onboarding : .logged
            )
        }
    }

    private static func risingWeightPoints(
        startKg: Double,
        risePerStep: Double,
        count: Int
    ) -> [WeightChartPoint] {
        (0..<count).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -(count - 1) + index, to: today) else {
                return nil
            }
            return WeightChartPoint(
                date: date,
                weightKg: startKg + (Double(index) * risePerStep),
                isSynthetic: index == 0,
                pointLabel: index == 0 ? .onboarding : .logged
            )
        }
    }

    private static func flatWeightPoints(kg: Double, count: Int) -> [WeightChartPoint] {
        (0..<count).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -(count - 1) + index, to: today) else {
                return nil
            }
            let wobble = index.isMultiple(of: 2) ? 0.05 : -0.05
            return WeightChartPoint(
                date: date,
                weightKg: kg + wobble,
                isSynthetic: index == 0,
                pointLabel: index == 0 ? .onboarding : .logged
            )
        }
    }

    private static func weightEntriesFromChart(
        _ points: [WeightChartPoint]
    ) -> [(daysAgo: Int, kg: Double)] {
        points
            .filter { !$0.isSynthetic }
            .compactMap { point in
                let days = calendar.dateComponents([.day], from: point.date, to: today).day ?? 0
                return (daysAgo: max(days, 0), kg: point.weightKg)
            }
    }
}
