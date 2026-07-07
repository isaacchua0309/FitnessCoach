//
//  AuthRestoreRoutingTests.swift
//  Fitness CoachTests
//
//  Forma — Auth gate restore routing tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AuthRestoreRoutingTests: XCTestCase {

    private var container: AppContainer!
    private var coordinator: AuthGateCoordinator!

    override func setUp() async throws {
        container = try AppContainer(inMemory: true)
        coordinator = AuthGateCoordinator(container: container)
    }

    override func tearDown() {
        coordinator = nil
        container = nil
        super.tearDown()
    }

    func testExistingUserFreshInstallRoutesToRestoreBeforeMainApp() throws {
        let uid = "returning-user"
        coordinator.rootModel.beginAccountRestore(uid: uid)
        coordinator.accountRestoreViewModel = AccountRestoreViewModel(container: container)

        XCTAssertEqual(coordinator.rootModel.state, .restoringAccount)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .restoringAccount
            ),
            .signedInProfileLoading
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .restoringAccount
            ),
            .main
        )
        XCTAssertNotNil(coordinator.accountRestoreViewModel)
    }

    func testNewUserWithoutProfileRoutesToOnboarding() {
        coordinator.applyExistingUserSignInResolution(.noProfileFound, uid: "new-user")

        XCTAssertEqual(coordinator.rootModel.state, .missingCloudProfile)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "new-user"),
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
        XCTAssertNil(coordinator.accountRestoreViewModel)
    }

    func testCompletedRestoreRoutesToMainApp() throws {
        let uid = "restored-user"
        let summary = RestoreAwareTestSupport.makeRestoreSummary(uid: uid, status: .completed)
        coordinator.applyTestingSignedInUID(uid)
        _ = try container.userProfileService.createProfile(ProfileFixtures.sampleDraft)
        _ = try container.userProfileService.assignOwnerUID(uid)

        coordinator.completeRouteToMain(uid: uid, restoreSummary: summary)

        XCTAssertEqual(coordinator.rootModel.state, .main)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
        XCTAssertFalse(container.accountRestoreSessionState.isBlockingRestoreActive)
    }

    func testPartialRestoreCanRouteToMainApp() throws {
        let uid = "partial-user"
        let summary = RestoreAwareTestSupport.makeRestoreSummary(uid: uid, status: .partial)
        coordinator.applyTestingSignedInUID(uid)
        _ = try container.userProfileService.createProfile(ProfileFixtures.sampleDraft)
        _ = try container.userProfileService.assignOwnerUID(uid)

        coordinator.completeRouteToMain(uid: uid, restoreSummary: summary)

        XCTAssertEqual(coordinator.rootModel.state, .main)
        XCTAssertEqual(container.accountRestoreSessionState.lastCompletedSummary?.status, .partial)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
    }

    func testAuthFailureDoesNotRouteToMainApp() {
        coordinator.applyExistingUserSignInResolution(.lookupFailed, uid: "failed-user")

        XCTAssertEqual(coordinator.rootModel.state, .existingUserProfileLookupFailed)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "failed-user"),
                rootState: .existingUserProfileLookupFailed
            ),
            .existingUserProfileLookupFailed
        )
        XCTAssertNotEqual(coordinator.rootModel.state, .main)
    }

    func testAccountSwitchResetsRestoreRoute() throws {
        coordinator.rootModel.beginAccountRestore(uid: "user-a")
        coordinator.accountRestoreViewModel = AccountRestoreViewModel(container: container)
        container.accountRestoreSessionState.beginBlockingRestore()
        let priorSessionID = coordinator.signedInSessionID

        coordinator.handleSignedOutTransition(
            from: .signedIn(uid: "user-a"),
            to: .signedOut,
            wasSignedIn: true
        )

        XCTAssertNil(coordinator.accountRestoreViewModel)
        XCTAssertEqual(coordinator.rootModel.state, .loading)
        XCTAssertFalse(container.accountRestoreSessionState.isBlockingRestoreActive)
        XCTAssertNil(container.accountRestoreSessionState.lastCompletedSummary)
        XCTAssertNotEqual(coordinator.signedInSessionID, priorSessionID)
        XCTAssertEqual(coordinator.effectiveRoute, .welcome)
    }
}
