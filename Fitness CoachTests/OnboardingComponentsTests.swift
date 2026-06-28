//
//  OnboardingComponentsTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for onboarding reusable components.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingComponentsTests: XCTestCase {

    // MARK: - Birthday wheel factory

    func testBirthdayWheelFactoryYearRangeRespectsAgeBounds() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 28
        let reference = calendar.date(from: components)!

        let columns = OnboardingBirthdayWheelFactory.columns(referenceDate: reference, calendar: calendar)
        let years = columns.year.values

        XCTAssertEqual(years.first, 2026 - BirthDateAgeResolver.maximumAge)
        XCTAssertEqual(years.last, 2026 - BirthDateAgeResolver.minimumAge)
        XCTAssertEqual(columns.month.values.count, 12)
        XCTAssertEqual(columns.day.values.count, 31)
    }

    func testBirthdayWheelFactoryComposesValidDate() {
        let calendar = Calendar(identifier: .gregorian)
        let date = OnboardingBirthdayWheelFactory.birthDate(month: 3, day: 15, year: 1990, calendar: calendar)

        XCTAssertNotNil(date)
        XCTAssertEqual(calendar.component(.month, from: date!), 3)
        XCTAssertEqual(calendar.component(.day, from: date!), 15)
        XCTAssertEqual(calendar.component(.year, from: date!), 1990)
    }

    // MARK: - Feature bullets / copy wiring

    func testIntroProofBulletsMapFromProductCopy() {
        let bullets = OnboardingFeatureBullet.introProofDefaults
        let copyBullets = FormaProductCopy.Onboarding.Flow.IntroProofFeatures.bullets

        XCTAssertEqual(bullets.count, copyBullets.count)
        zip(bullets, copyBullets).forEach { bullet, copy in
            XCTAssertEqual(bullet.icon, copy.icon)
            XCTAssertEqual(bullet.title, copy.title)
            XCTAssertEqual(bullet.subtitle, copy.subtitle)
        }
    }

    func testAlmostThereBulletsMapFromProductCopy() {
        let bullets = OnboardingFeatureBullet.almostThereDefaults
        let copyItems = FormaProductCopy.Onboarding.Flow.AlmostThereBenefits.items

        XCTAssertEqual(bullets.count, 3)
        XCTAssertEqual(bullets.count, copyItems.count)
        zip(bullets, copyItems).forEach { bullet, copy in
            XCTAssertEqual(bullet.icon, copy.icon)
            XCTAssertEqual(bullet.title, copy.title)
        }
    }

    // MARK: - Proof card models

    func testWeightMaintenanceProofModelUsesCopyNotHardcodedClaims() {
        let model = OnboardingWeightMaintenanceProofModel.introDefault
        let copy = FormaProductCopy.Onboarding.Flow.Proof.WeightMaintenance.self

        XCTAssertEqual(model.title, copy.title)
        XCTAssertEqual(model.subtitle, copy.subtitle)
        XCTAssertEqual(model.caption, copy.caption)
        XCTAssertEqual(model.yAxisLabel, copy.yAxisLabel)
        XCTAssertEqual(model.points.count, 4)
    }

    func testComparisonBarProofModelUsesCopyNotHardcodedClaims() {
        let model = OnboardingComparisonBarProofModel.introDefault
        let copy = FormaProductCopy.Onboarding.Flow.Proof.Comparison.self

        XCTAssertEqual(model.title, copy.title)
        XCTAssertEqual(model.subtitle, copy.subtitle)
        XCTAssertEqual(model.metricLabel, copy.metricLabel)
        XCTAssertEqual(model.formaLabel, copy.formaLabel)
        XCTAssertEqual(model.typicalLabel, copy.typicalLabel)
        XCTAssertEqual(model.formaValueLabel, copy.formaValueLabel)
        XCTAssertEqual(model.typicalValueLabel, copy.typicalValueLabel)
    }

    func testFormaProofComparisonModelUsesCopyNotHardcodedClaims() {
        let model = OnboardingFormaProofComparisonModel.default
        let comparison = FormaProductCopy.Onboarding.Flow.FormaProof.Comparison.self
        let disclaimer = FormaProductCopy.Onboarding.Flow.Proof.WeightLossComparison.disclaimer

        XCTAssertEqual(model.withoutFormaLabel, comparison.withoutStructureTitle)
        XCTAssertEqual(model.withFormaLabel, comparison.withFormaTitle)
        XCTAssertEqual(model.withoutFormaValue, comparison.withoutBullets[0])
        XCTAssertEqual(model.withFormaValue, comparison.withFormaBullets[0])
        XCTAssertEqual(model.disclaimer, disclaimer)
    }

    func testTrajectoryComparisonModelUsesIntroProofCopy() {
        let model = OnboardingWeightTrajectoryComparisonModel.introProofDefault
        let intro = FormaProductCopy.Onboarding.Flow.IntroProof.self
        let trajectory = FormaProductCopy.Onboarding.Flow.Proof.TrajectoryComparison.self

        XCTAssertEqual(model.takeaway, intro.takeaway)
        XCTAssertEqual(model.formaLabel, trajectory.formaLabel)
        XCTAssertEqual(model.traditionalLabel, trajectory.traditionalLabel)
        XCTAssertEqual(model.disclaimer, trajectory.disclaimer)
        XCTAssertEqual(model.chartAccessibilityLabel, trajectory.chartAccessibilityLabel)
        XCTAssertEqual(model.formaSeries.count, 5)
        XCTAssertEqual(model.traditionalSeries.count, 5)
    }

    func testTrajectoryComparisonChartYAxisDomainFocusesOnDataRange() {
        let model = OnboardingWeightTrajectoryComparisonModel.introProofDefault
        let domain = OnboardingWeightTrajectoryChartLayout.yAxisDomain(
            formaSeries: model.formaSeries,
            traditionalSeries: model.traditionalSeries
        )

        let weights = (model.formaSeries + model.traditionalSeries).map(\.weightKg)
        let minWeight = weights.min()!
        let maxWeight = weights.max()!

        XCTAssertGreaterThan(domain.lowerBound, minWeight - 5)
        XCTAssertLessThan(domain.lowerBound, minWeight)
        XCTAssertGreaterThan(domain.upperBound, maxWeight)
        XCTAssertLessThan(domain.upperBound, maxWeight + 5)
        XCTAssertFalse(domain.contains(0), "Y-axis should not anchor at zero for illustrative weight trajectories")
    }

    func testIntroProofStepCopyMatchesProductConstants() {
        let step = OnboardingStep.introProof
        let copy = FormaProductCopy.Onboarding.Flow.IntroProof.self

        XCTAssertEqual(step.title, copy.title)
        XCTAssertEqual(step.subtitle, copy.subtitle)
        XCTAssertEqual(copy.takeaway, "Small consistent habits beat restrictive dieting.")
    }
}
