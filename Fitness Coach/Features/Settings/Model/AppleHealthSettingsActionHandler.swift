//
//  AppleHealthSettingsActionHandler.swift
//  Fitness Coach
//
//  Forma — Primary actions for Settings → Apple Health.
//

import Foundation

enum AppleHealthSettingsActionHandler {

    static func perform(
        action: AppleHealthSettingsActionKind,
        openHealthApp: () -> Void,
        connect: () async -> Void,
        refreshHealthData: () async -> Void,
        syncRemoteSummaries: () async -> Void,
        deleteRemoteSummaries: () async throws -> Void
    ) async {
        switch action {
        case .connectAppleHealth:
            await connect()
        case .refreshHealthData:
            await refreshHealthData()
        case .manageInAppleHealth:
            openHealthApp()
        case .manageHealthDataSync:
            break
        case .deleteRemoteHealthSummaries:
            try? await deleteRemoteSummaries()
        }
    }

    static func performRemoteSyncNow(syncRemoteSummaries: () async -> Void) async {
        await syncRemoteSummaries()
    }
}
