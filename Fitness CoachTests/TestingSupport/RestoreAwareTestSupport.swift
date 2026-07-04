//
//  RestoreAwareTestSupport.swift
//  Fitness CoachTests
//

import Foundation
@testable import Fitness_Coach

@MainActor
final class StubAccountLocalDataInspector: AccountLocalDataInspecting {
    let isEffectivelyEmpty: Bool

    init(isEffectivelyEmpty: Bool) {
        self.isEffectivelyEmpty = isEffectivelyEmpty
    }

    func inspectLocalData(for uid: String) async throws -> AccountLocalDataStatus {
        AccountLocalDataStatus(
            uid: uid,
            hasProfile: true,
            hasAnyDailyLogs: !isEffectivelyEmpty,
            hasTodayDailyLog: !isEffectivelyEmpty,
            foodEntryCount: isEffectivelyEmpty ? 0 : 1,
            waterEntryCount: 0,
            weightEntryCount: 0,
            dailyReviewCount: 0,
            pendingMutationCount: 0,
            failedMutationCount: 0,
            newestLocalUpdatedAt: nil,
            oldestLocalDate: nil,
            newestLocalDate: nil,
            isEffectivelyEmpty: isEffectivelyEmpty,
            needsInitialRestore: isEffectivelyEmpty
        )
    }
}
