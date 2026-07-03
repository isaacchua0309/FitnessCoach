//
//  SettingsSupportTests.swift
//  Fitness CoachTests
//
//  Forma — Support settings section and mail action tests.
//

import XCTest
@testable import Fitness_Coach

final class SettingsSupportTests: XCTestCase {

    private let sampleDiagnostics = SettingsSupportDiagnosticsBuilder.build(
        input: SettingsSupportDiagnosticsInput(
            appVersion: "2.4.1",
            buildNumber: "512",
            deviceModel: "iPhone15,2",
            systemVersion: "18.2"
        )
    )

    // MARK: - Section visibility

    func testSupportSectionAppearsWhenConfigured() {
        let section = SettingsSupportPresentationBuilder.buildSection(
            configuration: SettingsSupportConfiguration(supportEmail: "support@forma.app")
        )

        XCTAssertNotNil(section)
        XCTAssertEqual(section?.rows.map(\.id), [.sendFeedback, .contactSupport, .reportProblem])
        XCTAssertEqual(section?.footer, FormaProductCopy.Settings.Support.sectionFooter)
    }

    func testSupportSectionHiddenWhenNotConfigured() {
        let section = SettingsSupportPresentationBuilder.buildSection(
            configuration: .unconfigured
        )

        XCTAssertNil(section)

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                supportConfiguration: .unconfigured,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertNil(state.support)
        XCTAssertFalse(state.visibleRowIDs.contains(.sendFeedback))
        XCTAssertFalse(state.visibleRowIDs.contains(.contactSupport))
        XCTAssertFalse(state.visibleRowIDs.contains(.reportProblem))
    }

    // MARK: - Row routes

    func testSupportRowsUseSupportMailDestinations() {
        let section = SettingsSupportPresentationBuilder.buildSection(
            configuration: SettingsSupportConfiguration(supportEmail: "help@forma.app")
        )

        XCTAssertEqual(
            section?.rows.first(where: { $0.id == .sendFeedback })?.destination,
            .supportMail(.feedback)
        )
        XCTAssertEqual(
            section?.rows.first(where: { $0.id == .contactSupport })?.destination,
            .supportMail(.contactSupport)
        )
        XCTAssertEqual(
            section?.rows.first(where: { $0.id == .reportProblem })?.destination,
            .supportMail(.reportProblem)
        )
    }

    func testSupportMailSubjectsMatchTopics() {
        XCTAssertEqual(
            SettingsSupportMailContent.subject(for: .feedback),
            FormaProductCopy.Settings.Support.feedbackMailSubject
        )
        XCTAssertEqual(
            SettingsSupportMailContent.subject(for: .contactSupport),
            FormaProductCopy.Settings.Support.contactMailSubject
        )
        XCTAssertEqual(
            SettingsSupportMailContent.subject(for: .reportProblem),
            FormaProductCopy.Settings.Support.reportProblemMailSubject
        )
    }

    // MARK: - Diagnostics

    func testDiagnosticContextIncludesSafeMetadata() {
        let body = SettingsSupportMailContent.messageBody(for: .feedback, diagnostics: sampleDiagnostics)

        XCTAssertTrue(body.contains("2.4.1"))
        XCTAssertTrue(body.contains("512"))
        XCTAssertTrue(body.contains("iPhone15,2"))
        XCTAssertTrue(body.contains("18.2"))
        XCTAssertTrue(body.contains(FormaProductCopy.Settings.Support.diagnosticsHeader))
    }

    func testDiagnosticContextExcludesHealthData() {
        let body = SettingsSupportMailContent.messageBody(for: .reportProblem, diagnostics: sampleDiagnostics)

        XCTAssertTrue(SettingsSupportMailContent.isPrivacySafe(body))
        XCTAssertFalse(body.localizedCaseInsensitiveContains("weight"))
        XCTAssertFalse(body.localizedCaseInsensitiveContains("calorie"))
        XCTAssertFalse(body.localizedCaseInsensitiveContains("apple health"))
    }

    func testMailURLIncludesDiagnosticsWithoutHealthData() {
        let url = SettingsSupportMailURLBuilder.url(
            for: .contactSupport,
            supportEmail: "support@forma.app",
            diagnostics: sampleDiagnostics
        )
        let body = URLComponents(url: url!, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "body" })?
            .value ?? ""

        XCTAssertFalse(body.isEmpty)
        XCTAssertTrue(SettingsSupportMailContent.isPrivacySafe(body))
    }

    func testInvalidSupportEmailIsTreatedAsUnconfigured() {
        let configuration = SettingsSupportConfiguration(supportEmail: "not-an-email")
        XCTAssertFalse(configuration.isConfigured)
    }
}
