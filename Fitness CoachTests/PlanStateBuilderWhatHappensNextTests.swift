//
//  PlanStateBuilderWhatHappensNextTests.swift
//  Fitness CoachTests
//
//  Forma — Tests for “What happens next” copy.
//

import XCTest
@testable import Fitness_Coach

final class PlanStateBuilderWhatHappensNextTests: XCTestCase {

    func testAggressiveCutShowsFocusCheckpointAndLikelyMaintenance() {
        let profile = ProfilePreviewData.profile
        let state = PlanStateBuilder.dashboardState(profile: profile).whatHappensNext

        XCTAssertEqual(state.currentPhaseName, "Aggressive Cut")
        XCTAssertEqual(state.currentPhaseFocus, FormaProductCopy.WhatHappensNext.cutFocus)
        XCTAssertEqual(state.nextCheckpoint, FormaProductCopy.WhatHappensNext.defaultCheckpoint)
        XCTAssertEqual(state.likelyNextStepName, "Maintenance")
        XCTAssertEqual(state.likelyNextStepDetail, FormaProductCopy.WhatHappensNext.maintenanceNextStep)
    }

    func testMaintenanceShowsLeanBulkAsLikelyNextStep() {
        var profile = ProfilePreviewData.profile
        profile.currentWeightKg = 75
        profile.goalWeightKg = 75

        let state = PlanStateBuilder.dashboardState(profile: profile).whatHappensNext

        XCTAssertEqual(state.currentPhaseName, "Maintenance")
        XCTAssertEqual(state.currentPhaseFocus, FormaProductCopy.WhatHappensNext.maintenanceFocus)
        XCTAssertEqual(state.likelyNextStepName, "Lean Bulk")
        XCTAssertEqual(state.likelyNextStepDetail, FormaProductCopy.WhatHappensNext.leanBulkNextStep)
    }

    func testBuildPhaseShowsMiniCutAsLikelyNextStep() {
        var profile = ProfilePreviewData.profile
        profile.currentWeightKg = 70
        profile.goalWeightKg = 78
        profile.targets.aggressiveness = .moderate

        let state = PlanStateBuilder.dashboardState(profile: profile).whatHappensNext

        XCTAssertEqual(state.currentPhaseName, "Moderate Build")
        XCTAssertEqual(state.currentPhaseFocus, FormaProductCopy.WhatHappensNext.buildFocus)
        XCTAssertEqual(state.likelyNextStepName, "Mini Cut")
        XCTAssertEqual(state.likelyNextStepDetail, FormaProductCopy.WhatHappensNext.miniCutNextStep)
    }
}
