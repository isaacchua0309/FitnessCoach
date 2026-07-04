//
//  SettingsDeveloperTests.swift
//  Fitness CoachTests
//
//  Forma — Developer settings section gating tests.
//

import XCTest
@testable import Fitness_Coach

final class SettingsDeveloperTests: XCTestCase {

    // MARK: - Section visibility

    func testDeveloperSectionHiddenInProductionConfig() {
        let section = SettingsDeveloperPresentationBuilder.buildSection(isVisible: false)

        XCTAssertNil(section)

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertNil(state.developer)
        XCTAssertFalse(state.visibleRowIDs.contains(.authDiagnostics))
        XCTAssertFalse(state.visibleRowIDs.contains(.pipelineTraces))
    }

    func testDeveloperSectionVisibleInDebugConfig() {
        let section = SettingsDeveloperPresentationBuilder.buildSection(isVisible: true)

        XCTAssertNotNil(section)
        XCTAssertEqual(section?.rows.map(\.id), [.authDiagnostics, .pipelineTraces, .healthIntelligenceSnapshot])
        XCTAssertEqual(section?.footer, FormaProductCopy.Settings.Developer.sectionFooter)

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: true
            )
        )

        XCTAssertNotNil(state.developer)
        XCTAssertTrue(state.isDebugOrInternalBuild)
    }

    func testInternalBuildFlagReadsFromAbTest() {
        XCTAssertTrue(FormaBuildConfiguration.internalBuildFlag(from: bundle(internalBuildFlag: "1")))
        XCTAssertTrue(FormaBuildConfiguration.internalBuildFlag(from: bundle(internalBuildFlag: "0")))
        XCTAssertTrue(FormaBuildConfiguration.internalBuildFlag(from: bundle(internalBuildFlag: nil)))
        XCTAssertTrue(FormaAbTest.Build.internalBuildEnabled)
    }

    // MARK: - Routes

    func testDeveloperRoutesAreNavigableInDebugConfig() {
        let section = SettingsDeveloperPresentationBuilder.buildSection(isVisible: true)
        let authRow = section?.rows.first(where: { $0.id == .authDiagnostics })
        let pipelineRow = section?.rows.first(where: { $0.id == .pipelineTraces })
        let healthRow = section?.rows.first(where: { $0.id == .healthIntelligenceSnapshot })

        XCTAssertEqual(authRow?.destination, .authDiagnostics)
        XCTAssertEqual(pipelineRow?.destination, .pipelineTraces)
        XCTAssertEqual(healthRow?.destination, .healthIntelligenceSnapshot)
        XCTAssertTrue(authRow?.isNavigable ?? false)
        XCTAssertTrue(pipelineRow?.isNavigable ?? false)
        XCTAssertTrue(healthRow?.isNavigable ?? false)
    }

    func testCompiledDeveloperToolsEnabledByAbTest() {
        XCTAssertTrue(FormaBuildConfiguration.includesCompiledDeveloperTools)
        XCTAssertTrue(FormaAbTest.Build.includesDeveloperTools)
    }

    // MARK: - Helpers

    private func bundle(internalBuildFlag: String?) -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FormaInternalBuildTest-\(UUID().uuidString).bundle")
        try! FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        var dictionary: [String: String] = [:]
        if let internalBuildFlag {
            dictionary[FormaBuildConfiguration.internalBuildInfoPlistKey] = internalBuildFlag
        }

        let infoPlistURL = bundleURL.appendingPathComponent("Info.plist")
        let data = try! PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: .xml,
            options: 0
        )
        try! data.write(to: infoPlistURL)
        return Bundle(url: bundleURL)!
    }
}
