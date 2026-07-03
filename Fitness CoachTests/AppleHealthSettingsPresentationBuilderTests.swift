//
//  AppleHealthSettingsPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Apple Health settings presentation tests.
//

import XCTest
@testable import Fitness_Coach

final class AppleHealthSettingsPresentationBuilderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var locale: Locale {
        Locale(identifier: "en_US_POSIX")
    }

    private var timeZone: TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }

    func testConnectedState() {
        let presentation = build(integrationState: .connected)

        XCTAssertEqual(presentation.heroStatus, FormaProductCopy.Settings.AppleHealth.statusConnected)
        XCTAssertTrue(presentation.heroShowsConnected)
        XCTAssertEqual(
            rowValue("status", in: presentation),
            FormaProductCopy.Settings.AppleHealth.statusConnected
        )
        XCTAssertEqual(presentation.primaryAction, .openHealthApp)
        XCTAssertEqual(
            presentation.primaryActionTitle,
            FormaProductCopy.Settings.AppleHealth.openHealthAppAction
        )
        XCTAssertTrue(presentation.isPrimaryActionEnabled)
    }

    func testDisconnectedState() {
        let presentation = build(integrationState: .notConnected)

        XCTAssertEqual(presentation.heroStatus, FormaProductCopy.Settings.AppleHealth.statusNotConnected)
        XCTAssertFalse(presentation.heroShowsConnected)
        XCTAssertEqual(
            rowValue("status", in: presentation),
            FormaProductCopy.Settings.AppleHealth.statusNotConnected
        )
        XCTAssertEqual(presentation.primaryAction, .connectAppleHealth)
        XCTAssertEqual(
            presentation.primaryActionTitle,
            FormaProductCopy.Settings.AppleHealth.connectAction
        )
    }

    func testPermissionNeededState() {
        let presentation = build(integrationState: .denied)

        XCTAssertEqual(presentation.heroStatus, FormaProductCopy.Settings.AppleHealth.statusNotConnected)
        XCTAssertEqual(
            rowValue("status", in: presentation),
            FormaProductCopy.Settings.AppleHealth.statusPermissionNeeded
        )
        XCTAssertEqual(presentation.primaryAction, .openHealthApp)
        XCTAssertEqual(
            presentation.primaryActionTitle,
            FormaProductCopy.Settings.AppleHealth.openHealthAppAction
        )
    }

    func testLastSyncAvailable() {
        let syncDate = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 2,
            hour: 14,
            minute: 30
        ))!
        let presentation = build(
            integrationState: .connected,
            lastSyncDate: syncDate,
            now: syncDate
        )

        XCTAssertEqual(
            rowValue("last-sync", in: presentation),
            AppleHealthSettingsLastSyncFormatter.format(
                syncDate,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )
        )
        XCTAssertEqual(
            rowValue("permissions", in: presentation),
            FormaProductCopy.Settings.AppleHealth.permissionsWorkouts
        )
        XCTAssertEqual(
            rowValue("access", in: presentation),
            FormaProductCopy.Settings.AppleHealth.accessManagedInHealthApp
        )
    }

    func testLastSyncUnavailable() {
        let presentation = build(integrationState: .connected, lastSyncDate: nil)

        XCTAssertNil(rowValue("last-sync", in: presentation))
        XCTAssertEqual(presentation.connectionRows.map(\.id), ["status", "permissions", "access"])
    }

    func testTrustCopyIsPrivacyConscious() {
        let presentation = build(integrationState: .connected)

        XCTAssertEqual(
            presentation.trustCopy,
            [
                FormaProductCopy.Settings.AppleHealth.readsWorkoutsCopy,
                FormaProductCopy.Settings.AppleHealth.doesNotWriteCopy
            ]
        )
        XCTAssertTrue(presentation.trustCopy[0].localizedCaseInsensitiveContains("workouts"))
        XCTAssertTrue(presentation.trustCopy[1].localizedCaseInsensitiveContains("does not write"))
    }

    private func build(
        integrationState: TrainingIntegrationState,
        lastSyncDate: Date? = nil,
        now: Date = Date()
    ) -> AppleHealthSettingsPresentation {
        AppleHealthSettingsPresentationBuilder.build(
            input: AppleHealthSettingsPresentationInput(
                integrationState: integrationState,
                lastSyncDate: lastSyncDate
            ),
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
    }

    private func rowValue(
        _ id: String,
        in presentation: AppleHealthSettingsPresentation
    ) -> String? {
        presentation.connectionRows.first(where: { $0.id == id })?.value
    }
}

final class AppleHealthSettingsActionHandlerTests: XCTestCase {

    func testOpenHealthAction() async {
        var openedHealthApp = false
        var connected = false

        await AppleHealthSettingsActionHandler.perform(
            action: .openHealthApp,
            openHealthApp: { openedHealthApp = true },
            connect: { connected = true }
        )

        XCTAssertTrue(openedHealthApp)
        XCTAssertFalse(connected)
    }

    func testConnectAction() async {
        var openedHealthApp = false
        var connected = false

        await AppleHealthSettingsActionHandler.perform(
            action: .connectAppleHealth,
            openHealthApp: { openedHealthApp = true },
            connect: { connected = true }
        )

        XCTAssertFalse(openedHealthApp)
        XCTAssertTrue(connected)
    }
}
