//
//  UnitsSettingsTests.swift
//  Fitness CoachTests
//
//  Forma — Units settings presentation and display formatting tests.
//

import XCTest
@testable import Fitness_Coach

final class UnitsSettingsTests: XCTestCase {

    // MARK: - Example rows

    func testMetricExampleRows() {
        let rows = SettingsUnitsDisplayFormatter.exampleRows(for: .metric)

        XCTAssertEqual(rows.map(\.label), ["Weight", "Height", "Water", "Energy"])
        XCTAssertEqual(rows.map(\.unit), ["kg", "cm", "ml", "kcal"])
    }

    func testImperialExampleRows() {
        let rows = SettingsUnitsDisplayFormatter.exampleRows(for: .imperial)

        XCTAssertEqual(rows.map(\.label), ["Weight", "Height", "Water", "Energy"])
        XCTAssertEqual(rows.map(\.unit), ["lb", "ft/in", "fl oz", "kcal"])
    }

    // MARK: - Picker / selection state

    func testPresentationReflectsSelectedUnitSystem() {
        let metric = UnitsSettingsPresentationBuilder.build(
            input: UnitsSettingsPresentationInput(unitSystem: .metric)
        )
        let imperial = UnitsSettingsPresentationBuilder.build(
            input: UnitsSettingsPresentationInput(unitSystem: .imperial)
        )

        XCTAssertEqual(metric.selectedUnitSystem, .metric)
        XCTAssertEqual(imperial.selectedUnitSystem, .imperial)
        XCTAssertNil(metric.imperialDisplayOnlyFootnote)
        XCTAssertNotNil(imperial.imperialDisplayOnlyFootnote)
        XCTAssertTrue(imperial.showsImperialDisplayOnlyFootnote)
    }

    func testPickerChangesState() async {
        await MainActor.run {
            var formState = PlanPreviewData.formState
            XCTAssertEqual(formState.unitSystem, .metric)

            formState.unitSystem = .imperial
            XCTAssertEqual(formState.unitSystem, .imperial)

            let presentation = UnitsSettingsPresentationBuilder.build(
                input: UnitsSettingsPresentationInput(unitSystem: formState.unitSystem)
            )
            XCTAssertEqual(
                presentation.pickerLabel(for: .imperial),
                FormaProductCopy.Settings.Units.unitSystemPickerLabel(for: .imperial)
            )
            XCTAssertEqual(presentation.exampleRows.first(where: { $0.id == "weight" })?.unit, "lb")
        }
    }

    // MARK: - Main Settings row

    func testMainSettingsRowStatusUpdatesForMetric() {
        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertEqual(
            state.preferences.rows.first(where: { $0.id == .units })?.status,
            SettingsRowStatusFormatter.unitSystem(.metric)
        )
        XCTAssertEqual(
            state.preferences.rows.first(where: { $0.id == .units })?.status,
            FormaProductCopy.Settings.Status.metric
        )
    }

    func testMainSettingsRowStatusUpdatesForImperial() {
        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .imperial,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertEqual(
            state.preferences.rows.first(where: { $0.id == .units })?.status,
            SettingsRowStatusFormatter.unitSystem(.imperial)
        )
        XCTAssertEqual(
            state.preferences.rows.first(where: { $0.id == .units })?.status,
            FormaProductCopy.Settings.Status.imperial
        )
    }

    // MARK: - Body & stats display

    func testBodyDetailsValuesUseMetricUnits() {
        let height = SettingsUnitsDisplayFormatter.formatHeight(
            fromMetricCmText: "168",
            unitSystem: .metric
        )
        let weight = SettingsUnitsDisplayFormatter.formatWeight(
            fromMetricKgText: "90",
            unitSystem: .metric
        )

        XCTAssertEqual(height, "168 cm")
        XCTAssertEqual(weight, "90 kg")
    }

    func testBodyDetailsValuesUseImperialUnits() {
        let height = SettingsUnitsDisplayFormatter.formatHeight(
            fromMetricCmText: "168",
            unitSystem: .imperial
        )
        let weight = SettingsUnitsDisplayFormatter.formatWeight(
            fromMetricKgText: "90",
            unitSystem: .imperial
        )

        XCTAssertEqual(height, "5 ft 6 in")
        XCTAssertTrue(weight.contains("lb"))
        XCTAssertFalse(weight.contains("kg"))
    }

    func testBodyDetailsWaterUsesImperialFluidOuncesWhenSupported() {
        let water = SettingsUnitsDisplayFormatter.formatWater(
            fromMetricMlText: "2957",
            unitSystem: .imperial
        )

        XCTAssertTrue(water.contains("fl oz"))
        XCTAssertFalse(water.contains("ml"))
    }

    func testUnitsPresentationIncludesStorageFootnote() {
        let presentation = UnitsSettingsPresentationBuilder.build(
            input: UnitsSettingsPresentationInput(unitSystem: .metric)
        )

        XCTAssertEqual(
            presentation.storageFootnote,
            FormaProductCopy.Settings.Units.storageFootnote
        )
    }
}
