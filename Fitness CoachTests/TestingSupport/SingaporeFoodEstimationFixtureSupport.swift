//
//  SingaporeFoodEstimationFixtureSupport.swift
//  Fitness CoachTests
//
//  Loads Singapore/local food estimation QA fixtures and validates ranges loosely.
//

import Foundation
@testable import Fitness_Coach

struct SingaporeFoodEstimationFixtureFile: Decodable {
    let version: Int
    let description: String
    let caseCount: Int
    let cases: [SingaporeFoodEstimationCase]
}

struct SingaporeFoodEstimationCase: Decodable, Equatable {
    let id: String
    let inputText: String
    let expectedComponents: [String]
    let expectedCaloriesRange: [Double]
    let expectedProteinRange: [Double]
    let expectedCarbsRange: [Double]
    let expectedFatRange: [Double]
    let expectedConfidence: String
    let expectedConfidenceMode: String?
    let expectedAssumptions: [String]
    let shouldRequireConfirmation: Bool
    let notes: String

    var caloriesRange: MacroRange { MacroRange(expectedCaloriesRange) }
    var proteinRange: MacroRange { MacroRange(expectedProteinRange) }
    var carbsRange: MacroRange { MacroRange(expectedCarbsRange) }
    var fatRange: MacroRange { MacroRange(expectedFatRange) }
}

struct MacroRange: Equatable {
    let min: Double
    let max: Double

    init(_ values: [Double]) {
        min = values.first ?? 0
        max = values.last ?? 0
    }

    func contains(_ value: Double) -> Bool {
        value >= min && value <= max
    }

    var midpoint: Double {
        (min + max) / 2
    }
}

struct SingaporeFixtureValidationResult: Equatable {
    let ok: Bool
    let errors: [String]
}

enum SingaporeFoodEstimationFixtureSupport {

    static func loadFixture() throws -> SingaporeFoodEstimationFixtureFile {
        let url = try fixtureURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SingaporeFoodEstimationFixtureFile.self, from: data)
    }

    static func midpoint(_ range: MacroRange) -> Double {
        range.midpoint
    }

    static func valueInRange(_ value: Double, range: MacroRange) -> Bool {
        range.contains(value)
    }

    static func componentKeywordsMatch(
        componentNames: [String],
        expectedKeywords: [String]
    ) -> Bool {
        let haystack = componentNames.joined(separator: " ").lowercased()
        return expectedKeywords.allSatisfy { haystack.contains($0.lowercased()) }
    }

    static func assumptionKeywordsMatch(
        assumptions: [String],
        expectedKeywords: [String]
    ) -> Bool {
        let haystack = assumptions.joined(separator: " ").lowercased()
        return expectedKeywords.allSatisfy { haystack.contains($0.lowercased()) }
    }

    static func confidenceMatches(
        actual: AIConfidence,
        expected: String,
        mode: String = "max"
    ) -> Bool {
        let rank: [AIConfidence: Int] = [.low: 0, .medium: 1, .high: 2]
        guard let actualRank = rank[actual] else { return false }

        let expectedConfidence: AIConfidence
        switch expected.lowercased() {
        case "low": expectedConfidence = .low
        case "medium": expectedConfidence = .medium
        default: expectedConfidence = .high
        }
        guard let expectedRank = rank[expectedConfidence] else { return false }

        if mode == "exact" {
            return actualRank == expectedRank
        }
        return actualRank <= expectedRank
    }

    static func buildReferenceMeal(from fixtureCase: SingaporeFoodEstimationCase) -> FoodLogDraft {
        let totalCalories = Int(midpoint(fixtureCase.caloriesRange).rounded())
        let totalProtein = midpoint(fixtureCase.proteinRange)
        let totalCarbs = midpoint(fixtureCase.carbsRange)
        let totalFat = midpoint(fixtureCase.fatRange)
        let count = max(fixtureCase.expectedComponents.count, 1)
        let share = 1.0 / Double(count)

        var components: [FoodComponent] = fixtureCase.expectedComponents.map { keyword in
            FoodComponent(
                name: keyword,
                quantity: 1,
                unit: "serving",
                calories: Int((Double(totalCalories) * share).rounded()),
                protein: (totalProtein * share * 10).rounded() / 10,
                carbs: (totalCarbs * share * 10).rounded() / 10,
                fat: (totalFat * share * 10).rounded() / 10,
                sourceText: "\(fixtureCase.inputText) — \(keyword)"
            )
        }

        if let lastIndex = components.indices.last, components.count > 1 {
            let priorCalories = components.prefix(lastIndex).reduce(0) { $0 + $1.calories }
            components[lastIndex].calories = max(0, totalCalories - priorCalories)
            components[lastIndex].protein = max(
                0,
                totalProtein - components.prefix(lastIndex).reduce(0) { $0 + $1.protein }
            )
            components[lastIndex].carbs = max(
                0,
                totalCarbs - components.prefix(lastIndex).reduce(0) { $0 + $1.carbs }
            )
            components[lastIndex].fat = max(
                0,
                totalFat - components.prefix(lastIndex).reduce(0) { $0 + $1.fat }
            )
        }

        let confidence: AIConfidence
        switch fixtureCase.expectedConfidence.lowercased() {
        case "low": confidence = .low
        case "medium": confidence = .medium
        default: confidence = .high
        }

        let assumptions = fixtureCase.expectedAssumptions.map {
            "Assumption (\($0)): QA reference estimate for \(fixtureCase.id)."
        }

        return FoodLogDraft(
            displayName: fixtureCase.inputText,
            components: components,
            confidence: confidence.asConfidenceLevel,
            source: .aiTextEstimate,
            warnings: [],
            assumptions: assumptions,
            caloriesRangeLower: Int(fixtureCase.caloriesRange.min.rounded()),
            caloriesRangeUpper: Int(fixtureCase.caloriesRange.max.rounded())
        )
    }

    static func validateMealAgainstFixture(
        _ meal: FoodLogDraft,
        fixtureCase: SingaporeFoodEstimationCase,
        requiresConfirmation: Bool = true
    ) -> SingaporeFixtureValidationResult {
        var errors: [String] = []

        if !componentKeywordsMatch(
            componentNames: meal.components.map(\.name),
            expectedKeywords: fixtureCase.expectedComponents
        ) {
            errors.append("Components do not cover expected keywords.")
        }

        if !valueInRange(Double(meal.totalCalories), range: fixtureCase.caloriesRange) {
            errors.append("Calories \(meal.totalCalories) outside expected range.")
        }
        if !valueInRange(meal.totalProtein, range: fixtureCase.proteinRange) {
            errors.append("Protein \(meal.totalProtein) outside expected range.")
        }
        if !valueInRange(meal.totalCarbs, range: fixtureCase.carbsRange) {
            errors.append("Carbs \(meal.totalCarbs) outside expected range.")
        }
        if !valueInRange(meal.totalFat, range: fixtureCase.fatRange) {
            errors.append("Fat \(meal.totalFat) outside expected range.")
        }

        if !confidenceMatches(
            actual: AIConfidence(rawValue: meal.confidence.rawValue) ?? .medium,
            expected: fixtureCase.expectedConfidence,
            mode: fixtureCase.expectedConfidenceMode ?? "max"
        ) {
            errors.append("Confidence does not match fixture expectation.")
        }

        if !assumptionKeywordsMatch(
            assumptions: meal.assumptions + meal.warnings,
            expectedKeywords: fixtureCase.expectedAssumptions
        ) {
            errors.append("Assumptions do not cover expected keywords.")
        }

        if let range = FoodCalorieRangeResolver.resolvedRange(for: meal),
           !valueInRange(Double(meal.totalCalories), range: fixtureCase.caloriesRange) {
            errors.append("Resolved calorie range does not align with fixture midpoint.")
        }

        if requiresConfirmation != fixtureCase.shouldRequireConfirmation {
            errors.append("shouldRequireConfirmation mismatch.")
        }

        return SingaporeFixtureValidationResult(ok: errors.isEmpty, errors: errors)
    }

    static func validateFixtureCaseShape(_ fixtureCase: SingaporeFoodEstimationCase) -> [String] {
        var errors: [String] = []
        if fixtureCase.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Missing id.")
        }
        if fixtureCase.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Missing inputText.")
        }
        if fixtureCase.expectedComponents.isEmpty {
            errors.append("expectedComponents must be non-empty.")
        }
        for range in [
            fixtureCase.caloriesRange,
            fixtureCase.proteinRange,
            fixtureCase.carbsRange,
            fixtureCase.fatRange,
        ] where range.min > range.max {
            errors.append("Invalid macro range.")
        }
        return errors
    }

    private static func fixtureURL() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            let candidate = url.appendingPathComponent("Docs/Coach/Fixtures/singapore_food_estimation_cases.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            url.deleteLastPathComponent()
        }
        throw NSError(
            domain: "SingaporeFoodEstimationFixtureSupport",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Fixture file not found."]
        )
    }
}
