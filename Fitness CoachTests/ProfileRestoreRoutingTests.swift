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

        let harness = try DailyLogServiceTestSupport.makeHarness()
        let service = ProfileBootstrapService(
            userProfileService: harness.profileService,
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
        XCTAssertNotNil(try harness.profileService.getCurrentProfile())
    }

    func testMissingLocalAndCloudSetsMissingCloudProfileRouteInputs() async throws {
        let cloudStore = MockCloudUserProfileStore()
        let harness = try DailyLogServiceTestSupport.makeHarness()
        let service = ProfileBootstrapService(
            userProfileService: harness.profileService,
            cloudStore: cloudStore
        )

        let bootstrapResult = try await service.resolve(uid: "new-user")
        let rootState = RootProfileRouteResolver.resolve(bootstrapResult: bootstrapResult)
        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "new-user"),
            rootState: rootState,
            isOnboardingModelReady: true
        )

        XCTAssertEqual(bootstrapResult, .missingCloudProfile)
        XCTAssertEqual(rootState, .missingCloudProfile)
        XCTAssertEqual(shellRoute, .missingCloudProfile)
    }

    /// Signed-out v2 pre-auth routing is covered in `AppRouteResolverTests` and
    /// `OnboardingShellRouteResolverTests` (pure, no SwiftData). This case documents
    /// the composed inputs those resolvers expect after local profile resolution.
    func testSignedOutV2RoutingInputsFromLocalProfileResolution() {
        let rootWithProfile = RootProfileRouteResolver.resolve(hasProfile: true)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                rootState: rootWithProfile,
                isOnboardingModelReady: true,
                hasLocalProfile: true,
                isOnboardingV2Enabled: true
            ),
            .localOnboarding
        )

        let rootWithoutProfile = RootProfileRouteResolver.resolve(hasProfile: false)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                rootState: rootWithoutProfile,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                isOnboardingV2Enabled: true
            ),
            .localOnboarding
        )
    }
}
