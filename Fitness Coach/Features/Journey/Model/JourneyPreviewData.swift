//
//  JourneyPreviewData.swift
//  Fitness Coach
//
//  Forma — Deterministic Journey preview fixtures for UI previews and tests.
//

import Foundation

enum JourneyPreviewData {

    // MARK: - Scenarios

    enum Scenario: String, CaseIterable, Sendable {
        case brandNewUser
        case weekOne
        case strongMomentum
        case highlyConsistent
        case plateau
        case nearGoal
        case gainGoal
        case maintainGoal
        case healthDisconnected
        case healthConnected
        case sparseData
        case foodLogsOnly
        case weightLogsNoLoss
    }

    static let today = TrainingInsightsPreviewData.referenceNow

    private static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    static let strongMomentum = dashboard(.strongMomentum)
    static let state = strongMomentum
    static let baseline = strongMomentum.baseline

    static let brandNewUser = dashboard(.brandNewUser)
    static let weekOne = dashboard(.weekOne)
    static let highlyConsistent = dashboard(.highlyConsistent)
    static let plateau = dashboard(.plateau)
    static let nearGoal = dashboard(.nearGoal)
    static let gainGoal = dashboard(.gainGoal)
    static let maintainGoal = dashboard(.maintainGoal)
    static let healthDisconnected = dashboard(.healthDisconnected)
    static let healthConnected = dashboard(.healthConnected)
    static let sparseData = dashboard(.sparseData)
    static let foodLogsOnly = dashboard(.foodLogsOnly)
    static let weightLogsNoLoss = dashboard(.weightLogsNoLoss)

    static var monthlyRecapActive: JourneyMonthlyRecapState {
        strongMomentum.monthlyRecap
    }

    static func dashboard(_ scenario: Scenario) -> JourneyDashboardState {
        switch scenario {
        case .brandNewUser:
            return makeBrandNewUserDashboard()
        case .weekOne:
            return makeWeekOneDashboard()
        case .strongMomentum:
            return makeStrongMomentumDashboard()
        case .highlyConsistent:
            return makeHighlyConsistentDashboard()
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
        case .foodLogsOnly:
            return makeFoodLogsOnlyDashboard()
        case .weightLogsNoLoss:
            return makeWeightLogsNoLossDashboard()
        }
    }

    // MARK: - Section fixtures

    static var transformationNewUser: JourneyTransformationState {
        brandNewUser.transformation
    }

    static var transformationActiveFatLoss: JourneyTransformationState {
        strongMomentum.transformation
    }

    static var transformationNearGoal: JourneyTransformationState {
        nearGoal.transformation
    }

    static var transformationGainGoal: JourneyTransformationState {
        gainGoal.transformation
    }

    static var transformationMaintainGoal: JourneyTransformationState {
        maintainGoal.transformation
    }

    static var transformationPlateau: JourneyTransformationState {
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

    // MARK: - Dashboard factories

    private static func makeBrandNewUserDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .lose
        let profile = makeProfile(
            name: "Alex",
            currentWeight: 82,
            goalWeight: 74,
            createdDaysAgo: 0,
            trainingFrequencyPerWeek: 4
        )
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
        let streaks = makeStreaks(
            currentLogging: 0,
            longestLogging: 0,
            proteinStreak: 0,
            waterStreak: 0,
            trainingWeeks: nil,
            isTodayLogged: false
        )

        return JourneyPresentationBuilder.assembleFromLegacy(
            hasProfile: true,
            baseline: baseline,
            streaks: streaks,
            loggedDays: 0,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 0,
                proteinGoalDays: 0,
                waterGoalDays: 0,
                trainingDays: 0,
                expectedTrainingDays: 4,
                training: .hidden,
                weightDeltaThisWeekKg: nil,
                calorieAdherenceDays: 0,
                goalDirection: direction,
                streaks: streaks
            ),
            milestones: makeMilestones(
                baseline: baseline,
                foodLogDays: 0,
                proteinGoalDays: 0,
                waterGoalDays: 0,
                trainingWorkoutDays: 0,
                streaks: streaks
            ),
            storyTimeline: makeStoryTimeline(
                profile: profile,
                baseline: baseline,
                foodLogDays: 0,
                proteinGoalDays: 0,
                waterGoalDays: 0,
                trainingWorkoutDays: 0,
                streaks: streaks,
                healthConnected: false
            ),
            profile: profile,
            calendar: calendar,
            asOf: today
        )
    }

    private static func makeWeekOneDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .lose
        let profile = makeProfile(
            name: "Alex",
            currentWeight: 88.3,
            goalWeight: 75,
            createdDaysAgo: 6,
            trainingFrequencyPerWeek: 4
        )
        let baseline = makeBaseline(
            startWeight: 89,
            currentWeight: 88.3,
            goalWeight: 75,
            direction: direction,
            progressPercent: 5,
            daysOnJourney: 6,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: decliningWeightPoints(startKg: 89, dropPerStep: 0.23, count: 4)
        )

        return assembleRichDashboard(
            profile: profile,
            baseline: baseline,
            loggedDays: 6,
            loggingStreak: 3,
            longestStreak: 3,
            proteinStreak: 1,
            waterStreak: 1,
            trainingWeeks: nil,
            isTodayLogged: true,
            weightTrendDirection: .insufficientData,
            foodLogDays: 4,
            proteinGoalDays: 2,
            waterGoalDays: 2,
            weekFoodLoggedDays: 4,
            weekProteinGoalDays: 2,
            weekWaterGoalDays: 2,
            weekCalorieAdherenceDays: 2,
            trainingDays: 1,
            training: .connected(
                workoutDays: 1,
                averageCaloriesBurned: 240,
                averageTrainingDurationMinutes: 35
            ),
            weeklyWeightDeltaKg: -0.2,
            previousWeek: nil,
            healthConnected: true,
            healthWorkoutDayOffsets: [1]
        )
    }

    private static func makeHighlyConsistentDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .lose
        let profile = makeProfile(
            name: "Alex",
            currentWeight: 85.4,
            goalWeight: 75,
            createdDaysAgo: 56,
            trainingFrequencyPerWeek: 4
        )
        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 85.4,
            goalWeight: 75,
            direction: direction,
            progressPercent: 46,
            daysOnJourney: 56,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: decliningWeightPoints(startKg: 90.2, dropPerStep: 0.38, count: 12),
            estimatedMonth: "September"
        )

        return assembleRichDashboard(
            profile: profile,
            baseline: baseline,
            loggedDays: 48,
            loggingStreak: 14,
            longestStreak: 21,
            proteinStreak: 10,
            waterStreak: 9,
            trainingWeeks: 6,
            isTodayLogged: true,
            weightTrendDirection: .decreasing,
            foodLogDays: 48,
            proteinGoalDays: 42,
            waterGoalDays: 40,
            weekFoodLoggedDays: 7,
            weekProteinGoalDays: 7,
            weekWaterGoalDays: 7,
            weekCalorieAdherenceDays: 7,
            trainingDays: 4,
            training: .connected(
                workoutDays: 4,
                averageCaloriesBurned: 330,
                averageTrainingDurationMinutes: 48
            ),
            weeklyWeightDeltaKg: -0.5,
            previousWeek: JourneyWeeklyReviewPreviousWeek(
                foodLoggedDays: 7,
                proteinGoalDays: 7,
                waterGoalDays: 6,
                calorieAdherenceDays: 7,
                trainingDays: 4,
                weightDeltaKg: -0.4
            ),
            healthConnected: true,
            healthWorkoutDayOffsets: [28, 21, 14, 7]
        )
    }

    private static func makeStrongMomentumDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .lose
        let profile = makeProfile(
            name: "Alex",
            currentWeight: 86.2,
            goalWeight: 75,
            createdDaysAgo: 40,
            trainingFrequencyPerWeek: 4
        )
        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 86.2,
            goalWeight: 75,
            direction: direction,
            progressPercent: 42,
            daysOnJourney: 40,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: decliningWeightPoints(startKg: 90.2, dropPerStep: 0.44, count: 10),
            estimatedMonth: "October"
        )

        return assembleRichDashboard(
            profile: profile,
            baseline: baseline,
            loggedDays: 32,
            loggingStreak: 7,
            longestStreak: 21,
            proteinStreak: 5,
            waterStreak: 4,
            trainingWeeks: 3,
            isTodayLogged: true,
            weightTrendDirection: .decreasing,
            foodLogDays: 32,
            proteinGoalDays: 18,
            waterGoalDays: 16,
            weekFoodLoggedDays: 7,
            weekProteinGoalDays: 6,
            weekWaterGoalDays: 5,
            weekCalorieAdherenceDays: 6,
            trainingDays: 4,
            training: .connected(
                workoutDays: 4,
                averageCaloriesBurned: 310,
                averageTrainingDurationMinutes: 45
            ),
            weeklyWeightDeltaKg: -0.6,
            previousWeek: JourneyWeeklyReviewPreviousWeek(
                foodLoggedDays: 5,
                proteinGoalDays: 4,
                waterGoalDays: 3,
                calorieAdherenceDays: 4,
                trainingDays: 3,
                weightDeltaKg: -0.3
            ),
            healthConnected: true,
            healthWorkoutDayOffsets: [21, 15, 8, 1]
        )
    }

    private static func makePlateauDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .lose
        let profile = makeProfile(
            name: "Alex",
            currentWeight: 86.1,
            goalWeight: 75,
            createdDaysAgo: 38,
            trainingFrequencyPerWeek: 4
        )
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
            profile: profile,
            baseline: baseline,
            loggedDays: 28,
            loggingStreak: 7,
            longestStreak: 14,
            proteinStreak: 4,
            waterStreak: 3,
            trainingWeeks: 2,
            isTodayLogged: true,
            weightTrendDirection: .stable,
            foodLogDays: 28,
            proteinGoalDays: 15,
            waterGoalDays: 18,
            weekFoodLoggedDays: 6,
            weekProteinGoalDays: 5,
            weekWaterGoalDays: 5,
            weekCalorieAdherenceDays: 5,
            trainingDays: 3,
            training: .connected(
                workoutDays: 3,
                averageCaloriesBurned: 280,
                averageTrainingDurationMinutes: 40
            ),
            weeklyWeightDeltaKg: 0.0,
            previousWeek: JourneyWeeklyReviewPreviousWeek(
                foodLoggedDays: 6,
                proteinGoalDays: 5,
                waterGoalDays: 4,
                calorieAdherenceDays: 5,
                trainingDays: 3,
                weightDeltaKg: 0.1
            ),
            healthConnected: true,
            healthWorkoutDayOffsets: [17, 10, 3]
        )
    }

    private static func makeNearGoalDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .lose
        let profile = makeProfile(
            name: "Alex",
            currentWeight: 76.5,
            goalWeight: 75,
            createdDaysAgo: 60,
            trainingFrequencyPerWeek: 4
        )
        let baseline = makeBaseline(
            startWeight: 90,
            currentWeight: 76.5,
            goalWeight: 75,
            direction: direction,
            progressPercent: 90,
            daysOnJourney: 60,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: decliningWeightPoints(startKg: 90, dropPerStep: 1.23, count: 12),
            estimatedMonth: "July"
        )

        return assembleRichDashboard(
            profile: profile,
            baseline: baseline,
            loggedDays: 60,
            loggingStreak: 12,
            longestStreak: 21,
            proteinStreak: 7,
            waterStreak: 6,
            trainingWeeks: 4,
            isTodayLogged: true,
            weightTrendDirection: .decreasing,
            foodLogDays: 105,
            proteinGoalDays: 72,
            waterGoalDays: 70,
            weekFoodLoggedDays: 7,
            weekProteinGoalDays: 7,
            weekWaterGoalDays: 6,
            weekCalorieAdherenceDays: 7,
            trainingDays: 4,
            training: .connected(
                workoutDays: 4,
                averageCaloriesBurned: 320,
                averageTrainingDurationMinutes: 48
            ),
            weeklyWeightDeltaKg: -0.4,
            healthConnected: true,
            healthWorkoutDayOffsets: [30, 22, 15, 8, 1]
        )
    }

    private static func makeGainGoalDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .gain
        let profile = makeProfile(
            name: "Jordan",
            currentWeight: 65.8,
            goalWeight: 70,
            createdDaysAgo: 30,
            trainingFrequencyPerWeek: 4
        )
        let baseline = makeBaseline(
            startWeight: 62,
            currentWeight: 65.8,
            goalWeight: 70,
            direction: direction,
            progressPercent: 48,
            daysOnJourney: 30,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: risingWeightPoints(startKg: 62, risePerStep: 0.42, count: 10),
            estimatedMonth: "August"
        )

        return assembleRichDashboard(
            profile: profile,
            baseline: baseline,
            loggedDays: 24,
            loggingStreak: 5,
            longestStreak: 10,
            proteinStreak: 4,
            waterStreak: 3,
            trainingWeeks: 2,
            isTodayLogged: true,
            weightTrendDirection: .increasing,
            foodLogDays: 24,
            proteinGoalDays: 16,
            waterGoalDays: 14,
            weekFoodLoggedDays: 6,
            weekProteinGoalDays: 5,
            weekWaterGoalDays: 4,
            weekCalorieAdherenceDays: 5,
            trainingDays: 3,
            training: .connected(
                workoutDays: 3,
                averageCaloriesBurned: 350,
                averageTrainingDurationMinutes: 50
            ),
            weeklyWeightDeltaKg: 0.5,
            healthConnected: true,
            healthWorkoutDayOffsets: [16, 9, 2]
        )
    }

    private static func makeMaintainGoalDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .maintain
        let profile = makeProfile(
            name: "Taylor",
            currentWeight: 72.4,
            goalWeight: 72,
            createdDaysAgo: 45,
            trainingFrequencyPerWeek: 3
        )
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
            profile: profile,
            baseline: baseline,
            loggedDays: 30,
            loggingStreak: 4,
            longestStreak: 12,
            proteinStreak: 3,
            waterStreak: 4,
            trainingWeeks: 2,
            isTodayLogged: true,
            weightTrendDirection: .stable,
            foodLogDays: 30,
            proteinGoalDays: 20,
            waterGoalDays: 22,
            weekFoodLoggedDays: 6,
            weekProteinGoalDays: 5,
            weekWaterGoalDays: 5,
            weekCalorieAdherenceDays: 5,
            trainingDays: 3,
            training: .connected(
                workoutDays: 3,
                averageCaloriesBurned: 260,
                averageTrainingDurationMinutes: 35
            ),
            weeklyWeightDeltaKg: 0.1,
            healthConnected: true,
            healthWorkoutDayOffsets: [14, 7, 1]
        )
    }

    private static func makeHealthDisconnectedDashboard() -> JourneyDashboardState {
        var dashboard = makeStrongMomentumDashboard()
        var review = dashboard.weeklyReview
        review.training = .locked
        review.trainingDays = 0
        review.weekSummaryCopy = JourneyWeeklyReviewBuilder.weekSummaryCopy(
            foodDays: review.foodLoggedDays,
            proteinDays: review.proteinGoalDays,
            trainingDays: 0,
            goalDirection: dashboard.baseline.goalDirection,
            weightDelta: review.weightDeltaThisWeekKg
        )
        review.rows = JourneyWeeklyReviewBuilder.rows(
            for: review,
            goalDirection: dashboard.baseline.goalDirection
        )

        let weekLogs = makeLogs(
            count: 7,
            proteinGoalDays: 6,
            waterGoalDays: 5,
            calorieAdherenceDays: 6,
            trainingWorkoutDays: 0
        )
        let maturityLogs = makeLogs(
            count: 32,
            proteinGoalDays: 18,
            waterGoalDays: 16,
            calorieAdherenceDays: 32,
            trainingWorkoutDays: 0
        )
        let weights = weightEntriesFromChart(dashboard.baseline.chartPoints)

        dashboard.weeklyHabit = JourneyWeeklyPatternBuilder.build(
            JourneyWeeklyPatternBuilder.Input(
                weekLogs: weekLogs,
                weekWeights: weights,
                maturityLogs: maturityLogs,
                allWeights: weights,
                healthWorkoutDayStarts: [],
                weeklyTraining: review.training,
                expectedTrainingDays: review.expectedTrainingDays,
                streaks: dashboard.streaks,
                streakSummary: StreakSummary(
                    loggingStreak: dashboard.streaks.currentLoggingStreakDays,
                    mealLoggingStreak: dashboard.streaks.currentMealLoggingStreakDays,
                    checkInStreak: dashboard.streaks.currentCheckInStreakDays,
                    proteinStreak: dashboard.streaks.currentProteinStreakDays,
                    hydrationStreak: dashboard.streaks.currentWaterStreakDays,
                    workoutStreak: dashboard.streaks.currentActivityStreakDays
                ),
                weeklyReview: review,
                asOf: today,
                calendar: calendar
            )
        )
        return dashboard
    }

    private static func makeHealthConnectedDashboard() -> JourneyDashboardState {
        makeStrongMomentumDashboard()
    }

    private static func makeFoodLogsOnlyDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .lose
        let profile = makeProfile(
            name: "Alex",
            currentWeight: 82,
            goalWeight: 74,
            createdDaysAgo: 5,
            trainingFrequencyPerWeek: 4
        )
        let baseline = makeBaseline(
            startWeight: 82,
            currentWeight: 82,
            goalWeight: 74,
            direction: direction,
            progressPercent: 0,
            daysOnJourney: 5,
            hasRealWeightEntries: false,
            usesSyntheticBaseline: true,
            chartPoints: syntheticChartPoints(startKg: 82)
        )
        let streaks = makeStreaks(
            currentLogging: 3,
            longestLogging: 3,
            proteinStreak: 1,
            waterStreak: 1,
            trainingWeeks: nil,
            isTodayLogged: true
        )
        let maturityLogs = makeLogs(
            count: 5,
            proteinGoalDays: 2,
            waterGoalDays: 2,
            calorieAdherenceDays: 5,
            trainingWorkoutDays: 0
        )
        let weekLogs = makeLogs(
            count: 5,
            proteinGoalDays: 2,
            waterGoalDays: 2,
            calorieAdherenceDays: 5,
            trainingWorkoutDays: 0
        )

        return JourneyPresentationBuilder.assembleFromLegacy(
            hasProfile: true,
            baseline: baseline,
            streaks: streaks,
            loggedDays: 5,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 5,
                proteinGoalDays: 2,
                waterGoalDays: 2,
                trainingDays: 0,
                expectedTrainingDays: 4,
                training: .hidden,
                weightDeltaThisWeekKg: nil,
                calorieAdherenceDays: 4,
                goalDirection: direction,
                streaks: streaks
            ),
            milestones: makeMilestones(
                baseline: baseline,
                foodLogDays: 5,
                proteinGoalDays: 2,
                waterGoalDays: 2,
                trainingWorkoutDays: 0,
                streaks: streaks
            ),
            storyTimeline: makeStoryTimeline(
                profile: profile,
                baseline: baseline,
                foodLogDays: 5,
                proteinGoalDays: 2,
                waterGoalDays: 2,
                trainingWorkoutDays: 0,
                streaks: streaks,
                healthConnected: false
            ),
            profile: profile,
            maturityLogs: maturityLogs,
            monthLogs: maturityLogs,
            weekLogs: weekLogs,
            allWeights: [],
            weightTrendDirection: .insufficientData,
            calendar: calendar,
            asOf: today
        )
    }

    private static func makeWeightLogsNoLossDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .lose
        let profile = makeProfile(
            name: "Alex",
            currentWeight: 88.0,
            goalWeight: 75,
            createdDaysAgo: 20,
            trainingFrequencyPerWeek: 4
        )
        let chartPoints = flatWeightPoints(kg: 88.0, count: 8)
        let baseline = makeBaseline(
            startWeight: 88,
            currentWeight: 88.0,
            goalWeight: 75,
            direction: direction,
            progressPercent: 0,
            daysOnJourney: 20,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: chartPoints
        )
        let streaks = makeStreaks(
            currentLogging: 2,
            longestLogging: 4,
            proteinStreak: 1,
            waterStreak: 0,
            trainingWeeks: nil,
            isTodayLogged: false
        )
        let maturityLogs = makeLogs(
            count: 4,
            proteinGoalDays: 2,
            waterGoalDays: 1,
            calorieAdherenceDays: 4,
            trainingWorkoutDays: 0
        )
        let weights = weightEntriesFromChart(chartPoints)

        return JourneyPresentationBuilder.assembleFromLegacy(
            hasProfile: true,
            baseline: baseline,
            streaks: streaks,
            loggedDays: 4,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 3,
                proteinGoalDays: 2,
                waterGoalDays: 1,
                trainingDays: 0,
                expectedTrainingDays: 4,
                training: .hidden,
                weightDeltaThisWeekKg: 0.0,
                calorieAdherenceDays: 3,
                goalDirection: direction,
                streaks: streaks
            ),
            milestones: makeMilestones(
                baseline: baseline,
                foodLogDays: 4,
                proteinGoalDays: 2,
                waterGoalDays: 1,
                trainingWorkoutDays: 0,
                streaks: streaks
            ),
            storyTimeline: makeStoryTimeline(
                profile: profile,
                baseline: baseline,
                foodLogDays: 4,
                proteinGoalDays: 2,
                waterGoalDays: 1,
                trainingWorkoutDays: 0,
                streaks: streaks,
                healthConnected: false,
                weightEntries: weights
            ),
            profile: profile,
            maturityLogs: maturityLogs,
            monthLogs: maturityLogs,
            weekLogs: Array(maturityLogs.prefix(3)),
            allWeights: weights,
            weekWeights: weights,
            weightTrendDirection: .stable,
            calendar: calendar,
            asOf: today
        )
    }

    private static func makeSparseDataDashboard() -> JourneyDashboardState {
        let direction: JourneyGoalDirection = .lose
        let profile = makeProfile(
            name: "Alex",
            currentWeight: 87.8,
            goalWeight: 75,
            createdDaysAgo: 5,
            trainingFrequencyPerWeek: 4
        )
        let baseline = makeBaseline(
            startWeight: 88,
            currentWeight: 87.8,
            goalWeight: 75,
            direction: direction,
            progressPercent: 2,
            daysOnJourney: 5,
            hasRealWeightEntries: true,
            usesSyntheticBaseline: false,
            chartPoints: decliningWeightPoints(startKg: 88, dropPerStep: 0.2, count: 2)
        )
        let streaks = makeStreaks(
            currentLogging: 0,
            longestLogging: 2,
            proteinStreak: 1,
            waterStreak: 0,
            trainingWeeks: nil,
            isTodayLogged: false
        )

        return JourneyPresentationBuilder.assembleFromLegacy(
            hasProfile: true,
            baseline: baseline,
            streaks: streaks,
            loggedDays: 2,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: 2,
                proteinGoalDays: 1,
                waterGoalDays: 1,
                trainingDays: 0,
                expectedTrainingDays: 4,
                training: .hidden,
                weightDeltaThisWeekKg: nil,
                calorieAdherenceDays: 1,
                goalDirection: direction,
                streaks: streaks
            ),
            milestones: makeMilestones(
                baseline: baseline,
                foodLogDays: 2,
                proteinGoalDays: 1,
                waterGoalDays: 1,
                trainingWorkoutDays: 0,
                streaks: streaks
            ),
            storyTimeline: makeStoryTimeline(
                profile: profile,
                baseline: baseline,
                foodLogDays: 2,
                proteinGoalDays: 1,
                waterGoalDays: 1,
                trainingWorkoutDays: 0,
                streaks: streaks,
                healthConnected: false,
                weightEntries: weightEntries(from: [(daysAgo: 0, kg: 87.8)])
            ),
            profile: profile,
            maturityLogs: makeLogs(
                count: 2,
                proteinGoalDays: 1,
                waterGoalDays: 1,
                calorieAdherenceDays: 1,
                trainingWorkoutDays: 0
            ),
            monthLogs: makeLogs(
                count: 2,
                proteinGoalDays: 1,
                waterGoalDays: 1,
                calorieAdherenceDays: 1,
                trainingWorkoutDays: 0
            ),
            weekLogs: makeLogs(
                count: 2,
                proteinGoalDays: 1,
                waterGoalDays: 1,
                calorieAdherenceDays: 1,
                trainingWorkoutDays: 0
            ),
            allWeights: weightEntriesFromChart(baseline.chartPoints),
            weightTrendDirection: .insufficientData,
            calendar: calendar,
            asOf: today
        )
    }

    // MARK: - Shared assembly

    private static func assembleRichDashboard(
        profile: UserProfile,
        baseline: JourneyBaseline,
        loggedDays: Int,
        loggingStreak: Int,
        longestStreak: Int,
        proteinStreak: Int,
        waterStreak: Int,
        trainingWeeks: Int?,
        isTodayLogged: Bool,
        weightTrendDirection: WeightTrendDirection,
        foodLogDays: Int,
        proteinGoalDays: Int,
        waterGoalDays: Int,
        weekFoodLoggedDays: Int,
        weekProteinGoalDays: Int,
        weekWaterGoalDays: Int,
        weekCalorieAdherenceDays: Int,
        trainingDays: Int,
        training: JourneyWeeklyTrainingStatus,
        weeklyWeightDeltaKg: Double?,
        previousWeek: JourneyWeeklyReviewPreviousWeek? = nil,
        healthConnected: Bool,
        healthWorkoutDayOffsets: [Int] = []
    ) -> JourneyDashboardState {
        let streaks = makeStreaks(
            currentLogging: loggingStreak,
            longestLogging: longestStreak,
            proteinStreak: proteinStreak,
            waterStreak: waterStreak,
            trainingWeeks: trainingWeeks,
            isTodayLogged: isTodayLogged
        )
        let maturityLogs = makeLogs(
            count: foodLogDays,
            proteinGoalDays: proteinGoalDays,
            waterGoalDays: waterGoalDays,
            calorieAdherenceDays: foodLogDays,
            trainingWorkoutDays: healthConnected ? max(trainingDays, 1) : trainingDays
        )
        let weekLogs = makeLogs(
            count: weekFoodLoggedDays,
            proteinGoalDays: weekProteinGoalDays,
            waterGoalDays: weekWaterGoalDays,
            calorieAdherenceDays: weekCalorieAdherenceDays,
            trainingWorkoutDays: trainingDays
        )
        let weights = weightEntriesFromChart(baseline.chartPoints)
        let goalProjection = baseline.goalWeightKg.map {
            ProgressProjectionCalculator.projection(
                weights: weights,
                goalWeightKg: $0,
                asOf: today
            )
        }

        return JourneyPresentationBuilder.assembleFromLegacy(
            hasProfile: true,
            baseline: baseline,
            streaks: streaks,
            loggedDays: loggedDays,
            weeklyReview: makeWeeklyReview(
                foodLoggedDays: weekFoodLoggedDays,
                proteinGoalDays: weekProteinGoalDays,
                waterGoalDays: weekWaterGoalDays,
                trainingDays: trainingDays,
                expectedTrainingDays: JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: profile),
                training: training,
                weightDeltaThisWeekKg: weeklyWeightDeltaKg,
                calorieAdherenceDays: weekCalorieAdherenceDays,
                goalDirection: baseline.goalDirection,
                streaks: streaks,
                previousWeek: previousWeek
            ),
            milestones: makeMilestones(
                baseline: baseline,
                foodLogDays: foodLogDays,
                proteinGoalDays: proteinGoalDays,
                waterGoalDays: waterGoalDays,
                trainingWorkoutDays: healthConnected ? max(trainingDays, 1) : trainingDays,
                streaks: streaks,
                healthWorkoutDayOffsets: healthWorkoutDayOffsets
            ),
            storyTimeline: makeStoryTimeline(
                profile: profile,
                baseline: baseline,
                foodLogDays: foodLogDays,
                proteinGoalDays: proteinGoalDays,
                waterGoalDays: waterGoalDays,
                trainingWorkoutDays: healthConnected ? max(trainingDays, 1) : trainingDays,
                streaks: streaks,
                healthConnected: healthConnected,
                healthWorkoutDayOffsets: healthWorkoutDayOffsets,
                weightEntries: weightEntriesFromChart(baseline.chartPoints)
            ),
            goalProjection: goalProjection,
            profile: profile,
            maturityLogs: maturityLogs,
            monthLogs: maturityLogs,
            weekLogs: weekLogs,
            allWeights: weights,
            weekWeights: weights,
            weeklyTraining: training,
            healthWorkoutDayStarts: makeHealthWorkoutDayStarts(healthWorkoutDayOffsets),
            monthHealthWorkoutCount: healthConnected ? healthWorkoutDayOffsets.count : 0,
            weightTrendDirection: weightTrendDirection,
            calendar: calendar,
            asOf: today
        )
    }

    // MARK: - Helper factories

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

    private static func makeProfile(
        name: String,
        currentWeight: Double,
        goalWeight: Double,
        createdDaysAgo: Int,
        trainingFrequencyPerWeek: Int
    ) -> UserProfile {
        let createdAt = calendar.date(byAdding: .day, value: -createdDaysAgo, to: today) ?? today
        return UserProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: name,
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: currentWeight,
            goalWeightKg: goalWeight,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek,
            averageSteps: 7_000,
            unitSystem: .metric,
            targets: previewTargets,
            createdAt: createdAt,
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
        let totalChange: Double
        switch direction {
        case .lose, .gain:
            totalChange = currentWeight - startWeight
        case .maintain:
            totalChange = abs(currentWeight - startWeight)
        }

        return JourneyBaseline(
            startWeightKg: startWeight,
            startDate: calendar.date(byAdding: .day, value: -daysOnJourney, to: today) ?? today,
            currentWeightKg: currentWeight,
            goalWeightKg: goalWeight,
            goalDirection: direction,
            totalChangeKg: totalChange,
            remainingChangeKg: abs(currentWeight - goalWeight),
            progressPercent: progressPercent,
            estimatedCompletionDate: estimatedMonth == nil
                ? nil
                : calendar.date(byAdding: .day, value: 90, to: today),
            estimatedCompletionMonthLabel: estimatedMonth,
            hasRealWeightEntries: hasRealWeightEntries,
            usesSyntheticBaselinePoint: usesSyntheticBaseline,
            onboardingBaselineWeightKg: startWeight,
            chartPoints: chartPoints,
            showsWeightChart: !chartPoints.isEmpty
        )
    }

    private static func makeMilestones(
        baseline: JourneyBaseline,
        foodLogDays: Int,
        proteinGoalDays: Int,
        waterGoalDays: Int,
        trainingWorkoutDays: Int,
        streaks: JourneyStreakState,
        healthWorkoutDayOffsets: [Int] = []
    ) -> JourneyMilestonesState {
        JourneyMilestonesBuilder.build(
            JourneyMilestonesBuilder.Input(
                baseline: baseline,
                maturityLogs: makeLogs(
                    count: foodLogDays,
                    proteinGoalDays: proteinGoalDays,
                    waterGoalDays: waterGoalDays,
                    calorieAdherenceDays: foodLogDays,
                    trainingWorkoutDays: trainingWorkoutDays
                ),
                journeyStreaks: streaks,
                healthWorkoutDayStarts: makeHealthWorkoutDayStarts(healthWorkoutDayOffsets),
                calendar: calendar
            )
        )
    }

    private static func makeStoryTimeline(
        profile: UserProfile,
        baseline: JourneyBaseline,
        foodLogDays: Int,
        proteinGoalDays: Int,
        waterGoalDays: Int,
        trainingWorkoutDays: Int,
        streaks: JourneyStreakState,
        healthConnected: Bool,
        healthWorkoutDayOffsets: [Int] = [],
        weightEntries: [WeightEntry] = []
    ) -> JourneyStoryTimelineState {
        let logs = makeLogs(
            count: foodLogDays,
            proteinGoalDays: proteinGoalDays,
            waterGoalDays: waterGoalDays,
            calorieAdherenceDays: foodLogDays,
            trainingWorkoutDays: trainingWorkoutDays
        )
        let weights = weightEntries

        return JourneyTimelineBuilder.build(
            JourneyTimelineBuilder.Input(
                profile: profile,
                baseline: baseline,
                maturityLogs: logs,
                allWeights: weights,
                healthWorkoutDayStarts: makeHealthWorkoutDayStarts(healthWorkoutDayOffsets),
                isAppleHealthConnected: healthConnected,
                unlockedMilestoneCount: 0,
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
        streaks: JourneyStreakState,
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
            weekOverWeekDetail: nil,
            consistencyHeadline: nil,
            consistencyDetail: nil
        )

        return JourneyWeeklyReviewBuilder.enrich(
            review: base,
            previousWeek: previousWeek,
            goalDirection: goalDirection,
            streaks: streaks
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
        let headline = currentLogging > 0
            ? copy.loggingStreak(days: currentLogging)
            : copy.buildingConsistency
        let detail = longestLogging > 0
            ? copy.longestLoggingStreak(days: longestLogging)
            : nil

        return JourneyStreakState.legacy(
            currentLoggingStreakDays: currentLogging,
            longestLoggingStreakDays: longestLogging,
            currentProteinStreakDays: proteinStreak,
            currentWaterStreakDays: waterStreak,
            currentTrainingStreakWeeks: trainingWeeks,
            isTodayLogged: isTodayLogged,
            heroStreakChip: heroChip,
            weeklyConsistencyHeadline: headline,
            weeklyConsistencyDetail: detail,
            keepStreakAliveCopy: nil,
            mealLoggingStreakDays: currentLogging
        )
    }

    private static func makeLogs(
        count: Int,
        proteinGoalDays: Int,
        waterGoalDays: Int,
        calorieAdherenceDays: Int,
        trainingWorkoutDays: Int
    ) -> [DailyLog] {
        guard count > 0 else { return [] }

        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }

            let hitsProtein = offset < proteinGoalDays
            let hitsWater = offset < waterGoalDays
            let hitsCalories = offset < calorieAdherenceDays
            let hasWorkout = offset < trainingWorkoutDays

            return DailyLog(
                id: UUID(),
                date: date,
                weightKg: nil,
                targets: previewTargets,
                totals: MacroTotals(
                    calories: hitsCalories ? 1_800 : 2_150,
                    protein: hitsProtein ? 140 : 85,
                    carbs: 155,
                    fat: 55,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: hitsWater ? 2_500 : 600,
                steps: nil,
                workoutCaloriesBurned: hasWorkout ? 300 : 0,
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
        guard count > 0 else { return [] }

        return (0..<count).compactMap { index in
            guard let date = calendar.date(
                byAdding: .day,
                value: -(count - 1) + index,
                to: today
            ) else {
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
        guard count > 0 else { return [] }

        return (0..<count).compactMap { index in
            guard let date = calendar.date(
                byAdding: .day,
                value: -(count - 1) + index,
                to: today
            ) else {
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
        guard count > 0 else { return [] }

        return (0..<count).compactMap { index in
            guard let date = calendar.date(
                byAdding: .day,
                value: -(count - 1) + index,
                to: today
            ) else {
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

    private static func weightEntries(
        from tuples: [(daysAgo: Int, kg: Double)]
    ) -> [WeightEntry] {
        tuples.compactMap { entry -> WeightEntry? in
            guard let date = calendar.date(byAdding: .day, value: -entry.daysAgo, to: today) else {
                return nil
            }
            return WeightEntry(
                id: UUID(),
                date: date,
                weightKg: entry.kg,
                note: nil,
                createdAt: date
            )
        }
    }

    private static func weightEntriesFromChart(
        _ points: [WeightChartPoint]
    ) -> [WeightEntry] {
        weightEntries(
            from: points
                .filter { !$0.isSynthetic }
                .compactMap { point in
                    let days = calendar.dateComponents(
                        [.day],
                        from: calendar.startOfDay(for: point.date),
                        to: calendar.startOfDay(for: today)
                    ).day ?? 0
                    return (daysAgo: max(days, 0), kg: point.weightKg)
                }
        )
    }

    private static func makeHealthWorkoutDayStarts(_ offsets: [Int]) -> Set<Date> {
        Set(
            offsets.compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                    return nil
                }
                return calendar.startOfDay(for: date)
            }
        )
    }
}
