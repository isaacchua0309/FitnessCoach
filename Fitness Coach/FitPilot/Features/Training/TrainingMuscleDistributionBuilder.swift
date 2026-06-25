//
//  TrainingMuscleDistributionBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Muscle group distribution from logged exercise sets.
//

import Foundation

struct MuscleDistributionItem: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let setCount: Int
    let progress: Double
}

enum TrainingMuscleGroup: String, CaseIterable, Sendable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case cardio = "Cardio"
    case other = "Other"
}

enum TrainingMuscleDistributionBuilder {

    private static let displayOrder: [TrainingMuscleGroup] = [
        .chest, .back, .legs, .shoulders, .arms, .core, .cardio, .other
    ]

    static func distribution(from sets: [ExerciseSet]) -> [MuscleDistributionItem] {
        guard !sets.isEmpty else { return [] }

        var counts: [TrainingMuscleGroup: Int] = [:]
        for set in sets {
            let group = muscleGroup(for: set.exerciseName)
            counts[group, default: 0] += 1
        }

        let maxCount = counts.values.max() ?? 1

        return displayOrder.compactMap { group in
            guard let count = counts[group], count > 0 else { return nil }
            return MuscleDistributionItem(
                name: group.rawValue,
                setCount: count,
                progress: Double(count) / Double(maxCount)
            )
        }
    }

    static func muscleGroup(for exerciseName: String) -> TrainingMuscleGroup {
        let name = exerciseName.lowercased()

        if matches(name, keywords: [
            "bench", "chest", "fly", "push-up", "pushup", "dip", "pec"
        ]) {
            return .chest
        }

        if matches(name, keywords: [
            "row", "pull-up", "pullup", "chin-up", "lat", "deadlift", "back", "pulldown"
        ]) {
            return .back
        }

        if matches(name, keywords: [
            "squat", "leg", "lunge", "calf", "hamstring", "quad", "glute", "hip thrust"
        ]) {
            return .legs
        }

        if matches(name, keywords: [
            "shoulder", "overhead press", "ohp", "lateral raise", "delt"
        ]) {
            return .shoulders
        }

        if matches(name, keywords: [
            "curl", "tricep", "bicep", "arm", "extension", "skull"
        ]) {
            return .arms
        }

        if matches(name, keywords: [
            "plank", "crunch", "core", "ab", "sit-up", "situp"
        ]) {
            return .core
        }

        if matches(name, keywords: [
            "run", "jog", "walk", "cycle", "bike", "swim", "cardio", "badminton",
            "tennis", "soccer", "football", "basketball", "hiit", "elliptical", "rower"
        ]) {
            return .cardio
        }

        return .other
    }

    private static func matches(_ name: String, keywords: [String]) -> Bool {
        keywords.contains { name.contains($0) }
    }
}
