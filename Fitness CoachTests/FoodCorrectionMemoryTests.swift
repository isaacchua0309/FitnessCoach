//
//  FoodCorrectionMemoryTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class FoodCorrectionMemoryTests: XCTestCase {

    func testPendingEditCreatesCorrectionMemory() async throws {
        let store = InMemoryFoodCorrectionMemoryStore()
        let before = FoodLogDraft(
            displayName: "Chicken rice",
            components: [
                FoodComponent(name: "Rice", calories: 260, protein: 5, carbs: 55, fat: 1, quantity: 1, unit: "bowl"),
                FoodComponent(name: "Chicken", calories: 280, protein: 35, carbs: 0, fat: 12, quantity: 1, unit: "serving")
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )
        var after = before
        after.components[0].quantity = 0.5
        after.components[0].unit = "bowl"
        after.components[0].calories = 130

        await FoodCorrectionMemoryRecorder.recordIfNeeded(
            before: before,
            after: after,
            source: .pendingEditSheet,
            store: store
        )

        let entries = try await store.recentEntries(limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.correctionType, .portionAdjustment)
        XCTAssertEqual(entries.first?.componentName, "Rice")
        XCTAssertEqual(entries.first?.source, .pendingEditSheet)
    }

    func testPostLogEditCreatesCorrectionMemory() async throws {
        let store = InMemoryFoodCorrectionMemoryStore()
        let now = Date()
        let before = FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: .lunch,
            name: "Chicken breast",
            quantity: 1,
            unit: "serving",
            calories: 220,
            protein: 35,
            carbs: 0,
            fat: 8,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: .medium,
            imageUrl: nil,
            notes: nil,
            components: nil,
            createdAt: now,
            updatedAt: now
        )
        var after = before
        after.quantity = 300
        after.unit = "g"
        after.calories = 330
        after.source = .corrected
        after.updatedAt = now.addingTimeInterval(1)

        await FoodCorrectionMemoryRecorder.recordPostLogEditIfNeeded(
            before: before,
            after: after,
            store: store
        )

        let entries = try await store.recentEntries(limit: 10)
        XCTAssertFalse(entries.isEmpty)
        XCTAssertTrue(entries.contains { $0.source == .postLogEdit })
        XCTAssertTrue(entries.contains { $0.correctionType == .portionAdjustment || $0.correctionType == .calorieOverride })
    }

    func testCorrectionMemoryAppearsInContextPacket() async {
        let store = InMemoryFoodCorrectionMemoryStore()
        await store.record(
            FoodCorrectionMemoryEntry(
                originalFoodName: "Chicken rice",
                correctionType: .portionAdjustment,
                correctionSummary: "User often uses half rice portion for chicken rice.",
                componentName: "Rice",
                amountHint: "half bowl",
                source: .pendingEditSheet
            )
        )

        let builder = CoachContextPacketV2Builder(
            foodCorrectionMemoryStore: store
        )
        let packet = await builder.makeContext(recentMessages: [], mode: .preview)

        XCTAssertEqual(packet.foodCorrectionMemory.count, 1)
        XCTAssertTrue(packet.foodCorrectionMemory.first?.patternSummary.contains("half rice portion") == true)
        XCTAssertTrue(
            packet.assumptions.contains {
                $0.key == CoachContextFoodCorrectionMemoryBuilder.hintsNotFactsAssumptionKey
            }
        )
    }

    func testMemoryIsCompactedAndLimited() async throws {
        let store = InMemoryFoodCorrectionMemoryStore()

        for index in 0..<60 {
            await store.record(
                FoodCorrectionMemoryEntry(
                    originalFoodName: "Food \(index)",
                    correctionType: .other,
                    correctionSummary: "Correction \(index)",
                    source: .pendingEditSheet
                )
            )
        }

        let stored = try await store.recentEntries(limit: 100)
        XCTAssertLessThanOrEqual(stored.count, FoodCorrectionMemoryLimits.maxStoredEntries)

        let contextEntries = CoachContextFoodCorrectionMemoryBuilder.makeContextEntries(from: stored)
        XCTAssertLessThanOrEqual(contextEntries.count, FoodCorrectionMemoryLimits.maxContextEntries)
    }

    func testRepeatedCorrectionIncrementsUseCount() async throws {
        let store = InMemoryFoodCorrectionMemoryStore()
        let before = FoodLogDraft(
            displayName: "Pad thai",
            components: [FoodComponent(name: "Pad thai", calories: 600, protein: 20, carbs: 70, fat: 18)],
            confidence: .medium,
            source: .aiTextEstimate
        )
        var after = before
        after.components[0].calories = 520

        await FoodCorrectionMemoryRecorder.recordIfNeeded(
            before: before,
            after: after,
            source: .naturalLanguageCorrection,
            store: store
        )
        await FoodCorrectionMemoryRecorder.recordIfNeeded(
            before: before,
            after: after,
            source: .naturalLanguageCorrection,
            store: store
        )

        let entries = try await store.recentEntries(limit: 5)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.useCount, 2)
    }

    func testCorrectionMemoryDoesNotOverrideExactUserGrams() {
        let meal = FoodLogDraft(
            displayName: "Chicken breast",
            components: [
                FoodComponent(
                    name: "Chicken breast",
                    quantity: 300,
                    unit: "g",
                    calories: 330,
                    protein: 62,
                    carbs: 0,
                    fat: 7
                )
            ],
            confidence: .high,
            source: .manual
        )

        let corrections = [
            CoachFoodCorrectionContext(
                patternSummary: "User corrected chicken breast portions to 200g recently.",
                foodKey: "chicken breast",
                correctionType: FoodCorrectionType.portionAdjustment.rawValue,
                componentName: "Chicken breast",
                amountHint: "300g"
            )
        ]

        let application = FoodCorrectionMemoryApplier.apply(
            to: meal,
            corrections: corrections,
            prompt: "chicken breast 300g"
        )

        XCTAssertEqual(application.mealDraft.components.first?.quantity, 300)
        XCTAssertEqual(application.mealDraft.components.first?.unit, "g")
        XCTAssertTrue(application.mealDraft.assumptions.contains(where: { $0.contains("Correction hint:") }))
    }

    func testCorrectionMemoryDoesNotLeakAcrossUsers() async throws {
        var activeUser = "user-a"
        let store = FileFoodCorrectionMemoryStore(userIdProvider: { activeUser })

        await store.record(
            FoodCorrectionMemoryEntry(
                originalFoodName: "Chicken rice",
                correctionType: .portionAdjustment,
                correctionSummary: "User often uses half rice portion for chicken rice.",
                source: .pendingEditSheet
            )
        )

        activeUser = "user-b"
        let userBEntries = try await store.recentEntries(limit: 10)
        XCTAssertTrue(userBEntries.isEmpty)

        activeUser = "user-a"
        let userAEntries = try await store.recentEntries(limit: 10)
        XCTAssertEqual(userAEntries.count, 1)

        _ = FileFoodCorrectionMemoryStore.deleteFile(for: "user-a")
        _ = FileFoodCorrectionMemoryStore.deleteFile(for: "user-b")
    }

    func testSauceAdditionCreatesSauceOrOilCorrection() async throws {
        let store = InMemoryFoodCorrectionMemoryStore()
        let before = FoodLogDraft(
            displayName: "Chicken rice",
            components: [FoodComponent(name: "Chicken rice", calories: 600, protein: 30, carbs: 70, fat: 15)],
            confidence: .medium,
            source: .aiPhotoEstimate
        )
        var after = before
        after.components.append(
            FoodComponent(name: "Chili sauce", calories: 40, protein: 0, carbs: 8, fat: 1)
        )

        await FoodCorrectionMemoryRecorder.recordIfNeeded(
            before: before,
            after: after,
            source: .pendingEditSheet,
            store: store
        )

        let entries = try await store.recentEntries(limit: 5)
        XCTAssertTrue(entries.contains { $0.correctionType == .sauceOrOilAdjustment || $0.correctionType == .componentAdded })
        XCTAssertTrue(entries.contains { $0.componentName == "Chili sauce" })
    }

    func testIdenticalDraftsDoNotCreateMemory() async throws {
        let store = InMemoryFoodCorrectionMemoryStore()
        let draft = FoodLogDraft(
            displayName: "Salad",
            components: [FoodComponent(name: "Salad", calories: 250, protein: 10, carbs: 20, fat: 12)],
            confidence: .medium,
            source: .aiTextEstimate
        )

        await FoodCorrectionMemoryRecorder.recordIfNeeded(
            before: draft,
            after: draft,
            source: .pendingEditSheet,
            store: store
        )

        let entries = try await store.recentEntries(limit: 5)
        XCTAssertTrue(entries.isEmpty)
    }
}
