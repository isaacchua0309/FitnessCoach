//
//  CoachContextInspectorTests.swift
//  Fitness CoachTests
//
//  Forma — DEBUG-only Coach context inspector tests.
//

import XCTest
@testable import Fitness_Coach

#if DEBUG
final class CoachContextInspectorTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        self.calendar = calendar

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = 14
        referenceDate = calendar.date(from: components)!
    }

    func testCompiledDeveloperToolsAvailableOnlyInDebugBuilds() {
        #if DEBUG
        XCTAssertTrue(FormaBuildConfiguration.includesCompiledDeveloperTools)
        #else
        XCTAssertFalse(FormaBuildConfiguration.includesCompiledDeveloperTools)
        #endif
    }

    func testRedactedJSONDoesNotContainSecretsOrRawImageBytes() throws {
        let imageBase64 = String(repeating: "A", count: 160)
        let packet = makeSamplePacket(chatText: "Bearer secret-token-12345 \(imageBase64)")

        let json = try CoachContextPacketV2DebugRedactor.redactedJSONString(from: packet)

        XCTAssertFalse(json.localizedCaseInsensitiveContains("Bearer secret-token"))
        XCTAssertFalse(json.contains(imageBase64))
        XCTAssertTrue(json.contains("[REDACTED]") || !json.contains("secret-token"))
        XCTAssertFalse(json.contains("eyJ"))
    }

    func testBuildReportUsesRedactedSummaryAndValidationWarnings() {
        var packet = makeSamplePacket(chatText: "hello")
        packet.today?.nutrition?.caloriesConsumed = 9_999

        let validation = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)
        let report = CoachContextInspector.buildReport(
            packet: validation.correctedPacket,
            validation: validation,
            preCompactionTimelineCount: 3
        )

        XCTAssertEqual(report.schemaVersion, CoachContextPacketV2.schemaVersion)
        XCTAssertEqual(report.timelineEventCount, 3)
        XCTAssertEqual(report.compactedTimelineEventCount, validation.correctedPacket.timeline.recentEvents.count)
        XCTAssertTrue(report.coachContextV2TransportOnly)
        XCTAssertFalse(report.compactSummary.contains("Salad"))
        if !validation.isValid {
            XCTAssertFalse(report.validationWarnings.isEmpty)
        }
    }

    func testFailureReportSurfacesRebuildErrorMessage() {
        let report = CoachContextInspectionReport.failure("Timeline store unavailable")

        XCTAssertEqual(report.errorMessage, "Timeline store unavailable")
        XCTAssertEqual(report.compactSummary, "Inspection failed.")
    }

    func testDebugRedactorStripsLongBase64PayloadsFromChatText() {
        let base64 = String(repeating: "aGVsbG8=", count: 30)
        let redacted = CoachContextPacketV2DebugRedactor.redactSecrets(in: "photo \(base64)")

        XCTAssertFalse(redacted.contains(base64))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }

    func testDeveloperSectionIncludesCoachContextInspectorRow() {
        let section = SettingsDeveloperPresentationBuilder.buildSection(isVisible: true)
        XCTAssertTrue(section?.rows.contains(where: { $0.id == .coachContextInspector }) ?? false)
    }

    // MARK: - Helpers

    private func makeSamplePacket(chatText: String) -> CoachContextPacketV2 {
        let entryId = UUID()
        return CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: referenceDate, calendar: calendar),
            today: CoachContextTodayPacket(
                nutrition: CoachTodayNutritionContext(
                    caloriesConsumed: 420,
                    caloriesRemaining: 1_580,
                    proteinConsumed: 28,
                    proteinRemaining: 112,
                    carbsConsumed: 30,
                    carbsRemaining: 150,
                    fatConsumed: 14,
                    fatRemaining: 51
                )
            ),
            timeline: CoachContextTimelinePacket(
                recentEvents: [
                    CoachTimelineContextEvent(
                        id: UUID(),
                        timestamp: referenceDate,
                        type: CoachTimelineEventType.foodLogged.rawValue,
                        source: CoachTimelineEventSource.coachUI.rawValue,
                        status: CoachTimelineEventStatus.confirmed.rawValue,
                        summary: "Logged Salad",
                        linkedEntryId: entryId
                    )
                ]
            ),
            recentChatMessages: [
                CoachChatMessageContext(
                    id: UUID(),
                    role: "user",
                    text: chatText,
                    timestamp: referenceDate,
                    hasPhotoAttachment: true
                )
            ],
            recentMealsStructured: [
                CoachRecentMealContext(
                    name: "Salad",
                    calories: 420,
                    linkedEntryId: entryId
                )
            ],
            sourceAttribution: CoachContextSourceAttribution(
                generationMode: .live,
                timelineEventCount: 1,
                recentMealCount: 1,
                commonFoodCount: 0
            )
        )
    }
}
#endif
