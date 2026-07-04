//
//  CoachEntryReferenceResolverTests.swift
//  Fitness CoachTests
//
//  Edit/delete food reference resolution using timeline and linkedEntryId.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachEntryReferenceResolverTests: XCTestCase {

    private let baseDate = Date(timeIntervalSince1970: 1_720_108_800) // 2024-07-04

    // MARK: - Delete scenarios

    func testDeleteLastMealUsesMostRecentConfirmedFoodLogged() {
        let older = UUID()
        let newest = UUID()
        let context = makeContext(
            meals: [
                meal(name: "Oatmeal", entryId: older, mealType: .breakfast, offsetMinutes: 120),
                meal(name: "Chicken rice", entryId: newest, mealType: .lunch, offsetMinutes: 10)
            ],
            events: [
                foodLoggedEvent(entryId: older, name: "Oatmeal", mealType: .breakfast, offsetMinutes: 120),
                foodLoggedEvent(entryId: newest, name: "Chicken rice", mealType: .lunch, offsetMinutes: 10)
            ]
        )

        let action = AICommandAction(type: .deleteEntry, targetEntrySelector: "delete that")
        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)

        assertTarget(resolution, entryId: newest, confidence: .medium)
    }

    func testDeleteLunchTargetsUniqueLunchEntry() {
        let breakfastId = UUID()
        let lunchId = UUID()
        let context = makeContext(
            meals: [
                meal(name: "Oatmeal", entryId: breakfastId, mealType: .breakfast),
                meal(name: "Chicken rice", entryId: lunchId, mealType: .lunch)
            ],
            events: [
                foodLoggedEvent(entryId: breakfastId, name: "Oatmeal", mealType: .breakfast, offsetMinutes: 60),
                foodLoggedEvent(entryId: lunchId, name: "Chicken rice", mealType: .lunch, offsetMinutes: 5)
            ]
        )

        let action = AICommandAction(
            type: .deleteEntry,
            foodDraft: FoodDraft(
                mealType: .lunch,
                name: "lunch",
                quantity: nil,
                unit: nil,
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .high,
                imageUrl: nil,
                notes: nil
            ),
            targetEntrySelector: "remove lunch"
        )

        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)
        assertTarget(resolution, entryId: lunchId, confidence: .medium)
    }

    func testDeleteChickenRiceWhenOneExists() {
        let entryId = UUID()
        let context = makeContext(
            meals: [meal(name: "Chicken rice", entryId: entryId, mealType: .lunch)],
            events: [foodLoggedEvent(entryId: entryId, name: "Chicken rice", mealType: .lunch)]
        )

        let action = AICommandAction(type: .deleteEntry, targetEntrySelector: "delete chicken rice")
        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)

        assertTarget(resolution, entryId: entryId, confidence: .medium)
    }

    func testDeleteChickenRiceWhenTwoExistAsksClarification() {
        let first = UUID()
        let second = UUID()
        let context = makeContext(
            meals: [
                meal(name: "Chicken rice", entryId: first, mealType: .lunch, offsetMinutes: 30),
                meal(name: "Chicken rice", entryId: second, mealType: .dinner, offsetMinutes: 5)
            ],
            events: [
                foodLoggedEvent(entryId: first, name: "Chicken rice", mealType: .lunch, offsetMinutes: 30),
                foodLoggedEvent(entryId: second, name: "Chicken rice", mealType: .dinner, offsetMinutes: 5)
            ]
        )

        let action = AICommandAction(type: .deleteEntry, targetEntrySelector: "delete chicken rice")
        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)

        assertClarify(resolution)
    }

    // MARK: - Edit scenarios

    func testEditMostRecentMeal() {
        let entryId = UUID()
        let context = makeContext(
            meals: [meal(name: "Greek yogurt", entryId: entryId, mealType: .breakfast)],
            events: [foodLoggedEvent(entryId: entryId, name: "Greek yogurt", mealType: .breakfast)]
        )

        let action = AICommandAction(
            type: .editEntry,
            foodDraft: editDraft(calories: 220),
            targetEntrySelector: "change that to 220 calories"
        )
        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)

        assertTarget(resolution, entryId: entryId, confidence: .medium)
    }

    func testEditRejectedEstimateIsBlocked() {
        let rejectedEstimateId = UUID()
        let context = makeContext(
            meals: [],
            events: [
                rejectedEstimateEvent(entryId: rejectedEstimateId, name: "Pizza slice")
            ]
        )

        let action = AICommandAction(
            type: .editEntry,
            foodDraft: editDraft(calories: 600),
            linkedEntryId: rejectedEstimateId
        )
        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)

        assertBlocked(resolution)
    }

    func testEditPendingEstimateUpdatesPendingDraft() {
        let pending = CoachPendingConfirmation.food(
            AIFoodConfirmationDraft(
                originalText: "log chicken rice",
                assistantMessage: nil,
                mealDraft: CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft,
                confidence: .medium,
                requiresConfirmation: true
            )
        )

        let action = AICommandAction(
            type: .editEntry,
            foodDraft: editDraft(calories: 600),
            targetEntrySelector: "change chicken rice to 600 calories"
        )
        let context = makeContext(meals: [], events: [])

        let resolution = CoachEntryReferenceResolver.resolve(
            action: action,
            context: context,
            pendingConfirmation: pending
        )

        guard case .target(_, _, .high, let pendingDraft) = resolution.outcome else {
            return XCTFail("Expected high-confidence pending draft update")
        }
        XCTAssertNotNil(pendingDraft)
        XCTAssertEqual(pendingDraft?.primaryMealDraft.totalCalories, 600)
    }

    // MARK: - Priority & exclusions

    func testLinkedEntryIdFromBackendWins() {
        let backendId = UUID()
        let recentId = UUID()
        let context = makeContext(
            meals: [
                meal(name: "Recent meal", entryId: recentId, mealType: .dinner, offsetMinutes: 1),
                meal(name: "Backend meal", entryId: backendId, mealType: .lunch, offsetMinutes: 60)
            ],
            events: [
                foodLoggedEvent(entryId: recentId, name: "Recent meal", mealType: .dinner, offsetMinutes: 1),
                foodLoggedEvent(entryId: backendId, name: "Backend meal", mealType: .lunch, offsetMinutes: 60)
            ]
        )

        let action = AICommandAction(
            type: .deleteEntry,
            targetEntrySelector: "delete that",
            linkedEntryId: backendId
        )
        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)

        assertTarget(resolution, entryId: backendId, confidence: .high)
    }

    func testAmbiguousTargetAsksClarification() {
        let first = UUID()
        let second = UUID()
        let context = makeContext(
            meals: [
                meal(name: "Salad", entryId: first, mealType: .lunch, offsetMinutes: 20),
                meal(name: "Salad", entryId: second, mealType: .lunch, offsetMinutes: 10)
            ],
            events: [
                foodLoggedEvent(entryId: first, name: "Salad", mealType: .lunch, offsetMinutes: 20),
                foodLoggedEvent(entryId: second, name: "Salad", mealType: .lunch, offsetMinutes: 10)
            ]
        )

        let action = AICommandAction(type: .deleteEntry, targetEntrySelector: "delete salad")
        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)

        assertClarify(resolution)
    }

    func testDeletedEventNotTargetedAgain() {
        let deletedEntryId = UUID()
        let activeEntryId = UUID()
        let context = makeContext(
            meals: [meal(name: "Active meal", entryId: activeEntryId, mealType: .snack)],
            events: [
                foodDeletedEvent(entryId: deletedEntryId, name: "Removed meal", offsetMinutes: 30),
                foodLoggedEvent(entryId: activeEntryId, name: "Active meal", mealType: .snack, offsetMinutes: 5)
            ]
        )

        let action = AICommandAction(
            type: .deleteEntry,
            linkedEntryId: deletedEntryId
        )
        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)

        assertBlocked(resolution)
    }

    func testDeletePendingEstimateIsBlocked() {
        let pending = CoachPendingConfirmation.food(
            AIFoodConfirmationDraft(
                originalText: "log chicken rice",
                assistantMessage: nil,
                mealDraft: CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft,
                confidence: .medium,
                requiresConfirmation: true
            )
        )

        let action = AICommandAction(type: .deleteEntry, targetEntrySelector: "delete that")
        let context = makeContext(meals: [], events: [])

        let resolution = CoachEntryReferenceResolver.resolve(
            action: action,
            context: context,
            pendingConfirmation: pending
        )

        assertBlocked(resolution)
    }

    // MARK: - Helpers

    private func makeContext(
        meals: [CoachRecentMealContext],
        events: [CoachTimelineContextEvent]
    ) -> CoachContextPacketV2 {
        CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: baseDate),
            timeline: CoachContextTimelinePacket(recentEvents: events),
            recentMealsStructured: meals
        )
    }

    private func meal(
        name: String,
        entryId: UUID,
        mealType: MealType,
        offsetMinutes: Int = 0
    ) -> CoachRecentMealContext {
        CoachRecentMealContext(
            name: name,
            mealType: mealType.rawValue,
            calories: 500,
            loggedAt: baseDate.addingTimeInterval(TimeInterval(offsetMinutes * 60)),
            linkedEntryId: entryId
        )
    }

    private func foodLoggedEvent(
        entryId: UUID,
        name: String,
        mealType: MealType,
        offsetMinutes: Int = 0
    ) -> CoachTimelineContextEvent {
        CoachTimelineContextEvent(
            id: UUID(),
            timestamp: baseDate.addingTimeInterval(TimeInterval(offsetMinutes * 60)),
            type: CoachTimelineEventType.foodLogged.rawValue,
            source: CoachTimelineEventSourceAttribution.userConfirmation.rawValue,
            status: CoachTimelineEventStatus.confirmed.rawValue,
            summary: name,
            compactPayload: [
                "name": name,
                "kcal": "500",
                "mealType": mealType.rawValue
            ],
            linkedEntryId: entryId
        )
    }

    private func foodDeletedEvent(
        entryId: UUID,
        name: String,
        offsetMinutes: Int = 0
    ) -> CoachTimelineContextEvent {
        CoachTimelineContextEvent(
            id: UUID(),
            timestamp: baseDate.addingTimeInterval(TimeInterval(offsetMinutes * 60)),
            type: CoachTimelineEventType.foodDeleted.rawValue,
            source: CoachTimelineEventSourceAttribution.userConfirmation.rawValue,
            status: CoachTimelineEventStatus.confirmed.rawValue,
            summary: "Deleted \(name)",
            compactPayload: ["name": name],
            linkedEntryId: entryId
        )
    }

    private func rejectedEstimateEvent(entryId: UUID, name: String) -> CoachTimelineContextEvent {
        CoachTimelineContextEvent(
            id: UUID(),
            timestamp: baseDate,
            type: CoachTimelineEventType.foodRejected.rawValue,
            source: CoachTimelineEventSourceAttribution.estimateFood.rawValue,
            status: CoachTimelineEventStatus.rejected.rawValue,
            summary: name,
            compactPayload: ["meal": name],
            linkedEntryId: entryId
        )
    }

    private func editDraft(calories: Int) -> FoodDraft {
        FoodDraft(
            mealType: .lunch,
            name: "chicken rice",
            quantity: 1,
            unit: "serving",
            calories: calories,
            protein: 30,
            carbs: 70,
            fat: 10,
            fiber: nil,
            sodium: nil,
            source: .corrected,
            confidence: .high,
            imageUrl: nil,
            notes: nil
        )
    }

    private func assertTarget(
        _ resolution: CoachEntryReferenceResolution,
        entryId: UUID,
        confidence: CoachEntryReferenceConfidence,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .target(let linkedEntryId, _, let resolvedConfidence, _) = resolution.outcome else {
            XCTFail("Expected target resolution, got \(resolution.outcome)", file: file, line: line)
            return
        }
        XCTAssertEqual(linkedEntryId, entryId, file: file, line: line)
        XCTAssertEqual(resolvedConfidence, confidence, file: file, line: line)
    }

    private func assertClarify(
        _ resolution: CoachEntryReferenceResolution,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .clarify = resolution.outcome else {
            XCTFail("Expected clarification, got \(resolution.outcome)", file: file, line: line)
        }
    }

    private func assertBlocked(
        _ resolution: CoachEntryReferenceResolution,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .blocked = resolution.outcome else {
            XCTFail("Expected blocked resolution, got \(resolution.outcome)", file: file, line: line)
        }
    }
}
