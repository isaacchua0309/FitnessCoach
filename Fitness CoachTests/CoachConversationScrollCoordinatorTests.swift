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
}
