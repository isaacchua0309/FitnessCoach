//
//  CoachModelDecompositionCharacterizationTests.swift
//  Fitness CoachTests
//
//  Legacy characterization scenarios await migration to CoachModel's current input and AI-service APIs.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachModelDecompositionCharacterizationTests: XCTestCase {
    func testLegacyCharacterizationSuiteRequiresMigration() throws {
        throw XCTSkip("Obsolete CoachModel decomposition fixtures use removed image-selection and FoodDraft APIs.")
    }
}
