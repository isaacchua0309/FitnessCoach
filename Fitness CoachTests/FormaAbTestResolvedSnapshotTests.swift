//
//  FormaAbTestResolvedSnapshotTests.swift
//  Fitness CoachTests
//
//  Forma — Explicit runtime vs production-intent snapshot resolution (PRDX v1).
//

import XCTest
@testable import Fitness_Coach

final class FormaAbTestResolvedSnapshotTests: XCTestCase {

    override func tearDown() {
        FormaAbTest.testOverride = nil
        super.tearDown()
    }

    // MARK: - Environment resolver

    func testDebugRuntimeSnapshotIsAllEnabledCompatible() {
        XCTAssertEqual(
            FormaAbTest.resolvedSnapshot(for: .debug),
            FormaAbTestSnapshot.allEnabled
        )
    }

    func testReleaseRuntimeSnapshotIsAllEnabledCompatible() {
        XCTAssertEqual(
            FormaAbTest.resolvedSnapshot(for: .release),
            FormaAbTestSnapshot.allEnabled
        )
    }

    func testTestRuntimeSnapshotIsAllEnabledCompatible() {
        XCTAssertEqual(
            FormaAbTest.resolvedSnapshot(for: .test),
            FormaAbTestSnapshot.allEnabled
        )
    }

    func testProductionIntentSnapshotMatchesProductionConstant() {
        XCTAssertEqual(
            FormaAbTest.resolvedSnapshot(for: .productionIntent),
            FormaAbTestSnapshot.production
        )
    }

    // MARK: - Live runtime path (unchanged PRDX v1 behavior)

    func testSnapshotMatchesCurrentRuntimeEnvironment() {
        #if DEBUG
        XCTAssertEqual(FormaAbTest.snapshot(), FormaAbTest.resolvedSnapshot(for: .debug))
        #else
        XCTAssertEqual(FormaAbTest.snapshot(), FormaAbTest.resolvedSnapshot(for: .release))
        #endif
    }

    func testSnapshotWithoutOverrideRemainsAllEnabled() {
        XCTAssertNil(FormaAbTest.testOverride)
        XCTAssertEqual(FormaAbTest.snapshot(), FormaAbTestSnapshot.allEnabled)
    }

    func testTestOverrideTakesPrecedenceOverRuntimeEnvironment() {
        var override = FormaAbTestSnapshot.allEnabled
        override.uiEnabled = false
        FormaAbTest.testOverride = override

        XCTAssertEqual(FormaAbTest.snapshot(), override)
        XCTAssertEqual(FormaAbTest.resolvedSnapshot(for: .debug), FormaAbTestSnapshot.allEnabled)
    }
}
