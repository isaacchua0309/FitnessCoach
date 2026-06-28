//
//  OnboardingBirthdayAgePreviewBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Birthday age preview builder tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingBirthdayAgePreviewBuilderTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!
    }

    func testAgePreviewShowsDerivedAge() {
        var state = OnboardingFormState()
        state.birthDate = calendar.date(from: DateComponents(year: 1998, month: 6, day: 28))!

        let preview = OnboardingBirthdayAgePreviewBuilder.build(
            from: state,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(preview.headline, "You're 28")
        XCTAssertFalse(preview.isPlaceholder)
        XCTAssertTrue(preview.accessibilityLabel.contains("Age 28"))
    }

    func testAgePreviewPlaceholderWhenBirthdayMissing() {
        let preview = OnboardingBirthdayAgePreviewBuilder.build(from: OnboardingFormState())

        XCTAssertEqual(
            preview.headline,
            FormaProductCopy.Onboarding.Flow.Birthday.agePreviewPlaceholder
        )
        XCTAssertTrue(preview.isPlaceholder)
    }

    func testVoiceOverSummaryIncludesSexSelectionState() {
        var state = OnboardingFormState()
        state.birthDate = calendar.date(from: DateComponents(year: 1998, month: 6, day: 28))!
        state.sex = .female

        let summary = OnboardingBirthdayAgePreviewBuilder.voiceOverSummary(
            from: state,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertTrue(summary.contains("Age 28"))
        XCTAssertTrue(summary.contains("Female selected"))
    }

    func testVoiceOverSummaryReportsSexNotSelected() {
        var state = OnboardingFormState()
        state.birthDate = calendar.date(from: DateComponents(year: 1998, month: 6, day: 28))!

        let summary = OnboardingBirthdayAgePreviewBuilder.voiceOverSummary(
            from: state,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertTrue(summary.contains("not selected"))
    }
}
