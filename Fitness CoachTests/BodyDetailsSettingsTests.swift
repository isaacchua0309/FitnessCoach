//
//  BodyDetailsSettingsTests.swift
//  Fitness CoachTests
//
//  Forma — Body & stats settings presentation and routing tests.
//

import XCTest
@testable import Fitness_Coach

final class BodyDetailsSettingsTests: XCTestCase {

    private func completeFormState() -> PlanFormState {
        PlanPreviewData.formState
    }

    private func missingValuesFormState() -> PlanFormState {
        var state = PlanFormState.defaultDraftValues()
        state.ageText = ""
        state.heightCmText = ""
        state.currentWeightKgText = ""
        state.sex = .preferNotToSay
        return state
    }

    // MARK: - Complete profile

    func testCompleteProfileShowsAllDetailRows() {
        let presentation = BodyDetailsSettingsPresentationBuilder.build(
            input: BodyDetailsSettingsPresentationInput(formState: completeFormState())
        )

        XCTAssertEqual(presentation.detailRows.map(\.id), [
            "age",
            "height",
            "sex",
            "starting-weight",
            "current-weight",
            "unit-system"
        ])
        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "age" })?.value, "28 years")
        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "sex" })?.value, "Female")
        XCTAssertFalse(presentation.detailRows.contains(where: { $0.value == FormaProductCopy.Settings.BodyDetails.notSetValue }))
    }

    // MARK: - Missing values

    func testMissingValuesShowNotSet() {
        let presentation = BodyDetailsSettingsPresentationBuilder.build(
            input: BodyDetailsSettingsPresentationInput(formState: missingValuesFormState())
        )

        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "age" })?.value, FormaProductCopy.Settings.BodyDetails.notSetValue)
        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "height" })?.value, FormaProductCopy.Settings.BodyDetails.notSetValue)
        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "sex" })?.value, FormaProductCopy.Settings.BodyDetails.notSetValue)
        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "starting-weight" })?.value, FormaProductCopy.Settings.BodyDetails.notSetValue)
        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "current-weight" })?.value, FormaProductCopy.Settings.BodyDetails.notSetValue)
    }

    // MARK: - Unit systems

    func testMetricUnitsFormatBodyValues() {
        let presentation = BodyDetailsSettingsPresentationBuilder.build(
            input: BodyDetailsSettingsPresentationInput(
                formState: completeFormState(),
                startingWeightKg: 90,
                currentWeightKg: 88
            )
        )

        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "height" })?.value, "168 cm")
        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "starting-weight" })?.value, "90 kg")
        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "current-weight" })?.value, "88 kg")
        XCTAssertEqual(
            presentation.detailRows.first(where: { $0.id == "unit-system" })?.value,
            FormaProductCopy.Settings.Units.unitSystemPickerLabel(for: .metric)
        )
    }

    func testImperialUnitsFormatBodyValues() {
        var formState = completeFormState()
        formState.unitSystem = .imperial

        let presentation = BodyDetailsSettingsPresentationBuilder.build(
            input: BodyDetailsSettingsPresentationInput(
                formState: formState,
                startingWeightKg: 90,
                currentWeightKg: 88.2
            )
        )

        XCTAssertEqual(presentation.detailRows.first(where: { $0.id == "height" })?.value, "5 ft 6 in")
        XCTAssertTrue(presentation.detailRows.first(where: { $0.id == "starting-weight" })?.value.contains("lb") ?? false)
        XCTAssertTrue(presentation.detailRows.first(where: { $0.id == "current-weight" })?.value.contains("lb") ?? false)
        XCTAssertEqual(
            presentation.detailRows.first(where: { $0.id == "unit-system" })?.value,
            FormaProductCopy.Settings.Units.unitSystemPickerLabel(for: .imperial)
        )
    }

    // MARK: - Update in Plan route

    func testUpdateInPlanRouteDismissesSettingsAndOpensAdjustPlan() {
        var dismissCalled = false
        var adjustPlanCalled = false

        BodyDetailsSettingsActionHandler.openUpdateInPlan(
            dismissSettings: { dismissCalled = true },
            showAdjustPlan: { adjustPlanCalled = true }
        )

        XCTAssertTrue(dismissCalled)
        XCTAssertTrue(adjustPlanCalled)
    }

    func testPresentationIsReadOnlyWithUpdateInPlanCTA() {
        let presentation = BodyDetailsSettingsPresentationBuilder.build(
            input: BodyDetailsSettingsPresentationInput(formState: completeFormState())
        )

        XCTAssertTrue(presentation.isReadOnly)
        XCTAssertEqual(presentation.updateInPlanCTA, FormaProductCopy.Settings.BodyDetails.updateInPlanCTA)
        XCTAssertEqual(presentation.introCopy, FormaProductCopy.Settings.BodyDetails.introCopy)
    }

    func testStartingAndCurrentWeightCanDiffer() {
        let presentation = BodyDetailsSettingsPresentationBuilder.build(
            input: BodyDetailsSettingsPresentationInput(
                formState: completeFormState(),
                startingWeightKg: 92,
                currentWeightKg: 88.4
            )
        )

        XCTAssertNotEqual(
            presentation.detailRows.first(where: { $0.id == "starting-weight" })?.value,
            presentation.detailRows.first(where: { $0.id == "current-weight" })?.value
        )
    }
}
