//
//  WeeklyProgressFreshnessBuilder.swift
//  Fitness Coach
//
//  Forma — Lightweight sync/restore freshness microcopy for weekly progress.
//

import Foundation

struct WeeklyProgressFreshnessInput: Equatable {
    var isRestoringAccount: Bool
    var isCrossDeviceRefreshing: Bool
    var pendingUploadCount: Int?
    var lastRefreshAt: Date?
    var recentlyRestoredAt: Date?
    var now: Date
    var recentRefreshThreshold: TimeInterval = 120
    var recentRestoreThreshold: TimeInterval = 300
}

struct WeeklyProgressFreshnessState: Equatable {
    var cardMessage: String?
    var detailMessage: String?
    var accessibilityLabel: String

    var resolvedDetailMessage: String? {
        detailMessage ?? cardMessage
    }
}

enum WeeklyProgressFreshnessBuilder {

    enum Surface {
        case journey
        case generic
    }

    static func build(
        _ input: WeeklyProgressFreshnessInput?,
        surface: Surface = .generic
    ) -> WeeklyProgressFreshnessState? {
        guard let input else { return nil }

        let copy = FormaProductCopy.WeeklyReviewPresentation.Freshness.self
        let journeySyncCopy = FormaProductCopy.Journey.Sync.healthDataSyncing

        if input.isRestoringAccount {
            return state(
                card: copy.restoringAccount,
                detail: copy.restoringAccount,
                accessibility: copy.restoringAccount
            )
        }

        if input.isCrossDeviceRefreshing {
            let syncingMessage = surface == .journey ? journeySyncCopy : copy.syncingChanges
            return state(
                card: syncingMessage,
                detail: syncingMessage,
                accessibility: syncingMessage
            )
        }

        if let pendingUploadCount = input.pendingUploadCount, pendingUploadCount > 0 {
            let cardMessage = surface == .journey ? journeySyncCopy : copy.syncingChanges
            let detailMessage = surface == .journey
                ? journeySyncCopy
                : copy.reviewMayUpdate
            return state(
                card: cardMessage,
                detail: detailMessage,
                accessibility: detailMessage
            )
        }

        if let restoredAt = input.recentlyRestoredAt,
           input.now.timeIntervalSince(restoredAt) <= input.recentRestoreThreshold {
            return state(
                card: copy.savedToAccount,
                detail: nil,
                accessibility: copy.savedToAccount
            )
        }

        if let refreshAt = input.lastRefreshAt,
           input.now.timeIntervalSince(refreshAt) <= input.recentRefreshThreshold {
            return state(
                card: copy.updatedJustNow,
                detail: nil,
                accessibility: copy.updatedJustNow
            )
        }

        return nil
    }

    private static func state(
        card: String,
        detail: String?,
        accessibility: String
    ) -> WeeklyProgressFreshnessState {
        WeeklyProgressFreshnessState(
            cardMessage: card,
            detailMessage: detail,
            accessibilityLabel: accessibility
        )
    }
}
