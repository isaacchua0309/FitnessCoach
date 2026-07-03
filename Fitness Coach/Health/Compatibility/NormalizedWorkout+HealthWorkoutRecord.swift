//
//  NormalizedWorkout+HealthWorkoutRecord.swift
//  Fitness Coach
//
//  Forma — Maps Health Intelligence workouts to legacy Training Insights records.
//

import Foundation

extension NormalizedWorkout {

    var asHealthWorkoutRecord: HealthWorkoutRecord {
        HealthWorkoutRecord(
            id: id,
            activityName: activityLabel,
            startDate: startDate,
            endDate: endDate,
            durationMinutes: durationMinutes,
            activeCalories: activeEnergyKcal > 0 ? Int(activeEnergyKcal.rounded()) : nil
        )
    }
}
