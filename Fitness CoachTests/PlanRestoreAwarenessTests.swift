//
//  PlanRestoreAwarenessTests.swift
//  Fitness CoachTests
//
//  Forma — Plan tab restore/bootstrap routing tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class PlanRestoreAwarenessTests: XCTestCase {

    func testPlanUsesRestoredProfileAfterBootstrap() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(
            cloudUID: RestoreAwareTestSupport.ownerUID
        )
        harness.cloudStore.storedDocument = ProfileFixtures.cloudDocument()

        let bootstrapResult = try await harness.profileBootstrapService.resolve(
            uid: RestoreAwareTestSupport.ownerUID
        )
        XCTAssertEqual(bootstrapResult, .main)
        XCTAssertEqual(
            try harness.profileService.getCurrentProfile()?.ownerUID,
            RestoreAwareTestSupport.ownerUID
        )

        let planModel = RestoreAwareTestSupport.makePlanModel(harness: harness)
        await planModel.loadProfile()

        guard case .loaded(let state) = planModel.viewState else {
            return XCTFail("Expected loaded plan state, got \(planModel.viewState)")
        }
        XCTAssertFalse(state.header.title.isEmpty)
        XCTAssertNotNil(try harness.profileService.getCurrentProfile())
    }

    func testPlanDoesNotRegressOnboardingRoute() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(cloudUID: nil)
        let planModel = RestoreAwareTestSupport.makePlanModel(harness: harness)

        await planModel.loadProfile()
        XCTAssertEqual(planModel.viewState, .empty)

        let rootState = RootProfileRouteResolver.resolve(hasProfile: false)
        XCTAssertEqual(rootState, .onboarding)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: RestoreAwareTestSupport.ownerUID),
                rootState: rootState,
                isOnboardingModelReady: true
            ),
            .onboarding
        )
        XCTAssertNotEqual(rootState, .main)
    }
}
