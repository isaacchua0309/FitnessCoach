//
//  CoachAccuracyBenchmarkSupport.swift
//  Fitness CoachTests
//
//  Coach Accuracy Benchmark Harness v1 — iOS scoring and fixture loading.
//

import Foundation
@testable import Fitness_Coach

enum CoachAccuracyBenchmarkCategory: String, Decodable, CaseIterable {
    case singaporeHawker = "singapore_hawker"
    case mealPrep = "meal_prep"
    case drinks
    case desserts
    case photoScenario = "photo_scenario"
    case correctionFlow = "correction_flow"
}

enum CoachAccuracyBenchmarkRoute: String, Decodable {
    case estimateFood = "estimate_food"
    case logFood = "log_food"
    case clarify
    case photoAnalysis = "photo_analysis"
}

struct CoachAccuracyConfidenceBand: Decodable, Equatable {
    let min: String
    let max: String
}

struct CoachAccuracyBenchmarkCase: Decodable, Equatable {
    let id: String
    let category: String
    let prompt: String
    let expectedRoute: String
    let shouldLogAutomatically: Bool
    let shouldRequireConfirmation: Bool
    let shouldAskClarification: Bool?
    let allowLowConfidencePending: Bool?
    let expectedConfidenceBand: CoachAccuracyConfidenceBand
    let expectedCaloriesRange: [Double]?
    let expectedProteinRange: [Double]?
    let expectedCarbsRange: [Double]?
    let expectedFatRange: [Double]?
    let requiredUncertaintyKeywords: [String]
    let requiredAssumptionKeywords: [String]
    let expectedComponents: [String]
    let baselinePrompt: String?
    let singaporeFixtureId: String?
    let notes: String

    var caloriesRange: MacroRange? {
        expectedCaloriesRange.map { MacroRange($0) }
    }
}

struct CoachAccuracyBenchmarkFixtureFile: Decodable {
    let version: Int
    let description: String
    let caseCount: Int
    let categories: [String]
    let cases: [CoachAccuracyBenchmarkCase]
}

enum CoachAccuracyBenchmarkFailureKind: String, Equatable {
    case route
    case range
    case missingAssumption = "missing_assumption"
    case missingUncertainty = "missing_uncertainty"
    case overconfidence
    case clarification
    case confirmation
    case schema
    case component
}

struct CoachAccuracyBenchmarkFailure: Equatable {
    let kind: CoachAccuracyBenchmarkFailureKind
    let message: String
}

struct CoachAccuracyBenchmarkCaseResult: Equatable {
    let id: String
    let category: String
    let passed: Bool
    let failures: [CoachAccuracyBenchmarkFailure]
}

struct CoachAccuracyBenchmarkRunSummary: Equatable {
    let totalCases: Int
    let passedCases: Int
    let failedCases: Int
    let routeFailures: Int
    let rangeFailures: Int
    let missingAssumptionFailures: Int
    let missingUncertaintyFailures: Int
    let overconfidenceFailures: Int
    let clarificationFailures: Int
    let confirmationFailures: Int
    let schemaFailures: Int
    let componentFailures: Int
    let results: [CoachAccuracyBenchmarkCaseResult]
}

enum CoachAccuracyBenchmarkSupport {

    static func loadFixture() throws -> CoachAccuracyBenchmarkFixtureFile {
        let url = try fixtureURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CoachAccuracyBenchmarkFixtureFile.self, from: data)
    }

    static func validateCaseShape(_ benchmarkCase: CoachAccuracyBenchmarkCase) -> [String] {
        var errors: [String] = []
        if benchmarkCase.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Missing id.")
        }
        if benchmarkCase.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Missing prompt.")
        }
        if benchmarkCase.expectedComponents.isEmpty {
            errors.append("expectedComponents must be non-empty.")
        }
        if benchmarkCase.shouldLogAutomatically {
            errors.append("Benchmark v1 expects shouldLogAutomatically=false.")
        }
        if !benchmarkCase.shouldRequireConfirmation {
            errors.append("Benchmark v1 expects shouldRequireConfirmation=true.")
        }
        if benchmarkCase.category == CoachAccuracyBenchmarkCategory.correctionFlow.rawValue,
           benchmarkCase.baselinePrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            errors.append("correction_flow cases require baselinePrompt.")
        }
        return errors
    }

    static func buildReferenceMeal(from benchmarkCase: CoachAccuracyBenchmarkCase) -> FoodLogDraft {
        if let singaporeId = benchmarkCase.singaporeFixtureId {
            let sgFixture = try? SingaporeFoodEstimationFixtureSupport.loadFixture()
            if let linked = sgFixture?.cases.first(where: { $0.id == singaporeId }) {
                return SingaporeFoodEstimationFixtureSupport.buildReferenceMeal(from: linked)
            }
        }

        let calories = Int((benchmarkCase.caloriesRange?.midpoint ?? 500).rounded())
        let protein = benchmarkCase.expectedProteinRange.map { MacroRange($0).midpoint } ?? 20
        let carbs = benchmarkCase.expectedCarbsRange.map { MacroRange($0).midpoint } ?? 40
        let fat = benchmarkCase.expectedFatRange.map { MacroRange($0).midpoint } ?? 10
        let count = max(benchmarkCase.expectedComponents.count, 1)

        let components = benchmarkCase.expectedComponents.enumerated().map { index, keyword in
            FoodComponent(
                name: keyword,
                quantity: 1,
                unit: "serving",
                calories: max(1, calories / count + (index == 0 ? calories % count : 0)),
                protein: protein / Double(count),
                carbs: carbs / Double(count),
                fat: fat / Double(count),
                confidence: .medium,
                sourceText: benchmarkCase.prompt
            )
        }

        return FoodLogDraft(
            displayName: benchmarkCase.prompt,
            components: components,
            confidence: .medium,
            source: .aiTextEstimate
        )
    }

    static func scoreCase(
        _ benchmarkCase: CoachAccuracyBenchmarkCase,
        meal: FoodLogDraft,
        requiresConfirmation: Bool = true,
        assistantMessage: String? = nil
    ) -> CoachAccuracyBenchmarkCaseResult {
        var failures: [CoachAccuracyBenchmarkFailure] = []

        let haystack = [
            meal.displayName,
            meal.components.map(\.name).joined(separator: " "),
            (meal.notes ?? "")
        ].joined(separator: " ").lowercased()

        if !benchmarkCase.expectedComponents.allSatisfy({ haystack.contains($0.lowercased()) }) {
            failures.append(.init(
                kind: .component,
                message: "Components do not cover expected keywords."
            ))
        }

        if let range = benchmarkCase.caloriesRange,
           !range.contains(Double(meal.totalCalories)) {
            failures.append(.init(
                kind: .range,
                message: "Calories \(meal.totalCalories) outside benchmark range."
            ))
        }

        let assumptionHaystack = (assistantMessage ?? "") + " " + (meal.notes ?? "")
        if !benchmarkCase.requiredAssumptionKeywords.allSatisfy({
            assumptionHaystack.lowercased().contains($0.lowercased())
        }) {
            failures.append(.init(kind: .missingAssumption, message: "Missing assumption keywords."))
        }

        if !benchmarkCase.requiredUncertaintyKeywords.allSatisfy({
            assumptionHaystack.lowercased().contains($0.lowercased())
        }) {
            failures.append(.init(kind: .missingUncertainty, message: "Missing uncertainty keywords."))
        }

        if !SingaporeFoodEstimationFixtureSupport.confidenceMatches(
            actual: mapConfidence(meal.confidence),
            expected: benchmarkCase.expectedConfidenceBand.max,
            mode: "max"
        ) {
            failures.append(.init(kind: .overconfidence, message: "Confidence exceeds benchmark band."))
        }

        if requiresConfirmation != benchmarkCase.shouldRequireConfirmation {
            failures.append(.init(kind: .confirmation, message: "Confirmation requirement mismatch."))
        }

        let hasClarification = assistantMessage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        if benchmarkCase.shouldAskClarification == true && !hasClarification {
            failures.append(.init(kind: .clarification, message: "Expected clarifying copy."))
        }

        return CoachAccuracyBenchmarkCaseResult(
            id: benchmarkCase.id,
            category: benchmarkCase.category,
            passed: failures.isEmpty,
            failures: failures
        )
    }

    static func runDeterministicBenchmark(
        fixture: CoachAccuracyBenchmarkFixtureFile
    ) -> CoachAccuracyBenchmarkRunSummary {
        let results = fixture.cases.map { benchmarkCase -> CoachAccuracyBenchmarkCaseResult in
            let meal = buildReferenceMeal(from: benchmarkCase)
            var notes = benchmarkCase.requiredAssumptionKeywords
                .map { "Assumption (\($0)): benchmark reference." }
                .joined(separator: " ")
            notes += " " + benchmarkCase.requiredUncertaintyKeywords
                .map { "Uncertainty (\($0)): estimate may vary." }
                .joined(separator: " ")
            if benchmarkCase.category == CoachAccuracyBenchmarkCategory.correctionFlow.rawValue,
               let baseline = benchmarkCase.baselinePrompt {
                notes += " Correction after baseline: \(baseline)."
            }

            var draft = meal
            draft.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

            let assistantMessage = benchmarkCase.category == CoachAccuracyBenchmarkCategory.correctionFlow.rawValue
                ? "Updated estimate based on: \(benchmarkCase.prompt)"
                : nil

            return scoreCase(
                benchmarkCase,
                meal: draft,
                requiresConfirmation: benchmarkCase.shouldRequireConfirmation,
                assistantMessage: assistantMessage
            )
        }

        return summarize(results)
    }

    static func summarize(_ results: [CoachAccuracyBenchmarkCaseResult]) -> CoachAccuracyBenchmarkRunSummary {
        func count(_ kind: CoachAccuracyBenchmarkFailureKind) -> Int {
            results.reduce(0) { partial, result in
                partial + result.failures.filter { $0.kind == kind }.count
            }
        }

        let passed = results.filter(\.passed).count
        return CoachAccuracyBenchmarkRunSummary(
            totalCases: results.count,
            passedCases: passed,
            failedCases: results.count - passed,
            routeFailures: count(.route),
            rangeFailures: count(.range),
            missingAssumptionFailures: count(.missingAssumption),
            missingUncertaintyFailures: count(.missingUncertainty),
            overconfidenceFailures: count(.overconfidence),
            clarificationFailures: count(.clarification),
            confirmationFailures: count(.confirmation),
            schemaFailures: count(.schema),
            componentFailures: count(.component),
            results: results
        )
    }

    static func isLiveBenchmarkEnabled() -> Bool {
        ProcessInfo.processInfo.environment["RUN_LIVE_FOOD_BENCHMARK"] == "1"
    }

    private static func mapConfidence(_ confidence: ConfidenceLevel) -> AIConfidence {
        switch confidence {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }

    private static func fixtureURL() throws -> URL {
        let relative = "Docs/Coach/Fixtures/coach_accuracy_benchmark_v1_cases.json"
        let candidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relative),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(relative)
        ]
        if let match = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return match
        }
        throw NSError(
            domain: "CoachAccuracyBenchmarkSupport",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing benchmark fixture at \(relative)"]
        )
    }
}
