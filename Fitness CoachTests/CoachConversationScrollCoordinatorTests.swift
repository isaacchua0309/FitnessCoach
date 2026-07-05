//
//  CoachConversationScrollCoordinatorTests.swift
//  Fitness CoachTests
//
//  Auto-scroll policy for the Coach transcript.
//

import XCTest
@testable import Fitness_Coach

final class CoachConversationScrollCoordinatorTests: XCTestCase {

    func testAlwaysScrollsForUserMessageAndPendingAppearance() {
        XCTAssertTrue(
            CoachConversationScrollCoordinator.shouldAutoScroll(
                reason: .userMessageSent,
                isNearBottom: false
            )
        )
        XCTAssertTrue(
            CoachConversationScrollCoordinator.shouldAutoScroll(
                reason: .pendingCardAppeared,
                isNearBottom: false
            )
        )
    }

    func testNearBottomRequiredForAssistantAndAccessoryChanges() {
        XCTAssertFalse(
            CoachConversationScrollCoordinator.shouldAutoScroll(
                reason: .assistantResponseArrived,
                isNearBottom: false
            )
        )
        XCTAssertTrue(
            CoachConversationScrollCoordinator.shouldAutoScroll(
                reason: .assistantResponseArrived,
                isNearBottom: true
            )
        )
        XCTAssertTrue(
            CoachConversationScrollCoordinator.shouldAutoScroll(
                reason: .inputFocused,
                isNearBottom: true
            )
        )
        XCTAssertFalse(
            CoachConversationScrollCoordinator.shouldAutoScroll(
                reason: .pendingCardDismissed,
                isNearBottom: false
            )
        )
    }

    func testMessageCountReasonUsesLastRole() {
        XCTAssertEqual(
            CoachConversationScrollCoordinator.reasonForMessageCountChange(
                previousCount: 2,
                newCount: 3,
                lastMessageRole: .user
            ),
            .userMessageSent
        )
        XCTAssertEqual(
            CoachConversationScrollCoordinator.reasonForMessageCountChange(
                previousCount: 2,
                newCount: 3,
                lastMessageRole: .assistant
            ),
            .assistantResponseArrived
        )
        XCTAssertNil(
            CoachConversationScrollCoordinator.reasonForMessageCountChange(
                previousCount: 3,
                newCount: 3,
                lastMessageRole: .assistant
            )
        )
    }

    func testPendingConfirmationReasons() {
        let pending = CoachPendingConfirmation.food(CoachMutationTestFixtures.chickenConfirmationDraft)

        XCTAssertEqual(
            CoachConversationScrollCoordinator.reasonForPendingConfirmationChange(
                previous: nil,
                current: pending
            ),
            .pendingCardAppeared
        )
        XCTAssertEqual(
            CoachConversationScrollCoordinator.reasonForPendingConfirmationChange(
                previous: pending,
                current: nil
            ),
            .pendingCardDismissed
        )
        XCTAssertNil(
            CoachConversationScrollCoordinator.reasonForPendingConfirmationChange(
                previous: pending,
                current: pending
            )
        )
    }

    func testNearBottomDistanceThreshold() {
        XCTAssertTrue(
            CoachConversationScrollCoordinator.isNearBottom(distanceFromBottom: 40)
        )
        XCTAssertFalse(
            CoachConversationScrollCoordinator.isNearBottom(distanceFromBottom: 200)
        )
        XCTAssertEqual(
            CoachConversationScrollCoordinator.distanceFromBottom(
                contentSizeHeight: 1_000,
                contentOffsetY: 800,
                containerHeight: 150
            ),
            50,
            accuracy: 0.001
        )
    }

    func testStructuredAssistantInsertUsesLayoutDelay() {
        let payload = DailyReviewPayload(
            title: "Daily Review",
            timezoneLabel: nil,
            generatedAt: Date(),
            snapshot: DailyReviewSnapshot(
                calories: ProgressMetric(
                    label: "Calories",
                    current: 1_500,
                    target: 2_000,
                    unit: "kcal",
                    remainingText: "500 kcal remaining",
                    progress: 0.75
                ),
                protein: ProgressMetric(
                    label: "Protein",
                    current: 90,
                    target: 140,
                    unit: "g",
                    remainingText: "50g to go",
                    progress: 0.64
                ),
                water: ProgressMetric(
                    label: "Water",
                    current: 1_000,
                    target: 2_500,
                    unit: "ml",
                    remainingText: "1,500 ml remaining",
                    progress: 0.4
                )
            ),
            statusSummary: "Within target.",
            bestNextMove: "Prioritize protein.",
            tomorrowFocus: nil,
            missingSignals: [],
            detailNote: nil
        )
        let structured = ChatMessage(
            role: .assistant,
            text: "Daily review",
            structuredContent: .dailyReview(payload)
        )
        let plain = ChatMessage(role: .assistant, text: "Hello")

        XCTAssertEqual(
            CoachConversationScrollCoordinator.scrollDelayAfterMessageInsert(
                reason: .assistantResponseArrived,
                lastMessage: structured
            ),
            CoachConversationScrollMetrics.structuredCardLayoutDelay
        )
        XCTAssertEqual(
            CoachConversationScrollCoordinator.scrollDelayAfterMessageInsert(
                reason: .assistantResponseArrived,
                lastMessage: plain
            ),
            0
        )
        XCTAssertEqual(
            CoachConversationScrollCoordinator.scrollDelayAfterMessageInsert(
                reason: .userMessageSent,
                lastMessage: structured
            ),
            0
        )
    }
}
