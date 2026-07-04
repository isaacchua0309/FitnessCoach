//
//  CoachIntentRegressionFixtureSupport.swift
//  Fitness CoachTests
//

import Foundation
@testable import Fitness_Coach

struct CoachIntentRegressionFixtureDocument: Codable, Sendable {
    var schemaVersion: Int
    var description: String
    var minimumCaseCount: Int
    var categories: [String]
    var categoryCounts: [String: Int]
    var caseCount: Int
    var cases: [CoachIntentRegressionFixtureCase]
}

struct CoachIntentRegressionFixtureCase: Codable, Sendable, Identifiable {
    var id: String
    var category: String
    var input: String
    var expectedIntent: String
    var shouldCreateMutation: Bool
    var shouldRequireConfirmation: Bool
    var notes: String
    var edgeReason: String
    var verificationLayers: [String]
    var misclassifiedIntent: String?
    var classifierConfidence: Double?
    var expectedRouteHandler: String?
    var forbiddenRouteHandlers: [String]?
}

enum CoachIntentRegressionFixtureLoader {

    static func load() throws -> CoachIntentRegressionFixtureDocument {
        let url = try fixtureURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CoachIntentRegressionFixtureDocument.self, from: data)
    }

    static func fixtureURL() throws -> URL {
        let candidates = [
            workspaceFixtureURL(),
            Bundle(for: BundleMarker.self).url(
                forResource: "coach_intent_regression_cases",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        ].compactMap { $0 }

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        throw NSError(
            domain: "CoachIntentRegressionFixtureLoader",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing coach_intent_regression_cases.json"]
        )
    }

    private static func workspaceFixtureURL() -> URL? {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Docs/Coach/Fixtures/coach_intent_regression_cases.json")
    }
}

enum CoachIntentRegressionFixtureMapping {

    static func coachIntent(from raw: String) -> CoachIntent? {
        CoachIntent(rawValue: raw)
    }

    static func stubResult(
        for fixtureCase: CoachIntentRegressionFixtureCase,
        intent: CoachIntent
    ) -> CoachIntentResult {
        CoachIntentResult(
            intent: intent,
            confidence: fixtureCase.classifierConfidence ?? 0.92,
            domain: .nutrition,
            requiresAppMutation: intent == .logFood || intent == .logWorkout || intent == .editLog || intent == .deleteLog,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false,
            action: intent == .logFood ? .logFood(FoodDraft(
                mealType: nil,
                name: "fixture food",
                quantity: 1,
                unit: "serving",
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .medium,
                imageUrl: nil,
                notes: nil
            )) : nil
        )
    }

    static func misclassifiedRawIntent(for fixtureCase: CoachIntentRegressionFixtureCase) -> String {
        fixtureCase.misclassifiedIntent ?? "log_food"
    }
}

private final class BundleMarker: NSObject {}
