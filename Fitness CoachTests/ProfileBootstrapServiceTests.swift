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

    private var harness: ProfileBootstrapTestSupport.Harness!

    override func setUp() async throws {
        harness = try ProfileBootstrapTestSupport.makeHarness()
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testLocalProfileExistsSkipsCloudFetchWhenOwnerMatches() async throws {
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        XCTAssertFalse(service.hasLocalProfile())

        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-1"
        )

        XCTAssertTrue(service.hasLocalProfile())

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .main)
        XCTAssertEqual(cloudStore.fetchCallCount, 0)
    }

    func testUnownedLocalProfileDoesNotSkipCloudFetch() async throws {
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        do {
            _ = try await service.resolve(uid: "user-1")
            XCTFail("Expected resolve to require ownership resolution")
        } catch {
            XCTAssertEqual(cloudStore.fetchCallCount, 0)
        }
    }

    func testMissingLocalAndCloudRoutesToMissingCloudProfile() async throws {
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .missingCloudProfile)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
    }

    func testCloudFetchFailureThrows() async throws {
        harness.cloudStore.fetchError = NSError(domain: "test", code: 1)
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        do {
            _ = try await service.resolve(uid: "user-1")
            XCTFail("Expected resolve to throw")
        } catch {
            XCTAssertEqual(cloudStore.fetchCallCount, 1)
        }
    }

    func testMissingCloudProfileMapsToRootState() {
        XCTAssertEqual(
            RootProfileRouteResolver.resolve(bootstrapResult: .missingCloudProfile),
            .missingCloudProfile
        )
    }

    func testMissingLocalWithCloudProfileRestoresLocally() async throws {
        let service = harness.bootstrapService
        let profile = ProfileTestFixtures.sampleProfile
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument(for: profile)

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .main)
        let restored = try XCTUnwrap(try harness.profileService.getCurrentProfile())
        XCTAssertEqual(restored.age, profile.age)
        XCTAssertEqual(restored.currentWeightKg, profile.currentWeightKg)
        XCTAssertEqual(restored.targets, profile.targets)
        XCTAssertEqual(restored.ownerUID, "user-1")
    }

    func testOwnedProfileUpdateUploadsWhenOwnerMatches() async throws {
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-1"
        )

        try await service.saveProfileToCloud(uid: "user-1", intent: .ownedProfileUpdate)

        XCTAssertEqual(cloudStore.saveCallCount, 1)
        XCTAssertEqual(cloudStore.lastSavedUID, "user-1")
        XCTAssertEqual(cloudStore.lastSavedProfile?.age, ProfileTestFixtures.sampleDraft.age)
    }

    func testOwnedProfileUpdateBlockedWhenOwnerMismatch() async throws {
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        do {
            try await service.saveProfileToCloud(uid: "user-1", intent: .ownedProfileUpdate)
            XCTFail("Expected owned update to be blocked")
        } catch let error as CloudProfileWriteError {
            XCTAssertEqual(
                error,
                .blocked(.ownerMismatch(localOwnerUID: "other-user", signedInUID: "user-1"))
            )
        }

        XCTAssertEqual(cloudStore.saveCallCount, 0)
    }

    func testSyncOnboardingProfileToCloudUploadsWhenCloudMissing() async throws {
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await service.syncOnboardingProfileToCloud(uid: "user-1", intent: .newProfileInitialUpload)

        XCTAssertEqual(cloudStore.saveCallCount, 1)
        XCTAssertEqual(cloudStore.lastSavedUID, "user-1")
        XCTAssertEqual(cloudStore.fetchCallCount, 2)
    }

    func testFetchCloudProfilePresenceAbsentWhenDocumentMissing() async throws {
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        let presence = try await service.fetchCloudProfilePresence(uid: "user-1")

        XCTAssertEqual(presence, .absent)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
    }

    func testFetchCloudProfilePresencePresentWhenDocumentExists() async throws {
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        let presence = try await service.fetchCloudProfilePresence(uid: "user-1")

        guard case .present(let document) = presence else {
            return XCTFail("Expected present cloud profile")
        }
        XCTAssertEqual(document.age, ProfileTestFixtures.sampleProfile.age)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
    }

    func testFetchCloudProfilePresenceThrowsOnFetchFailure() async throws {
        harness.cloudStore.fetchError = NSError(domain: "test", code: 1)
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        do {
            _ = try await service.fetchCloudProfilePresence(uid: "user-1")
            XCTFail("Expected fetchCloudProfilePresence to throw")
        } catch {
            XCTAssertEqual(cloudStore.fetchCallCount, 1)
        }
    }

    func testLocalProfileWithoutAuthSkipsCloudFetchWhenOwnerMatches() async throws {
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore

        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "offline-local-user"
        )

        XCTAssertTrue(service.hasLocalProfile())
        let result = try await service.resolve(uid: "offline-local-user")

        XCTAssertEqual(result, .main)
        XCTAssertEqual(cloudStore.fetchCallCount, 0)
        XCTAssertEqual(
            RootProfileRouteResolver.resolve(hasProfile: service.hasLocalProfile()),
            .main
        )
    }

    func testExistingCloudProfileRestoreStillWorksAfterFreshInstall() async throws {
        let service = harness.bootstrapService
        let cloudStore = harness.cloudStore
        let profile = ProfileTestFixtures.sampleProfile
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument(for: profile)

        XCTAssertFalse(service.hasLocalProfile())

        let firstResolve = try await service.resolve(uid: "returning-user")
        XCTAssertEqual(firstResolve, .main)
        XCTAssertTrue(service.hasLocalProfile())

        let restored = try XCTUnwrap(try harness.profileService.getCurrentProfile())
        XCTAssertEqual(restored.goalWeightKg, profile.goalWeightKg)

        let fetchCountAfterRestore = cloudStore.fetchCallCount
        _ = try harness.profileService.assignOwnerUID("returning-user")
        let secondResolve = try await service.resolve(uid: "returning-user")
        XCTAssertEqual(secondResolve, .main)
        XCTAssertEqual(cloudStore.fetchCallCount, fetchCountAfterRestore)
    }
}
