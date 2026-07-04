//
//  CoachContextFoodMemoryBuilder.swift
//  Fitness Coach
//
//  Forma — Builds structured recent meals and common-food memory for CoachContextPacketV2.
//  Pure deterministic mapping from food log entries; no repository access.
//

import Foundation

enum CoachContextFoodMemoryBuilder {

    static let minCommonFoodFrequency = 2
    static let minReliableMacroSamples = 2

    private struct FoodAggregate {
        var displayName: String
        var count: Int
        var lastLoggedAt: Date
        var calories: [Int]
        var protein: [Double]
        var carbs: [Double]
        var fat: [Double]
        var confidences: [ConfidenceLevel]
    }

    // MARK: Recent meals

    static func makeRecentMeals(
        from entries: [FoodEntry],
        todayLocalDate: String,
        calendar: Calendar,
        limit: Int = CoachContextPacketV2Limits.maxRecentMeals
    ) -> [CoachRecentMealContext] {
        guard limit > 0, !entries.isEmpty else { return [] }

        let todayEntries = entries.filter {
            CoachTimelineEvent.makeTimestamps(from: $0.createdAt, calendar: calendar).localDate == todayLocalDate
        }
        let priorEntries = entries.filter {
            CoachTimelineEvent.makeTimestamps(from: $0.createdAt, calendar: calendar).localDate != todayLocalDate
        }

        let todaySorted = todayEntries.sorted { $0.createdAt > $1.createdAt }
        let priorSorted = priorEntries.sorted { $0.createdAt > $1.createdAt }

        var selected: [FoodEntry] = []
        selected.reserveCapacity(limit)
        selected.append(contentsOf: todaySorted.prefix(limit))

        if selected.count < limit {
            let remaining = limit - selected.count
            selected.append(contentsOf: priorSorted.prefix(remaining))
        }

        return selected.map { CoachRecentMealContext.from(entry: $0, calendar: calendar) }
    }

    // MARK: Common foods

    static func makeCommonFoods(
        from entries: [FoodEntry],
        limit: Int = CoachContextPacketV2Limits.maxCommonFoods
    ) -> [CoachCommonFoodContext] {
        guard limit > 0, !entries.isEmpty else { return [] }

        var aggregates: [String: FoodAggregate] = [:]

        for entry in entries {
            let normalized = normalizedFoodName(entry.name)
            guard !normalized.isEmpty else { continue }

            var aggregate = aggregates[normalized] ?? FoodAggregate(
                displayName: entry.name.trimmingCharacters(in: .whitespacesAndNewlines),
                count: 0,
                lastLoggedAt: entry.createdAt,
                calories: [],
                protein: [],
                carbs: [],
                fat: [],
                confidences: []
            )

            aggregate.count += 1
            if entry.createdAt > aggregate.lastLoggedAt {
                aggregate.lastLoggedAt = entry.createdAt
                aggregate.displayName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            aggregate.calories.append(entry.calories)
            aggregate.protein.append(entry.protein)
            aggregate.carbs.append(entry.carbs)
            aggregate.fat.append(entry.fat)
            aggregate.confidences.append(entry.confidence)
            aggregates[normalized] = aggregate
        }

        return aggregates
            .compactMap { normalized, aggregate -> CoachCommonFoodContext? in
                guard isEligibleCommonFood(aggregate) else { return nil }

                let reliableSamples = zip(
                    aggregate.confidences.indices,
                    aggregate.confidences
                ).filter { $0.element != .low }.count

                let macrosReliable = aggregate.count >= minReliableMacroSamples
                    && reliableSamples >= minReliableMacroSamples

                return CoachCommonFoodContext(
                    normalizedName: normalized,
                    displayName: aggregate.displayName,
                    frequency: aggregate.count,
                    lastLoggedAt: aggregate.lastLoggedAt,
                    typicalCalories: macrosReliable ? averageInt(aggregate.calories) : nil,
                    typicalProteinGrams: macrosReliable ? averageMacro(aggregate.protein) : nil,
                    typicalCarbsGrams: macrosReliable ? averageMacro(aggregate.carbs) : nil,
                    typicalFatGrams: macrosReliable ? averageMacro(aggregate.fat) : nil,
                    macroConfidence: macrosReliable
                        ? macroConfidence(from: aggregate.confidences)
                        : nil
                )
            }
            .sorted {
                if $0.frequency == $1.frequency {
                    return ($0.lastLoggedAt ?? .distantPast) > ($1.lastLoggedAt ?? .distantPast)
                }
                return ($0.frequency ?? 0) > ($1.frequency ?? 0)
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Helpers

    static func normalizedFoodName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isEligibleCommonFood(_ aggregate: FoodAggregate) -> Bool {
        guard aggregate.count >= minCommonFoodFrequency else { return false }

        let lowConfidenceCount = aggregate.confidences.filter { $0 == .low }.count
        if aggregate.count == minCommonFoodFrequency, lowConfidenceCount == aggregate.count {
            return false
        }

        return true
    }

    private static func averageInt(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    private static func averageMacro(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let average = values.reduce(0, +) / Double(values.count)
        let rounded = (average * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0 ? average.rounded() : rounded
    }

    private static func macroConfidence(from confidences: [ConfidenceLevel]) -> CoachContextConfidence {
        guard !confidences.isEmpty else { return .unknown }

        if confidences.allSatisfy({ $0 == .high }) {
            return .high
        }

        let reliableCount = confidences.filter { $0 != .low }.count
        if reliableCount >= minReliableMacroSamples {
            return .medium
        }

        return .low
    }
}
