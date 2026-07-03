//
//  HealthPermissionDisplayModelTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthPermissionDisplayModelTests: XCTestCase {

    private let requiredCategories: Set<HealthPermissionCategory> = [
        .steps, .workouts, .activeEnergy, .exerciseMinutes
    ]

    private let optionalCategories: Set<HealthPermissionCategory> = [
        .sleep, .restingHeartRate, .hrv, .weight
    ]

    func testDisplayCategoriesCoverAllRequiredKinds() {
        XCTAssertEqual(HealthPermissionCategory.displayCategories.count, 8)
        XCTAssertEqual(Set(HealthPermissionCategory.allCases), requiredCategories.union(optionalCategories))
    }

    func testCategorySignalKindRoundTrip() {
        for category in HealthPermissionCategory.allCases {
            XCTAssertEqual(HealthPermissionCategory(signalKind: category.signalKind), category)
        }
    }

    func testFutureSignalsDoNotMapToDisplayCategories() {
        for signal in HealthSignalKind.futureOptional {
            XCTAssertNil(HealthPermissionCategory(signalKind: signal))
        }
    }

    func testPrivacyPrinciplesIncludeRequiredStatements() {
        let bullets = HealthPrivacyCopy.Principles.overviewBullets.joined(separator: " ").lowercased()

        XCTAssertTrue(bullets.contains("personalize coaching"))
        XCTAssertTrue(bullets.contains("only after"))
        XCTAssertTrue(bullets.contains("does not sell"))
        XCTAssertTrue(bullets.contains("revoke access"))
        XCTAssertTrue(bullets.contains("limited"))
        XCTAssertTrue(bullets.contains("raw healthkit samples are not uploaded"))
        XCTAssertTrue(bullets.contains("normalized summaries"))
    }

    func testCategoryDefinitionsMatchRequirementLevels() {
        for category in HealthPermissionCategory.allCases {
            let definition = HealthPrivacyCopy.definition(for: category)

            XCTAssertFalse(definition.title.isEmpty)
            XCTAssertFalse(definition.explanation.isEmpty)
            XCTAssertFalse(definition.whyFormaUsesIt.isEmpty)
            XCTAssertEqual(definition.category, category)

            if requiredCategories.contains(category) {
                XCTAssertEqual(definition.requirement, .required)
            } else {
                XCTAssertEqual(definition.requirement, .optional)
            }
        }
    }

    func testDisplayStatusMapsFromSignalAccess() {
        XCTAssertEqual(
            HealthPermissionDisplayStatus(access: .available, isHealthDataAvailable: true),
            .connected
        )
        XCTAssertEqual(
            HealthPermissionDisplayStatus(access: .denied, isHealthDataAvailable: true),
            .denied
        )
        XCTAssertEqual(
            HealthPermissionDisplayStatus(access: .notDetermined, isHealthDataAvailable: true),
            .notDetermined
        )
        XCTAssertEqual(
            HealthPermissionDisplayStatus(access: .unavailable, isHealthDataAvailable: true),
            .unavailable
        )
        XCTAssertEqual(
            HealthPermissionDisplayStatus(access: .unknown, isHealthDataAvailable: true),
            .unknown
        )
        XCTAssertEqual(
            HealthPermissionDisplayStatus(access: .available, isHealthDataAvailable: false),
            .unavailable
        )
    }

    func testStatusCopyCoversPrimaryStates() {
        let title = "Steps"

        for status in [HealthPermissionDisplayStatus.connected,
                       .unavailable,
                       .denied,
                       .notDetermined] {
            let label = HealthPrivacyCopy.Status.label(for: status, categoryTitle: title)
            let detail = HealthPrivacyCopy.Status.detail(for: status, categoryTitle: title)

            XCTAssertFalse(label.isEmpty)
            XCTAssertFalse(detail.isEmpty)
            XCTAssertFalse(detail.lowercased().contains("diagnos"))
            XCTAssertFalse(detail.lowercased().contains("medical"))
        }
    }

    func testBuilderProducesRowForEachCategory() {
        let status = HealthPermissionStatus.uniform(.available, isHealthDataAvailable: true)
        let models = HealthPermissionDisplayModelBuilder.makeAll(from: status)

        XCTAssertEqual(models.count, 8)
        XCTAssertTrue(models.allSatisfy(\.isConnected))
        XCTAssertEqual(Set(models.map(\.category)), Set(HealthPermissionCategory.allCases))
    }

    func testBuilderReflectsDeniedAccess() {
        let model = HealthPermissionDisplayModelBuilder.make(
            category: .sleep,
            access: .denied,
            isHealthDataAvailable: true
        )

        XCTAssertEqual(model.status, .denied)
        XCTAssertEqual(model.statusLabel, "Access off")
        XCTAssertTrue(model.statusDetail.contains("Health app"))
        XCTAssertEqual(model.requirement, .optional)
    }

    func testDisplayModelExposesPrivacyOverview() {
        XCTAssertEqual(
            HealthPermissionDisplayModel.privacyOverviewBullets,
            HealthPrivacyCopy.Principles.overviewBullets
        )
        XCTAssertFalse(HealthPermissionDisplayModel.privacyOverviewAccessibilityLabel.isEmpty)
    }
}
