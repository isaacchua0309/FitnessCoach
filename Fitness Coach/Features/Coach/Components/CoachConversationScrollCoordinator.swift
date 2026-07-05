//
//  CoachConversationScrollCoordinator.swift
//  Fitness Coach
//
//  FitPilot AI — Conservative auto-scroll policy for the Coach transcript.
//

import CoreGraphics
import Foundation

enum CoachConversationScrollAnchor {
    static let bottom = "coach-transcript-bottom"
}

enum CoachConversationScrollMetrics {
    /// Distance from the transcript bottom within which the user is treated as "following" the thread.
    static let nearBottomThreshold: CGFloat = 96
    /// Lets keyboard and bottom-accessory layout settle before scrolling.
    static let focusTransitionDelay: TimeInterval = 0.1
    static let layoutTransitionDelay: TimeInterval = 0.05
    /// Extra beat for tall structured assistant cards (daily review, nutrition).
    static let structuredCardLayoutDelay: TimeInterval = 0.1
}

enum CoachConversationScrollReason: Equatable {
    case userMessageSent
    case assistantResponseArrived
    case pendingCardAppeared
    case pendingCardUpdated
    case pendingCardDismissed
    case inputFocused
    case inputBlurred
    case sendingStarted
    case sendingFinished
}

enum CoachConversationScrollCoordinator {

    static func shouldAutoScroll(
        reason: CoachConversationScrollReason,
        isNearBottom: Bool
    ) -> Bool {
        switch reason {
        case .userMessageSent, .pendingCardAppeared:
            return true
        case .assistantResponseArrived,
             .pendingCardUpdated,
             .pendingCardDismissed,
             .inputFocused,
             .inputBlurred,
             .sendingStarted,
             .sendingFinished:
            return isNearBottom
        }
    }

    static func reasonForMessageCountChange(
        previousCount: Int,
        newCount: Int,
        lastMessageRole: ChatMessageRole?
    ) -> CoachConversationScrollReason? {
        guard newCount > previousCount, let lastMessageRole else { return nil }
        switch lastMessageRole {
        case .user:
            return .userMessageSent
        case .assistant, .system:
            return .assistantResponseArrived
        }
    }

    static func reasonForPendingConfirmationChange(
        previous: CoachPendingConfirmation?,
        current: CoachPendingConfirmation?
    ) -> CoachConversationScrollReason? {
        switch (previous, current) {
        case (nil, .some):
            return .pendingCardAppeared
        case (.some, nil):
            return .pendingCardDismissed
        case (.some, .some) where previous != current:
            return .pendingCardUpdated
        default:
            return nil
        }
    }

    /// Lets structured assistant cards finish layout before scrolling them above the composer.
    static func scrollDelayAfterMessageInsert(
        reason: CoachConversationScrollReason,
        lastMessage: ChatMessage?
    ) -> TimeInterval {
        guard reason == .assistantResponseArrived,
              lastMessage?.structuredContent != nil else {
            return 0
        }
        return CoachConversationScrollMetrics.structuredCardLayoutDelay
    }

    static func distanceFromBottom(
        contentSizeHeight: CGFloat,
        contentOffsetY: CGFloat,
        containerHeight: CGFloat
    ) -> CGFloat {
        max(0, contentSizeHeight - contentOffsetY - containerHeight)
    }

    static func isNearBottom(distanceFromBottom: CGFloat) -> Bool {
        distanceFromBottom <= CoachConversationScrollMetrics.nearBottomThreshold
    }
}
