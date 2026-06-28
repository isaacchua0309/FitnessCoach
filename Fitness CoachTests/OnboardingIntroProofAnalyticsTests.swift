//
//  OnboardingIntroProofAnalyticsTests.swift
//  Fitness CoachTests
//
//  Forma — Intro proof analytics and navigation tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingIntroProofAnalyticsTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private let analytics = CapturingIntroProofAnalyticsLogger()

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingIntroProofAnalyticsTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testIntroProofLogsStepViewedOnStart() throws {
        _ = try makeModel()

        XCTAssertTrue(analytics.contains(.stepViewed, step: "intro_proof"))
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["stage"], OnboardingStage.start.rawValue)
        XCTAssertNil(analytics.lastProperties(for: .stepViewed)?["v2Enabled"])
    }

    func testIntroProofNextLogsCompletedAndAdvancesToHeightWeight() throws {
        let model = try makeModel()
        XCTAssertEqual(model.currentStep, .introProof)

        model.goNext()

        XCTAssertTrue(analytics.contains(.stepCompleted, step: "intro_proof"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "height_weight"))
        XCTAssertNil(analytics.lastProperties(for: .stepCompleted)?["v2Enabled"])
        XCTAssertEqual(model.currentStep, .heightWeight)
    }

    private func makeModel() throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsLogger: analytics,
            analyticsEntry: .preAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }
}

private final class CapturingIntroProofAnalyticsLogger: OnboardingAnalyticsLogging, @unchecked Sendable {

    struct Record: Sendable {
        let event: OnboardingAnalyticsEvent
        let properties: OnboardingAnalyticsProperties
    }

    private let lock = NSLock()
    private var records: [Record] = []

    func log(_ event: OnboardingAnalyticsEvent, properties: OnboardingAnalyticsProperties) {
        lock.lock()
        records.append(Record(event: event, properties: properties))
        lock.unlock()
    }

    func contains(_ event: OnboardingAnalyticsEvent, step: String? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return records.contains { record in
            guard record.event == event else { return false }
            if let step, record.properties.step != step { return false }
            return true
        }
    }

    func lastProperties(for event: OnboardingAnalyticsEvent) -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        guard let record = records.last(where: { $0.event == event }) else { return nil }
        return record.properties.asParameters()
    }
}

private extension OnboardingAnalyticsProperties {
    subscript(key: String) -> String? {
        asParameters()[key]
    }
}
