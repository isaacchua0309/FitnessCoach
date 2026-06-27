//
//  MockCloudUserProfileStore.swift
//  Fitness CoachTests
//
//  In-memory cloud profile store (no Firebase).
//

import Foundation
@testable import Fitness_Coach

@MainActor
final class MockCloudUserProfileStore: CloudUserProfileStoring, @unchecked Sendable {

    var storedDocument: CloudUserProfileDocument?
    var fetchError: Error?
    private(set) var fetchCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var lastSavedProfile: UserProfile?
    private(set) var lastSavedUID: String?

    func fetch(uid: String) async throws -> CloudUserProfileDocument? {
        _ = uid
        fetchCallCount += 1
        if let fetchError {
            throw fetchError
        }
        return storedDocument
    }

    func save(profile: UserProfile, uid: String) async throws {
        saveCallCount += 1
        lastSavedProfile = profile
        lastSavedUID = uid
        storedDocument = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: storedDocument?.onboardingCompletedAt ?? profile.createdAt,
            updatedAt: Date()
        )
    }
}
