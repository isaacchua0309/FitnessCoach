//
//  CloudProfileResolutionTests.swift
//  Fitness CoachTests
//
//  Forma — Read-only cloud profile resolution (Stage 3).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CloudProfileResolutionTests: XCTestCase {

    private func makeService(
        cloudStore: MockCloudUserProfileStore,
        container: AppContainer? = nil
    ) throws -> (ProfileBootstrapService, AppContainer) {
        let resolvedContainer = try container ?? AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: resolvedContainer.userProfileService,
            cloudStore: cloudStore
        )
        return (service, resolvedContainer)
    }

    func testResolveCloudProfileFoundWhenDocumentExists() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        let (service, _) = try makeService(cloudStore: cloudStore)

        let result = await service.resolveCloudProfile(
            uid: "user-1",
            context: .ownershipResolution
        )

        guard case .found(let document) = result else {
            return XCTFail("Expected found cloud profile, got \(result)")
        }
        XCTAssertEqual(document.age, ProfileTestFixtures.sampleProfile.age)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
        XCTAssertEqual(cloudStore.saveCallCount, 0)
    }

    func testResolveCloudProfileMissingWhenDocumentAbsent() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let (service, _) = try makeService(cloudStore: cloudStore)

        let result = await service.resolveCloudProfile(
            uid: "user-1",
            context: .returningSignIn
        )

        XCTAssertTrue(result.isMissing)
        XCTAssertFalse(result.isFailed)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
        XCTAssertEqual(cloudStore.saveCallCount, 0)
    }

    func testResolveCloudProfileFailedWhenStoreThrows() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.fetchError = NSError(domain: "test.cloud", code: 42)
        let (service, _) = try makeService(cloudStore: cloudStore)

        let result = await service.resolveCloudProfile(
            uid: "user-1",
            context: .accountSwitch
        )

        guard case .failed(let failure) = result else {
            return XCTFail("Expected failed cloud lookup, got \(result)")
        }
        XCTAssertEqual(failure.domain, "test.cloud")
        XCTAssertEqual(failure.code, 42)
        XCTAssertFalse(result.isMissing)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
        XCTAssertEqual(cloudStore.saveCallCount, 0)
    }

    func testMissingAndFailedAreDistinguishable() async throws {
        let missingStore = MockCloudUserProfileStore()
        let (missingService, _) = try makeService(cloudStore: missingStore)
        let missingResult = await missingService.resolveCloudProfile(
            uid: "user-1",
            context: .normalLaunch
        )

        let failedStore = MockCloudUserProfileStore()
        failedStore.fetchError = NSError(domain: "test.cloud", code: 1)
        let (failedService, _) = try makeService(cloudStore: failedStore)
        let failedResult = await failedService.resolveCloudProfile(
            uid: "user-1",
            context: .normalLaunch
        )

        XCTAssertTrue(missingResult.isMissing)
        XCTAssertFalse(missingResult.isFailed)
        XCTAssertTrue(failedResult.isFailed)
        XCTAssertFalse(failedResult.isMissing)
        XCTAssertNotEqual(
            missingResult.ownershipLookupResult,
            failedResult.ownershipLookupResult
        )
    }

    func testOwnershipCloudLookupMapsFoundSummary() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let document = ProfileTestFixtures.cloudDocument()
        cloudStore.storedDocument = document
        let (service, _) = try makeService(cloudStore: cloudStore)

        let lookup = await service.ownershipCloudLookup(
            uid: "user-1",
            context: .ownershipResolution
        )

        XCTAssertEqual(
            lookup,
            .found(CloudProfileSummary(updatedAt: document.updatedAt))
        )
        XCTAssertEqual(cloudStore.saveCallCount, 0)
    }

    func testOwnershipCloudLookupMapsMissingAndFailed() async throws {
        let missingStore = MockCloudUserProfileStore()
        let (missingService, _) = try makeService(cloudStore: missingStore)

        let missingLookup = await missingService.ownershipCloudLookup(
            uid: "user-1",
            context: .ownershipResolution
        )
        XCTAssertEqual(missingLookup, .missing)

        let failedStore = MockCloudUserProfileStore()
        failedStore.fetchError = NSError(domain: "test.cloud", code: 7)
        let (failedService, _) = try makeService(cloudStore: failedStore)

        let failedLookup = await failedService.ownershipCloudLookup(
            uid: "user-1",
            context: .ownershipResolution
        )
        XCTAssertEqual(failedLookup, .failed)
    }

    func testFetchCloudProfilePresenceDelegatesToResolveCloudProfile() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        let (service, _) = try makeService(cloudStore: cloudStore)

        let presence = try await service.fetchCloudProfilePresence(uid: "user-1")

        guard case .present(let document) = presence else {
            return XCTFail("Expected present cloud profile")
        }
        XCTAssertEqual(document.age, ProfileTestFixtures.sampleProfile.age)
        XCTAssertEqual(cloudStore.fetchCallCount, 1)
        XCTAssertEqual(cloudStore.saveCallCount, 0)
    }

    func testFetchCloudProfilePresenceThrowsOnFailedLookup() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.fetchError = NSError(domain: "test.cloud", code: 99)
        let (service, _) = try makeService(cloudStore: cloudStore)

        do {
            _ = try await service.fetchCloudProfilePresence(uid: "user-1")
            XCTFail("Expected fetchCloudProfilePresence to throw")
        } catch let error as CloudProfileResolutionFailure {
            XCTAssertEqual(error.code, 99)
        }
        XCTAssertEqual(cloudStore.saveCallCount, 0)
    }
}
