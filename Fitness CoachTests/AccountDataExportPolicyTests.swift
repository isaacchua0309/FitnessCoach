//
//  AccountDataExportPolicyTests.swift
//  Fitness CoachTests
//
//  Forma — Account data export policy tests.
//

import XCTest
@testable import Fitness_Coach

final class AccountDataExportPolicyTests: XCTestCase {

    func testExportDisabledByDefault() {
        XCTAssertFalse(AccountDataExportPolicy.accountDataExportEnabled)
        XCTAssertFalse(AccountDataExportPolicy.isEnabled)
    }

    func testMayExportDataRequiresMatchingSessionUID() {
        XCTAssertTrue(AccountDataExportPolicy.mayExportData(for: "user-a", sessionUID: "user-a"))
        XCTAssertFalse(AccountDataExportPolicy.mayExportData(for: "user-a", sessionUID: "user-b"))
        XCTAssertFalse(AccountDataExportPolicy.mayExportData(for: "user-a", sessionUID: nil))
    }

    func testExportedFoodEntryModelExcludesImageURLField() {
        let encoded = try? JSONEncoder().encode(
            ExportedFoodEntry(
                id: UUID(),
                dailyLogId: UUID(),
                mealType: MealType.lunch.rawValue,
                name: "Salad",
                quantity: 1,
                unit: "bowl",
                calories: 320,
                protein: 12,
                carbs: 20,
                fat: 18,
                fiber: nil,
                sodium: nil,
                source: FoodEntrySource.manual.rawValue,
                confidence: ConfidenceLevel.high.rawValue,
                notes: nil,
                components: nil,
                createdAt: Date(),
                updatedAt: Date(),
                syncStatus: AccountDataSyncStatus.localOnly.rawValue,
                lastSyncedAt: nil
            )
        )
        let json = String(data: encoded ?? Data(), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("imageUrl"))
    }
}
