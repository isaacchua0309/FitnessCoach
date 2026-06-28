//
//  OnboardingComponentsTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for onboarding reusable components.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingComponentsTests: XCTestCase {

    // MARK: - Ruler math

    func testRulerMathBuildValuesUsesStep() {
        let values = OnboardingRulerMath.buildValues(in: 70...72, step: 0.5)
        XCTAssertEqual(values, [70, 70.5, 71, 71.5, 72])
    }

    func testRulerMathIndexFindsNearestValue() {
        let values = OnboardingRulerMath.buildValues(in: 70...72, step: 0.5)
        XCTAssertEqual(OnboardingRulerMath.index(for: 71.2, in: values), 2)
        XCTAssertEqual(OnboardingRulerMath.index(for: 71.8, in: values), 4)
    }

    func testRulerMathSnapValue() {
        let values = OnboardingRulerMath.buildValues(in: 70...72, step: 0.5)
        XCTAssertEqual(OnboardingRulerMath.snapValue(71.24, in: values), 71)
        XCTAssertEqual(OnboardingRulerMath.snapValue(71.26, in: values), 71.5)
    }

    func testRulerMathClampedIndex() {
        XCTAssertEqual(OnboardingRulerMath.clampedIndex(-3, count: 5), 0)
        XCTAssertEqual(OnboardingRulerMath.clampedIndex(99, count: 5), 4)
        XCTAssertEqual(OnboardingRulerMath.clampedIndex(2, count: 5), 2)
    }

    func testRulerMathAccessibilityLabelIncludesUnit() {
        let label = OnboardingRulerMath.accessibilityValueLabel(
            value: 72,
            unitLabel: "kg",
            formatter: { "\(Int($0))" }
        )
        XCTAssertEqual(label, "72 kg")
    }

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
        let copyBullets = FormaProductCopy.Onboarding.Flow.AlmostThereFeatures.bullets

        XCTAssertEqual(bullets.count, 4)
        XCTAssertEqual(bullets.count, copyBullets.count)
        zip(bullets, copyBullets).forEach { bullet, copy in
            XCTAssertEqual(bullet.icon, copy.icon)
            XCTAssertEqual(bullet.title, copy.title)
            XCTAssertEqual(bullet.subtitle, copy.subtitle)
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
        let copy = FormaProductCopy.Onboarding.Flow.Proof.WeightLossComparison.self

        XCTAssertEqual(model.withoutFormaValue, copy.withoutFormaValue)
        XCTAssertEqual(model.withFormaValue, copy.withFormaValue)
        XCTAssertEqual(model.disclaimer, copy.disclaimer)
    }

    func testTrajectoryComparisonModelUsesIntroProofCopy() {
        let model = OnboardingWeightTrajectoryComparisonModel.introProofDefault
        let intro = FormaProductCopy.Onboarding.Flow.IntroProof.self
        let trajectory = FormaProductCopy.Onboarding.Flow.Proof.TrajectoryComparison.self

        XCTAssertEqual(model.caption, intro.caption)
        XCTAssertEqual(model.formaLabel, trajectory.formaLabel)
        XCTAssertEqual(model.traditionalLabel, trajectory.traditionalLabel)
        XCTAssertEqual(model.formaDescription, trajectory.formaDescription)
        XCTAssertEqual(model.traditionalDescription, trajectory.traditionalDescription)
        XCTAssertEqual(model.disclaimer, trajectory.disclaimer)
        XCTAssertEqual(model.chartAccessibilityLabel, trajectory.chartAccessibilityLabel)
        XCTAssertEqual(model.formaSeries.count, 5)
        XCTAssertEqual(model.traditionalSeries.count, 5)
    }

    func testIntroProofStepCopyMatchesProductConstants() {
        let step = OnboardingStep.introProof
        let copy = FormaProductCopy.Onboarding.Flow.IntroProof.self

        XCTAssertEqual(step.title, copy.title)
        XCTAssertEqual(step.subtitle, copy.subtitle)
    }
}
