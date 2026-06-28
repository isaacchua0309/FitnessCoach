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

    func testLocalProfileExistsSkipsCloudFetchWhenOwnerMatches() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        XCTAssertFalse(service.hasLocalProfile())

        _ = try container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-1"
        )

        XCTAssertTrue(service.hasLocalProfile())

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .main)
        XCTAssertEqual(cloudStore.fetchCallCount, 0)
    }

    func testUnownedLocalProfileDoesNotSkipCloudFetch() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        do {
            _ = try await service.resolve(uid: "user-1")
            XCTFail("Expected resolve to require ownership resolution")
        } catch {
            XCTAssertEqual(cloudStore.fetchCallCount, 0)
        }
    }

    func testMissingLocalAndCloudRoutesToMissingCloudProfile() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let result = try await service.resolve(uid: "user-1")

        XCTAssertEqual(result, .missingCloudProfile)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
    }

    func testCloudFetchFailureThrows() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.fetchError = NSError(domain: "test", code: 1)
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

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
        XCTAssertEqual(restored.ownerUID, "user-1")
    }

    func testOwnedProfileUpdateUploadsWhenOwnerMatches() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-1"
        )

        try await service.saveProfileToCloud(uid: "user-1", intent: .ownedProfileUpdate)

        XCTAssertEqual(cloudStore.saveCallCount, 1)
        XCTAssertEqual(cloudStore.lastSavedUID, "user-1")
        XCTAssertEqual(cloudStore.lastSavedProfile?.age, ProfileTestFixtures.sampleDraft.age)
    }

    func testOwnedProfileUpdateBlockedWhenOwnerMismatch() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(
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
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await service.syncOnboardingProfileToCloud(uid: "user-1", intent: .newProfileInitialUpload)

        XCTAssertEqual(cloudStore.saveCallCount, 1)
        XCTAssertEqual(cloudStore.lastSavedUID, "user-1")
        XCTAssertEqual(cloudStore.fetchCallCount, 2)
    }

    func testFetchCloudProfilePresenceAbsentWhenDocumentMissing() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let presence = try await service.fetchCloudProfilePresence(uid: "user-1")

        XCTAssertEqual(presence, .absent)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
    }

    func testFetchCloudProfilePresencePresentWhenDocumentExists() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let presence = try await service.fetchCloudProfilePresence(uid: "user-1")

        guard case .present(let document) = presence else {
            return XCTFail("Expected present cloud profile")
        }
        XCTAssertEqual(document.age, ProfileTestFixtures.sampleProfile.age)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
    }

    func testFetchCloudProfilePresenceThrowsOnFetchFailure() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.fetchError = NSError(domain: "test", code: 1)
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        do {
            _ = try await service.fetchCloudProfilePresence(uid: "user-1")
            XCTFail("Expected fetchCloudProfilePresence to throw")
        } catch {
            XCTAssertEqual(cloudStore.fetchCallCount, 1)
        }
    }

    func testLocalProfileWithoutAuthSkipsCloudFetchWhenOwnerMatches() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(
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
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let profile = ProfileTestFixtures.sampleProfile
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument(for: profile)

        XCTAssertFalse(service.hasLocalProfile())

        let firstResolve = try await service.resolve(uid: "returning-user")
        XCTAssertEqual(firstResolve, .main)
        XCTAssertTrue(service.hasLocalProfile())

        let restored = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertEqual(restored.goalWeightKg, profile.goalWeightKg)

        let fetchCountAfterRestore = cloudStore.fetchCallCount
        _ = try container.userProfileService.assignOwnerUID("returning-user")
        let secondResolve = try await service.resolve(uid: "returning-user")
        XCTAssertEqual(secondResolve, .main)
        XCTAssertEqual(cloudStore.fetchCallCount, fetchCountAfterRestore)
    }
}
