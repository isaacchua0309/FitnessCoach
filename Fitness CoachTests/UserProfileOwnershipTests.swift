//
//  UserProfileOwnershipTests.swift
//  Fitness CoachTests
//
//  Forma — Local profile ownerUID metadata (Stage 1).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class UserProfileOwnershipTests: XCTestCase {

    func testLegacyProfileLoadsWithNilOwnerUID() async throws {
        let container = try AppContainer(inMemory: true)
        let profile = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        XCTAssertNil(profile.ownerUID)
        XCTAssertNil(try container.userProfileService.getCurrentProfileOwnerUID())
        XCTAssertEqual(
            try container.userProfileService.currentProfileOwnership(for: "any-uid"),
            .unowned
        )
    }

    func testPreAuthCreateProfileHasNilOwnerUID() throws {
        let container = try AppContainer(inMemory: true)

        let profile = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        XCTAssertNil(profile.ownerUID)
        let loaded = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertNil(loaded.ownerUID)
    }

    func testRestoredCloudProfileHasSignedInOwnerUID() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore,
            cloudSyncStore: ProfileCloudSyncStore(userDefaults: container.onboardingUserDefaults)
        )

        _ = try await service.resolve(uid: "signed-in-user")

        let restored = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertEqual(restored.ownerUID, "signed-in-user")
        XCTAssertEqual(
            try container.userProfileService.currentProfileOwnership(for: "signed-in-user"),
            .matchesSession
        )
    }

    func testEntityToModelMappingPreservesOwnerUID() throws {
        let container = try AppContainer(inMemory: true)
        _ = try container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "owner-a"
        )

        let loaded = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertEqual(loaded.ownerUID, "owner-a")
    }

    func testModelToEntityMappingPreservesOwnerUID() throws {
        var profile = ProfileTestFixtures.sampleProfile
        profile.ownerUID = "owner-b"

        let entity = UserProfileEntity(model: profile)
        XCTAssertEqual(entity.ownerUID, "owner-b")
        XCTAssertEqual(entity.toModel().ownerUID, "owner-b")
    }

    func testAssignOwnerUIDUpdatesCurrentProfile() throws {
        let container = try AppContainer(inMemory: true)
        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let assigned = try container.userProfileService.assignOwnerUID("linked-user")

        XCTAssertEqual(assigned.ownerUID, "linked-user")
        XCTAssertEqual(
            try container.userProfileService.currentProfileOwnership(for: "linked-user"),
            .matchesSession
        )
        XCTAssertEqual(
            try container.userProfileService.currentProfileOwnership(for: "other-user"),
            .mismatched(localOwnerUID: "linked-user")
        )
    }

    func testOnboardingCloudSyncAssignsOwnerUID() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let syncStore = ProfileCloudSyncStore(userDefaults: container.onboardingUserDefaults)
        let bootstrapService = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore,
            cloudSyncStore: syncStore
        )
        let coordinator = ProfileBootstrapCoordinatorService(
            profileBootstrapService: bootstrapService,
            cloudSyncStore: syncStore
        )

        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        XCTAssertNil(try container.userProfileService.getCurrentProfileOwnerUID())

        try await coordinator.syncOnboardingProfileToCloud(uid: "save-plan-user")

        XCTAssertEqual(try container.userProfileService.getCurrentProfileOwnerUID(), "save-plan-user")
    }
}
