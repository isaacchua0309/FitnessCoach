//
//  SettingsPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Settings hub presentation model tests.
//

import XCTest
@testable import Fitness_Coach

final class SettingsPresentationBuilderTests: XCTestCase {

    private let productionInput = SettingsPresentationInput(
        integrationState: .connected,
        appVersionDisplay: "1.0 (100)",
        featureAvailability: .production,
        isDebugOrInternalBuild: false
    )

    private let debugInput = SettingsPresentationInput(
        integrationState: .connected,
        appVersionDisplay: "1.0 (100)",
        featureAvailability: .production,
        isDebugOrInternalBuild: true
    )

    func testProductionSettingsHidesDeveloperSection() {
        let state = SettingsPresentationBuilder.build(input: productionInput)

        XCTAssertNil(state.developer)
        XCTAssertFalse(state.isDebugOrInternalBuild)
        XCTAssertFalse(state.visibleRowIDs.contains(.authDiagnostics))
        XCTAssertFalse(state.visibleRowIDs.contains(.pipelineTraces))
    }

    func testDebugSettingsShowsDeveloperSection() {
        let state = SettingsPresentationBuilder.build(input: debugInput)

        XCTAssertNotNil(state.developer)
        XCTAssertTrue(state.isDebugOrInternalBuild)
        XCTAssertEqual(state.developer?.rows.map(\.id), [.authDiagnostics, .pipelineTraces])
        XCTAssertEqual(
            state.developer?.footer,
            FormaProductCopy.Settings.Hub.developerSectionFooter
        )
    }

    func testProductionSettingsHidesComingSoonRows() {
        let state = SettingsPresentationBuilder.build(input: productionInput)

        XCTAssertFalse(state.visibleRowIDs.contains(.exportData))
        XCTAssertFalse(state.visibleRowIDs.contains(.deleteData))

        let titles = allRowTitles(in: state)
        XCTAssertFalse(titles.contains(where: { $0.localizedCaseInsensitiveContains("coming soon") }))
    }

    func testFunctionalRowsAppearInProduction() {
        let state = SettingsPresentationBuilder.build(input: productionInput)

        XCTAssertEqual(
            state.visibleRowIDs,
            [
                .account,
                .units,
                .bodyAndStats,
                .theme,
                .appleHealth,
                .privacyPolicy,
                .sendFeedback,
                .contactSupport,
                .reportProblem,
                .appVersion,
                .termsOfService
            ]
        )

        XCTAssertEqual(state.account.rows.first?.title, FormaProductCopy.Settings.Rows.account)
        XCTAssertEqual(state.preferences.rows.map(\.title), [
            FormaProductCopy.Settings.Rows.units,
            FormaProductCopy.PlanCalculation.bodyDetailsSettingsTitle,
            FormaProductCopy.Settings.Theme.navigationRowTitle
        ])
        XCTAssertEqual(
            state.integrations.rows.first?.status,
            TrainingIntegrationCopy.settingsStatusConnected
        )
        XCTAssertEqual(state.privacyData.rows.map(\.id), [.privacyPolicy])
        XCTAssertEqual(state.about.rows.map(\.id), [.appVersion, .termsOfService])
    }

    func testPrivacyPolicyAppearsOnlyInPrivacySection() {
        let state = SettingsPresentationBuilder.build(input: productionInput)

        XCTAssertEqual(state.privacyData.rows.filter { $0.id == .privacyPolicy }.count, 1)
        XCTAssertFalse(state.about.rows.contains(where: { $0.id == .privacyPolicy }))
    }

    func testFeatureFlaggedRowsAppearOnlyWhenEnabled() {
        let enabledInput = SettingsPresentationInput(
            integrationState: .notConnected,
            appVersionDisplay: "1.0",
            featureAvailability: SettingsFeatureAvailability(
                isDataExportEnabled: true,
                isDeleteDataEnabled: true
            ),
            isDebugOrInternalBuild: false
        )

        let state = SettingsPresentationBuilder.build(input: enabledInput)

        XCTAssertEqual(
            state.privacyData.rows.map(\.id),
            [.privacyPolicy, .exportData, .deleteData]
        )
    }

    func testSupportMailURLsUseSupportEmail() {
        let feedbackURL = SettingsSupportMailURLBuilder.url(for: .feedback)
        XCTAssertEqual(feedbackURL?.scheme, "mailto")
        XCTAssertEqual(feedbackURL?.path, FormaProductCopy.Legal.supportEmail)

        let components = URLComponents(url: feedbackURL!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "subject" })?.value, "Forma Feedback")

        let reportURL = SettingsSupportMailURLBuilder.url(for: .reportProblem)
        let reportComponents = URLComponents(url: reportURL!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(
            reportComponents?.queryItems?.first(where: { $0.name == "subject" })?.value,
            FormaProductCopy.Settings.Support.reportProblemMailSubject
        )
    }

    func testAppVersionRowIsDisplayOnly() {
        let state = SettingsPresentationBuilder.build(input: productionInput)
        let appVersionRow = state.about.rows.first { $0.id == .appVersion }

        XCTAssertEqual(appVersionRow?.subtitle, "1.0 (100)")
        XCTAssertNil(appVersionRow?.destination)
        XCTAssertFalse(appVersionRow?.isNavigable ?? true)
    }

    private func allRowTitles(in state: SettingsPresentationState) -> [String] {
        var titles: [String] = []
        titles += state.account.rows.map(\.title)
        titles += state.preferences.rows.map(\.title)
        titles += state.integrations.rows.map(\.title)
        titles += state.privacyData.rows.map(\.title)
        titles += state.support.rows.map(\.title)
        titles += state.about.rows.map(\.title)
        if let developer = state.developer {
            titles += developer.rows.map(\.title)
        }
        return titles
    }
}
