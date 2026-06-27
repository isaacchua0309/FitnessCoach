//
//  NoOpCloudUserProfileStore.swift
//  Fitness Coach
//
//  FitPilot — Inert cloud profile store for previews and in-memory containers.
//

import Foundation

final class NoOpCloudUserProfileStore: CloudUserProfileStoring, @unchecked Sendable {

    func fetch(uid: String) async throws -> CloudUserProfileDocument? {
        _ = uid
        return nil
    }

    func save(profile: UserProfile, uid: String) async throws {
        _ = profile
        _ = uid
    }
}
