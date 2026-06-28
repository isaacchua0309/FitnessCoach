//
//  TodayMealsGroupingEngine.swift
//  Fitness Coach
//
//  Forma — Pure grouping for Today meals by type with totals and time-based missing state.
//

import Foundation

struct TodayMealGroupState: Equatable, Identifiable, Sendable {
    var mealType: MealType
    var entries: [FoodEntry]
    var totalCalories: Int
    var totalProtein: Double
    var isLogged: Bool
    /// Meal window has passed and nothing was logged for this slot.
    var isPastDueMissing: Bool
    var isOptional: Bool

    var id: MealType { mealType }
    var hasMultipleEntries: Bool { entries.count > 1 }
}

struct TodayMealsSectionState: Equatable, Sendable {
    var groups: [TodayMealGroupState]
    var isFullyEmpty: Bool
}

enum TodayMealsGroupingEngine {

    static let primaryMeals: [MealType] = [.breakfast, .lunch, .dinner]
    /// Collapsed groups show this many item rows before expanding.
    static let entryPreviewLimit = 1

    static func build(
        entries: [FoodEntry],
        date: Date,
        calendar: Calendar = .current
    ) -> TodayMealsSectionState {
        let hour = calendar.component(.hour, from: date)
        let grouped = groupEntries(entries)

        var groups = primaryMeals.map { mealType in
            makeGroup(
                mealType: mealType,
                entries: grouped[mealType] ?? [],
                hour: hour,
                isOptional: false
            )
        }

        groups.append(
            makeGroup(
                mealType: .snack,
                entries: grouped[.snack] ?? [],
                hour: hour,
                isOptional: true
            )
        )

        return TodayMealsSectionState(
            groups: groups,
            isFullyEmpty: entries.isEmpty
        )
    }

    static func groupEntries(_ entries: [FoodEntry]) -> [MealType: [FoodEntry]] {
        var grouped: [MealType: [FoodEntry]] = [:]
        for entry in entries {
            let bucket = bucketMealType(entry.mealType)
            grouped[bucket, default: []].append(entry)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.createdAt < $1.createdAt }
        }
        return grouped
    }

    static func bucketMealType(_ mealType: MealType?) -> MealType {
        switch mealType {
        case .breakfast, .lunch, .dinner, .snack:
            return mealType!
        case .unknown, nil:
            return .snack
        }
    }

    static func totals(for entries: [FoodEntry]) -> (calories: Int, protein: Double) {
        (
            calories: entries.reduce(0) { $0 + $1.calories },
            protein: entries.reduce(0) { $0 + $1.protein }
        )
    }

    static func isPastDueMissing(mealType: MealType, isLogged: Bool, hour: Int) -> Bool {
        guard !isLogged else { return false }
        switch mealType {
        case .breakfast:
            return hour >= NextBestActionEngine.breakfastWindowEndHour
        case .lunch:
            return hour >= NextBestActionEngine.lunchWindowEndHour
        case .dinner:
            return hour >= NextBestActionEngine.dinnerWindowEndHour
        case .snack, .unknown:
            return false
        }
    }

    private static func makeGroup(
        mealType: MealType,
        entries: [FoodEntry],
        hour: Int,
        isOptional: Bool
    ) -> TodayMealGroupState {
        let totals = totals(for: entries)
        let isLogged = !entries.isEmpty
        return TodayMealGroupState(
            mealType: mealType,
            entries: entries,
            totalCalories: totals.calories,
            totalProtein: totals.protein,
            isLogged: isLogged,
            isPastDueMissing: isPastDueMissing(mealType: mealType, isLogged: isLogged, hour: hour),
            isOptional: isOptional
        )
    }
}
