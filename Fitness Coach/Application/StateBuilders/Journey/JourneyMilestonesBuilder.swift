//
//  JourneyMilestonesBuilder.swift
//  Fitness Coach
//
//  Forma — Legacy milestone rail adapter for the next-achievement builder.
//

import Foundation

enum JourneyMilestonesBuilder {

    struct Input: Equatable {
        var profile: UserProfile?
        var baseline: JourneyBaseline
        var maturityLogs: [DailyLog]
        var journeyStreaks: JourneyStreakState
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var asOf: Date
        var calendar: Calendar

        init(
            profile: UserProfile? = nil,
            baseline: JourneyBaseline,
            maturityLogs: [DailyLog],
            journeyStreaks: JourneyStreakState,
            allWeights: [WeightEntry] = [],
            healthWorkoutDayStarts: Set<Date>,
            asOf: Date = Date(),
            calendar: Calendar
        ) {
            self.profile = profile
            self.baseline = baseline
            self.maturityLogs = maturityLogs
            self.journeyStreaks = journeyStreaks
            self.allWeights = allWeights
            self.healthWorkoutDayStarts = healthWorkoutDayStarts
            self.asOf = asOf
            self.calendar = calendar
        }
    }

    static func build(_ input: Input) -> JourneyMilestonesState {
        JourneyNextMilestoneBuilder.build(
            JourneyNextMilestoneBuilder.Input(
                profile: input.profile,
                baseline: input.baseline,
                maturityLogs: input.maturityLogs,
                allWeights: input.allWeights,
                healthWorkoutDayStarts: input.healthWorkoutDayStarts,
                asOf: input.asOf,
                calendar: input.calendar
            )
        ).legacyMilestones
    }
}
