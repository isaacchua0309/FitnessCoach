//
//  ProfileBootstrapServiceTests.swift
//  Fitness CoachTests
//
//  FitPilot — Profile bootstrap and cloud restore orchestration tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class ProfileBootstrapServiceTests: XCTestCase {

    func testLocalProfileExistsSkipsCloudFetch() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .main)
        XCTAssertEqual(cloudStore.fetchCallCount, 0)
    }

    func testMissingLocalAndCloudRoutesToOnboarding() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .onboarding)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
    }

    func testMissingLocalWithCloudProfileRestoresLocally() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let profile = ProfileTestFixtures.sampleProfile
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument(for: profile)

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .main)
        let restored = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertEqual(restored.age, profile.age)
        XCTAssertEqual(restored.currentWeightKg, profile.currentWeightKg)
        XCTAssertEqual(restored.targets, profile.targets)
    }

    func testSaveProfileToCloudUsesCurrentLocalProfile() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await service.saveProfileToCloud(uid: "user-1")

        XCTAssertEqual(cloudStore.saveCallCount, 1)
        XCTAssertEqual(cloudStore.lastSavedUID, "user-1")
        XCTAssertEqual(cloudStore.lastSavedProfile?.age, ProfileTestFixtures.sampleDraft.age)
    }
}
