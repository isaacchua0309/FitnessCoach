//
//  ProfileRestoreRoutingTests.swift
//  Fitness CoachTests
//
//  Profile bootstrap → root shell routing (no Firebase).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class ProfileRestoreRoutingTests: XCTestCase {

    func testRestoreFromCloudSetsMainRouteInputs() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let bootstrapResult = try await service.resolve(uid: "restored-user")
        let rootState = RootProfileRouteResolver.resolve(bootstrapResult: bootstrapResult)
        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "restored-user"),
            rootState: rootState
        )

        XCTAssertEqual(bootstrapResult, .main)
        XCTAssertEqual(rootState, .main)
        XCTAssertEqual(shellRoute, .main)
        XCTAssertNotNil(try container.userProfileService.getCurrentProfile())
    }

    func testMissingLocalAndCloudSetsOnboardingRouteInputs() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let service = ProfileBootstrapService(
            userProfileService: container.userProfileService,
            cloudStore: cloudStore
        )

        let bootstrapResult = try await service.resolve(uid: "new-user")
        let rootState = RootProfileRouteResolver.resolve(bootstrapResult: bootstrapResult)
        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "new-user"),
            rootState: rootState,
            isOnboardingModelReady: true
        )

        XCTAssertEqual(bootstrapResult, .onboarding)
        XCTAssertEqual(rootState, .onboarding)
        XCTAssertEqual(shellRoute, .onboarding)
    }
}
