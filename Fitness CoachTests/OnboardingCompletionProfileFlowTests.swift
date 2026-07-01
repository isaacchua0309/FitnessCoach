//
//  OnboardingCompletionProfileFlowTests.swift
//  Fitness CoachTests
//
//  Service-level flow tests for onboarding-completion cloud presence handling.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingCompletionProfileFlowTests: XCTestCase {

    func testAbsentCloudProfileAllowsUploadPath() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let presence = try await service.fetchCloudProfilePresence(uid: "user-1")
        XCTAssertEqual(presence, .absent)

        try await service.syncOnboardingProfileToCloud(uid: "user-1", intent: .newProfileInitialUpload)
        XCTAssertEqual(cloudStore.saveCallCount, 1)
    }

    func testPresentCloudProfileDoesNotUploadUntilExplicitSave() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let presence = try await service.fetchCloudProfilePresence(uid: "user-1")
        guard case .present = presence else {
            return XCTFail("Expected cloud profile to exist")
        }

        XCTAssertEqual(cloudStore.saveCallCount, 0)
    }

    func testFetchFailureDoesNotUpload() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.fetchError = NSError(domain: "test", code: 1)
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            cloudStore: cloudStore
        )

        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        do {
            _ = try await service.fetchCloudProfilePresence(uid: "user-1")
            XCTFail("Expected fetch to throw")
        } catch {
            XCTAssertEqual(cloudStore.saveCallCount, 0)
        }
    }

    func testOnboardingCompletionUploadFailureBlocksCompletion() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.saveError = NSError(domain: "test", code: 1)
        let container = try AppContainer(inMemory: true)
        let syncStore = ProfileCloudSyncStore(userDefaults: container.onboardingUserDefaults)
        let service = ProfileBootstrapService(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            cloudStore: cloudStore,
            cloudSyncStore: syncStore
        )
        let coordinator = ProfileBootstrapCoordinatorService(
            profileBootstrapService: service,
            cloudSyncStore: syncStore
        )

        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await coordinator.resolveOnboardingCompletion(uid: "user-1")

        XCTAssertEqual(outcome, .cloudSyncFailed)
        XCTAssertFalse(syncStore.isSyncedForUID("user-1"))
    }

    func testRestorePathReplacesLocalWithoutUpload() async throws {
        let cloudStore = MockCloudUserProfileStore()
        var cloudProfile = ProfileTestFixtures.sampleProfile
        cloudProfile.targets.calorieTarget = 1_888
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument(for: cloudProfile)

        let container = try AppContainer(inMemory: true)
        let bootstrap = ProfileBootstrapService(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            cloudStore: cloudStore
        )

        var draft = ProfileTestFixtures.sampleDraft
        draft.targets.calorieTarget = 2_100
        _ = try container.userProfileService.createProfile(draft)

        let presence = try await bootstrap.fetchCloudProfilePresence(uid: "user-1")
        guard case .present(let document) = presence else {
            return XCTFail("Expected cloud profile")
        }

        let restored = try container.userProfileService.replaceLocalProfile(
            with: document,
            ownerUID: "user-1"
        )
        XCTAssertEqual(restored.targets.calorieTarget, 1_888)
        XCTAssertEqual(restored.ownerUID, "user-1")
        XCTAssertEqual(cloudStore.saveCallCount, 0)
    }
}
