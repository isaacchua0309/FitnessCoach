//
//  SettingsPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Settings hub presentation model tests.
//

import XCTest
@testable import Fitness_Coach

final class SettingsPresentationBuilderTests: XCTestCase {

    private func makeInput(
        integrationState: TrainingIntegrationState = .connected,
        unitSystem: UnitSystem = .metric,
        themePalette: AppThemePalette = .oceanBlue,
        appVersion: String = "1.0",
        featureAvailability: SettingsFeatureAvailability = .production,
        legalAvailability: SettingsLegalAvailability = .production,
        supportConfiguration: SettingsSupportConfiguration = .production,
        isDebugOrInternalBuild: Bool = false
    ) -> SettingsPresentationInput {
        SettingsPresentationInput(
            integrationState: integrationState,
            unitSystem: unitSystem,
            themePalette: themePalette,
            appVersion: appVersion,
            featureAvailability: featureAvailability,
            legalAvailability: legalAvailability,
            supportConfiguration: supportConfiguration,
            isDebugOrInternalBuild: isDebugOrInternalBuild
        )
    }

    func testProductionSettingsHidesDeveloperSection() {
        let state = SettingsPresentationBuilder.build(input: makeInput())

        XCTAssertNil(state.developer)
        XCTAssertFalse(state.isDebugOrInternalBuild)
        XCTAssertFalse(state.visibleRowIDs.contains(.authDiagnostics))
        XCTAssertFalse(state.visibleRowIDs.contains(.pipelineTraces))
    }

    func testDebugSettingsShowsDeveloperSection() {
        let state = SettingsPresentationBuilder.build(
            input: makeInput(isDebugOrInternalBuild: true)
        )

        XCTAssertNotNil(state.developer)
        XCTAssertTrue(state.isDebugOrInternalBuild)
        XCTAssertEqual(state.developer?.rows.map(\.id), [.authDiagnostics, .pipelineTraces])
        XCTAssertEqual(
            state.developer?.footer,
            FormaProductCopy.Settings.Developer.sectionFooter
        )
    }

    func testProductionSettingsHidesComingSoonRows() {
        let state = SettingsPresentationBuilder.build(input: makeInput())

        XCTAssertFalse(state.visibleRowIDs.contains(.exportData))
        XCTAssertFalse(state.visibleRowIDs.contains(.deleteData))

        let titles = allRowTitles(in: state)
        XCTAssertFalse(SettingsProductionVisibility.containsProhibitedPlaceholderCopy(titles))
    }

    func testFunctionalRowsAppearInProduction() {
        let state = SettingsPresentationBuilder.build(input: makeInput())

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
        XCTAssertEqual(state.privacyData.rows.map(\.id), [.privacyPolicy])
        XCTAssertEqual(state.about.rows.map(\.id), [.appVersion, .termsOfService])
        XCTAssertNotNil(state.support)
        XCTAssertEqual(state.support?.rows.map(\.id), [.sendFeedback, .contactSupport, .reportProblem])
    }

    func testSupportSectionHiddenWhenEmailUnconfigured() {
        let state = SettingsPresentationBuilder.build(
            input: makeInput(supportConfiguration: .unconfigured)
        )

        XCTAssertNil(state.support)
    }

    func testStatusLabelsAppearWhenUseful() {
        let state = SettingsPresentationBuilder.build(
            input: makeInput(
                integrationState: .connected,
                unitSystem: .imperial,
                themePalette: .blossomPink,
                appVersion: "2.4.1"
            )
        )

        XCTAssertEqual(
            state.preferences.rows.first(where: { $0.id == .units })?.status,
            FormaProductCopy.Settings.Status.imperial
        )
        XCTAssertEqual(
            state.preferences.rows.first(where: { $0.id == .theme })?.status,
            FormaProductCopy.Settings.Theme.colorPaletteTitle(for: .blossomPink)
        )
        XCTAssertEqual(
            state.integrations.rows.first(where: { $0.id == .appleHealth })?.status,
            FormaProductCopy.Settings.Status.connected
        )
        XCTAssertEqual(
            state.integrations.rows.first(where: { $0.id == .appleHealth })?.status,
            SettingsRowStatusFormatter.appleHealth(.connected)
        )
        XCTAssertEqual(
            state.about.rows.first(where: { $0.id == .appVersion })?.status,
            "2.4.1"
        )
    }

    func testAppleHealthDisconnectedStatusLabel() {
        let state = SettingsPresentationBuilder.build(
            input: makeInput(integrationState: .denied)
        )

        XCTAssertEqual(
            state.integrations.rows.first(where: { $0.id == .appleHealth })?.status,
            FormaProductCopy.Settings.Status.notConnected
        )
    }

    func testPrivacyPolicyAppearsOnlyInPrivacySection() {
        let state = SettingsPresentationBuilder.build(input: makeInput())

        XCTAssertEqual(state.privacyData.rows.filter { $0.id == .privacyPolicy }.count, 1)
        XCTAssertFalse(state.about.rows.contains(where: { $0.id == .privacyPolicy }))
        XCTAssertEqual(state.about.rows.filter { $0.id == .termsOfService }.count, 1)
        XCTAssertFalse(state.privacyData.rows.contains(where: { $0.id == .termsOfService }))
    }

    func testPrivacyPolicyRowHiddenWhenURLAndInAppContentUnavailable() {
        let original = FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL
        defer { FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL = original }
        FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL = false

        let state = SettingsPresentationBuilder.build(
            input: makeInput(
                legalAvailability: SettingsLegalAvailability(
                    termsURL: nil,
                    privacyPolicyURL: nil
                )
            )
        )

        XCTAssertFalse(state.privacyData.rows.contains(where: { $0.id == .privacyPolicy }))
        XCTAssertFalse(state.about.rows.contains(where: { $0.id == .termsOfService }))
    }

    func testPrivacyPolicyRowAppearsWhenURLExists() {
        let privacyURL = URL(string: "https://forma.app/privacy")!
        let state = SettingsPresentationBuilder.build(
            input: makeInput(
                legalAvailability: SettingsLegalAvailability(
                    termsURL: nil,
                    privacyPolicyURL: privacyURL
                )
            )
        )

        let privacyRow = state.privacyData.rows.first(where: { $0.id == .privacyPolicy })
        XCTAssertNotNil(privacyRow)
        XCTAssertEqual(state.externalURL(for: .privacyPolicy), privacyURL)
        XCTAssertEqual(privacyRow?.destination, .legalDocument(.privacyPolicy))
    }

    func testFeatureFlaggedRowsAppearOnlyWhenEnabled() {
        let state = SettingsPresentationBuilder.build(
            input: makeInput(
                integrationState: .notConnected,
                featureAvailability: SettingsFeatureAvailability(
                    isDataExportEnabled: true,
                    isDeleteDataEnabled: true
                )
            )
        )

        XCTAssertEqual(
            state.privacyData.rows.map(\.id),
            [.privacyPolicy, .exportData, .deleteData]
        )
        XCTAssertEqual(state.privacyData.rows.first(where: { $0.id == .exportData })?.destination, .exportData)
        XCTAssertEqual(state.privacyData.rows.first(where: { $0.id == .deleteData })?.destination, .deleteData)
    }

    func testSupportMailURLsUseSupportEmailAndDiagnostics() {
        let diagnostics = SettingsSupportDiagnosticsBuilder.build(
            input: SettingsSupportDiagnosticsInput(
                appVersion: "2.4.1",
                buildNumber: "512",
                deviceModel: "iPhone15,2",
                systemVersion: "18.2"
            )
        )
        let email = "support@forma.app"

        let feedbackURL = SettingsSupportMailURLBuilder.url(
            for: .feedback,
            supportEmail: email,
            diagnostics: diagnostics
        )
        XCTAssertEqual(feedbackURL?.scheme, "mailto")
        XCTAssertEqual(feedbackURL?.path, email)

        let components = URLComponents(url: feedbackURL!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "subject" })?.value, "Forma Feedback")
        XCTAssertTrue(components?.queryItems?.first(where: { $0.name == "body" })?.value?.contains("2.4.1") ?? false)
        XCTAssertTrue(components?.queryItems?.first(where: { $0.name == "body" })?.value?.contains("iPhone15,2") ?? false)
        XCTAssertTrue(SettingsSupportMailContent.isPrivacySafe(components?.queryItems?.first(where: { $0.name == "body" })?.value ?? ""))

        let reportURL = SettingsSupportMailURLBuilder.url(
            for: .reportProblem,
            supportEmail: email,
            diagnostics: diagnostics
        )
        let reportComponents = URLComponents(url: reportURL!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(
            reportComponents?.queryItems?.first(where: { $0.name == "subject" })?.value,
            FormaProductCopy.Settings.Support.reportProblemMailSubject
        )
    }

    func testAppVersionRowIsDisplayOnly() {
        let state = SettingsPresentationBuilder.build(
            input: makeInput(appVersion: "2.4.1")
        )
        let appVersionRow = state.about.rows.first { $0.id == .appVersion }

        XCTAssertEqual(appVersionRow?.status, "2.4.1")
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
