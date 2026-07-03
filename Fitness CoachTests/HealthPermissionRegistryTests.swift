//
//  HealthPermissionRegistryTests.swift
//  Fitness CoachTests
//

import XCTest
#if canImport(HealthKit) && os(iOS)
import HealthKit
#endif
@testable import Fitness_Coach

final class HealthPermissionRegistryTests: XCTestCase {

    func testRequiredSignalsMatchProductSpec() {
        let required = Set(HealthSignalKind.required)
        XCTAssertTrue(required.contains(.stepCount))
        XCTAssertTrue(required.contains(.activeEnergyBurned))
        XCTAssertTrue(required.contains(.appleExerciseTime))
        XCTAssertTrue(required.contains(.workout))
        XCTAssertTrue(required.contains(.restingHeartRate))
        XCTAssertTrue(required.contains(.heartRateVariabilitySDNN))
        XCTAssertTrue(required.contains(.sleepAnalysis))
        XCTAssertTrue(required.contains(.bodyMass))
        XCTAssertEqual(required.count, 8)
    }

    func testFutureOptionalSignalsAreDeclaredButNotDefaultRequested() {
        let future = Set(HealthSignalKind.futureOptional)
        let defaultRequested = Set(HealthKitReadTypeRegistry.defaultRequestedSignals)

        XCTAssertTrue(future.contains(.walkingHeartRateAverage))
        XCTAssertTrue(future.contains(.vo2Max))
        XCTAssertTrue(future.contains(.distanceWalkingRunning))
        XCTAssertTrue(future.contains(.appleStandTime))
        XCTAssertTrue(defaultRequested.isDisjoint(with: future))
    }

    func testRequestedSignalsIncludesFutureOnlyWhenRequested() {
        let defaultSignals = HealthKitReadTypeRegistry.requestedSignals(includingFutureTypes: false)
        let expandedSignals = HealthKitReadTypeRegistry.requestedSignals(includingFutureTypes: true)

        XCTAssertEqual(defaultSignals, HealthSignalKind.required)
        XCTAssertEqual(expandedSignals.count, HealthSignalKind.required.count + HealthSignalKind.futureOptional.count)
    }

    func testHealthPermissionStatusTrainingAccessRequiresWorkoutOrSteps() {
        let stepsOnly = HealthPermissionStatus.uniform(
            .denied,
            isHealthDataAvailable: true,
            signals: HealthSignalKind.allCases
        )
        var access = stepsOnly.signalAccess
        access[.stepCount] = .available
        let status = HealthPermissionStatus(
            isHealthDataAvailable: true,
            signalAccess: access,
            resolvedAt: Date()
        )
        XCTAssertTrue(status.hasTrainingReadAccess)

        let neither = HealthPermissionStatus.uniform(
            .denied,
            isHealthDataAvailable: true,
            signals: HealthSignalKind.required
        )
        XCTAssertFalse(neither.hasTrainingReadAccess)
    }

    func testHealthShareUsageDescriptionMentionsRequiredCategories() throws {
        let copy = HealthPermissionCopy.healthShareUsageDescription.lowercased()
        XCTAssertTrue(copy.contains("step"))
        XCTAssertTrue(copy.contains("workout"))
        XCTAssertTrue(copy.contains("sleep"))
        XCTAssertTrue(copy.contains("heart"))
        XCTAssertTrue(copy.contains("weight"))
    }

    func testProjectHealthShareUsageDescriptionMentionsExpandedSignals() throws {
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fitness Coach.xcodeproj/project.pbxproj")
        let projectContents = try String(contentsOf: projectURL, encoding: .utf8).lowercased()

        XCTAssertTrue(projectContents.contains("sleep"))
        XCTAssertTrue(projectContents.contains("heart"))
        XCTAssertTrue(projectContents.contains("weight"))
        XCTAssertFalse(projectContents.contains("infoPlist_key_nshealthupdateusagedescription"))
    }

    #if canImport(HealthKit) && os(iOS)
    func testDefaultReadTypesIncludeWorkoutAndSteps() {
        XCTAssertFalse(HealthKitReadTypeRegistry.defaultReadTypes.isEmpty)
        XCTAssertTrue(HealthKitReadTypeRegistry.defaultReadTypes.contains(HKObjectType.workoutType()))
        XCTAssertTrue(HealthKitReadTypeRegistry.writeTypes.isEmpty)
    }
    #endif
}
