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

    static func build(_ input: WeeklyProgressFreshnessInput?) -> WeeklyProgressFreshnessState? {
        guard let input else { return nil }

        let copy = FormaProductCopy.WeeklyReviewPresentation.Freshness.self

        if input.isRestoringAccount {
            return state(
                card: copy.restoringAccount,
                detail: copy.restoringAccount,
                accessibility: copy.restoringAccount
            )
        }

        if input.isCrossDeviceRefreshing {
            return state(
                card: copy.syncingChanges,
                detail: copy.syncingChanges,
                accessibility: copy.syncingChanges
            )
        }

        if let pendingUploadCount = input.pendingUploadCount, pendingUploadCount > 0 {
            return state(
                card: copy.syncingChanges,
                detail: copy.reviewMayUpdate,
                accessibility: copy.reviewMayUpdate
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
