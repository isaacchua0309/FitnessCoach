//
//  ProfileCloudUploadFailureNotifier.swift
//  Fitness Coach
//
//  Forma — Surfaces cloud backup failures from background upload paths (Stage 8).
//

import Combine
import Foundation

@MainActor
final class ProfileCloudUploadFailureNotifier: ObservableObject {

    private let syncStore: ProfileCloudSyncStore?

    @Published private(set) var pendingContext: CloudProfileUploadFailureContext?

    init(syncStore: ProfileCloudSyncStore? = nil) {
        self.syncStore = syncStore
    }

    func reportFailure(_ context: CloudProfileUploadFailureContext) {
        syncStore?.clear()
        pendingContext = context
    }

    func clear() {
        pendingContext = nil
    }
}
