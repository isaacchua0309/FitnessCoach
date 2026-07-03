//
//  HealthPermissionStatusTests.swift
//  Fitness CoachTests
//
//  Phase 16–18 — HealthPermissionStatus semantics and permission display mapping.
//

import XCTest
@testable import Fitness_Coach

final class HealthPermissionStatusTests: XCTestCase {

    private var resolvedAt: Date {
        HealthIntelligencePhase1618TestSupport.referenceNow()
    }

    // MARK: - Aggregated permission semantics

    func testFullPermissionGrantsTrainingAndRequiredSignals() {
        let status = HealthIntelligencePhase1618TestSupport.permissionStatus(.full, resolvedAt: resolvedAt)

        XCTAssertTrue(status.isHealthDataAvailable)
        XCTAssertTrue(status.hasTrainingReadAccess)
        XCTAssertTrue(status.hasAnyAvailableReadAccess)
        XCTAssertTrue(status.allRequiredSignalsAvailable)
        XCTAssertFalse(status.anyRequiredSignalDenied)
        XCTAssertEqual(status.availableSignals, Set(HealthSignalKind.required))
        XCTAssertTrue(status.deniedSignals.isEmpty)
    }

    func testPartialPermissionAllowsReadableSubset() {
        let status = HealthIntelligencePhase1618TestSupport.permissionStatus(.partialStepsOnly, resolvedAt: resolvedAt)

        XCTAssertTrue(status.hasTrainingReadAccess)
        XCTAssertTrue(status.hasAnyAvailableReadAccess)
        XCTAssertFalse(status.allRequiredSignalsAvailable)
        XCTAssertTrue(status.anyRequiredSignalDenied)
        XCTAssertEqual(status.availableSignals, [.stepCount])
    }

    func testDeniedPermissionBlocksReadableAccess() {
        let status = HealthIntelligencePhase1618TestSupport.permissionStatus(.denied, resolvedAt: resolvedAt)

        XCTAssertTrue(status.isHealthDataAvailable)
        XCTAssertFalse(status.hasTrainingReadAccess)
        XCTAssertFalse(status.hasAnyAvailableReadAccess)
        XCTAssertFalse(status.allRequiredSignalsAvailable)
        XCTAssertTrue(status.anyRequiredSignalDenied)
        XCTAssertEqual(status.deniedSignals, Set(HealthSignalKind.required))
    }

    func testUnavailablePermissionMarksHealthDataUnavailable() {
        let status = HealthIntelligencePhase1618TestSupport.permissionStatus(.unavailable, resolvedAt: resolvedAt)

        XCTAssertFalse(status.isHealthDataAvailable)
        XCTAssertFalse(status.hasTrainingReadAccess)
        XCTAssertFalse(status.hasAnyAvailableReadAccess)
        XCTAssertFalse(status.allRequiredSignalsAvailable)
        XCTAssertFalse(status.anyRequiredSignalDenied)
        XCTAssertTrue(status.availableSignals.isEmpty)
        XCTAssertTrue(
            HealthSignalKind.allCases.allSatisfy { status.access(for: $0) == .unavailable }
        )
    }

    func testUnknownPermissionIsNotReadable() {
        let status = HealthIntelligencePhase1618TestSupport.permissionStatus(.unknown, resolvedAt: resolvedAt)

        XCTAssertTrue(status.isHealthDataAvailable)
        XCTAssertFalse(status.hasTrainingReadAccess)
        XCTAssertFalse(status.hasAnyAvailableReadAccess)
        XCTAssertFalse(status.allRequiredSignalsAvailable)
        XCTAssertFalse(status.anyRequiredSignalDenied)
        XCTAssertTrue(status.availableSignals.isEmpty)
    }

    func testWorkoutsOnlyPermissionGrantsTrainingAccessWithoutSteps() {
        let status = HealthIntelligencePhase1618TestSupport.permissionStatus(.partialWorkoutsOnly, resolvedAt: resolvedAt)

        XCTAssertTrue(status.hasTrainingReadAccess)
        XCTAssertTrue(status.access(for: .workout).isReadable)
        XCTAssertFalse(status.access(for: .stepCount).isReadable)
    }

    // MARK: - Display model mapping

    func testDisplayModelsReflectFullPermissionAsConnected() {
        let models = HealthPermissionDisplayModelBuilder.makeAll(
            from: HealthIntelligencePhase1618TestSupport.permissionStatus(.full, resolvedAt: resolvedAt)
        )

        XCTAssertEqual(models.count, HealthPermissionCategory.displayCategories.count)
        XCTAssertTrue(models.allSatisfy { $0.status == .connected })
        XCTAssertTrue(models.allSatisfy(\.isConnected))
    }

    func testDisplayModelsReflectPartialPermissionMix() {
        let status = HealthIntelligencePhase1618TestSupport.permissionStatus(.partialStepsAndWorkouts, resolvedAt: resolvedAt)
        let models = HealthPermissionDisplayModelBuilder.makeAll(from: status)

        let steps = models.first { $0.category == .steps }
        let workouts = models.first { $0.category == .workouts }
        let sleep = models.first { $0.category == .sleep }

        XCTAssertEqual(steps?.status, .connected)
        XCTAssertEqual(workouts?.status, .connected)
        XCTAssertEqual(sleep?.status, .denied)
    }

    func testDisplayModelsReflectDeniedPermission() {
        let models = HealthPermissionDisplayModelBuilder.makeAll(
            from: HealthIntelligencePhase1618TestSupport.permissionStatus(.denied, resolvedAt: resolvedAt)
        )

        XCTAssertTrue(models.allSatisfy { $0.status == .denied })
        XCTAssertTrue(models.allSatisfy { !$0.isConnected })
    }

    func testDisplayModelsReflectUnavailableDevice() {
        let models = HealthPermissionDisplayModelBuilder.makeAll(
            from: HealthIntelligencePhase1618TestSupport.permissionStatus(.unavailable, resolvedAt: resolvedAt)
        )

        XCTAssertTrue(models.allSatisfy { $0.status == .unavailable })
    }

    func testDisplayModelsReflectUnknownAccessAsUnknownStatus() {
        let models = HealthPermissionDisplayModelBuilder.makeAll(
            from: HealthIntelligencePhase1618TestSupport.permissionStatus(.unknown, resolvedAt: resolvedAt)
        )

        XCTAssertTrue(models.allSatisfy { $0.status == .unknown })
    }

    // MARK: - Settings presentation aggregation

    func testSettingsPresentationMapsFullPartialDeniedUnavailableAndUnknown() {
        assertConnectionStatus(
            preset: .full,
            integrationState: .connected,
            expectedLabel: FormaProductCopy.Settings.AppleHealth.statusConnected,
            isConnectedLike: true
        )
        assertConnectionStatus(
            preset: .partialStepsOnly,
            integrationState: .connected,
            expectedLabel: FormaProductCopy.Settings.AppleHealth.statusPartiallyConnected,
            isConnectedLike: true
        )
        assertConnectionStatus(
            preset: .denied,
            integrationState: .connected,
            expectedLabel: FormaProductCopy.Settings.AppleHealth.statusPermissionNeeded,
            isConnectedLike: false
        )
        assertConnectionStatus(
            preset: .unavailable,
            integrationState: .connected,
            expectedLabel: FormaProductCopy.Settings.AppleHealth.statusUnavailable,
            isConnectedLike: false
        )
    }

    // MARK: - Helpers

    private func assertConnectionStatus(
        preset: HealthIntelligencePhase1618PermissionPreset,
        integrationState: TrainingIntegrationState,
        expectedLabel: String,
        isConnectedLike: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let permission = HealthIntelligencePhase1618TestSupport.permissionStatus(preset, resolvedAt: resolvedAt)
        let status = AppleHealthSettingsPresentationBuilder.overallConnectionStatus(
            integrationState: integrationState,
            permissionStatus: permission,
            isHealthDataAvailable: permission.isHealthDataAvailable
        )

        XCTAssertEqual(status.label, expectedLabel, file: file, line: line)
        XCTAssertEqual(status.isConnectedLike, isConnectedLike, file: file, line: line)
    }
}
