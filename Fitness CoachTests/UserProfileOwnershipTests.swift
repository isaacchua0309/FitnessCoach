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

    private var harness: DailyLogServiceTestSupport.Harness!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testLegacyProfileLoadsWithNilOwnerUID() async throws {
        let profile = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        XCTAssertNil(profile.ownerUID)
        XCTAssertNil(try harness.profileService.getCurrentProfileOwnerUID())
        XCTAssertEqual(
            try harness.profileService.currentProfileOwnership(for: "any-uid"),
            .unowned
        )
    }

    func testPreAuthCreateProfileHasNilOwnerUID() throws {
        let profile = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        XCTAssertNil(profile.ownerUID)
        let loaded = try XCTUnwrap(try harness.profileService.getCurrentProfile())
        XCTAssertNil(loaded.ownerUID)
    }

    func testRestoredCloudProfileHasSignedInOwnerUID() async throws {
        let bootstrapHarness = try ProfileBootstrapTestSupport.makeHarness()
        bootstrapHarness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        _ = try await bootstrapHarness.bootstrapService.resolve(uid: "signed-in-user")

        let restored = try XCTUnwrap(try bootstrapHarness.profileService.getCurrentProfile())
        XCTAssertEqual(restored.ownerUID, "signed-in-user")
        XCTAssertEqual(
            try bootstrapHarness.profileService.currentProfileOwnership(for: "signed-in-user"),
            .matchesSession
        )
    }

    func testEntityToModelMappingPreservesOwnerUID() throws {
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "owner-a"
        )

        let loaded = try XCTUnwrap(try harness.profileService.getCurrentProfile())
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
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let assigned = try harness.profileService.assignOwnerUID("linked-user")

        XCTAssertEqual(assigned.ownerUID, "linked-user")
        XCTAssertEqual(
            try harness.profileService.currentProfileOwnership(for: "linked-user"),
            .matchesSession
        )
        XCTAssertEqual(
            try harness.profileService.currentProfileOwnership(for: "other-user"),
            .mismatched(localOwnerUID: "linked-user")
        )
    }

    func testOnboardingCloudSyncAssignsOwnerUID() async throws {
        let bootstrapHarness = try ProfileBootstrapTestSupport.makeHarness()
        let coordinator = bootstrapHarness.makeCoordinator()

        _ = try bootstrapHarness.profileService.createProfile(ProfileTestFixtures.sampleDraft)
        XCTAssertNil(try bootstrapHarness.profileService.getCurrentProfileOwnerUID())

        try await coordinator.syncOnboardingProfileToCloud(uid: "save-plan-user")

        XCTAssertEqual(
            try bootstrapHarness.profileService.getCurrentProfileOwnerUID(),
            "save-plan-user"
        )
    }
}
