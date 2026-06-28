//
//  OnboardingV4IntroProofAnalyticsTests.swift
//  Fitness CoachTests
//
//  Forma — V4 intro proof analytics and navigation tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingV4IntroProofAnalyticsTests: XCTestCase {

    private var v2FlagPrevious = false
    private var v3FlagPrevious: Bool?
    private var v4FlagPrevious: Bool?
    private var draftSuiteName: String!
    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private var analytics: CapturingOnboardingAnalyticsLogger!

    override func setUp() async throws {
        try await super.setUp()
        v2FlagPrevious = UserDefaults.standard.bool(forKey: OnboardingV2FeatureFlag.enabledKey)
        v3FlagPrevious = UserDefaults.standard.object(forKey: OnboardingV3FeatureFlag.enabledKey) as? Bool
        v4FlagPrevious = UserDefaults.standard.object(forKey: OnboardingV4FeatureFlag.enabledKey) as? Bool

        UserDefaults.standard.set(true, forKey: OnboardingV2FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV3FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV4FeatureFlag.enabledKey)

        draftSuiteName = "OnboardingV4IntroProofAnalyticsTests.\(UUID().uuidString)"
        draftDefaults = UserDefaults(suiteName: draftSuiteName)!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
        draftStore.clearDraft()
        analytics = CapturingOnboardingAnalyticsLogger()
    }

    override func tearDown() async throws {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftSuiteName)
        UserDefaults.standard.set(v2FlagPrevious, forKey: OnboardingV2FeatureFlag.enabledKey)
        if let v3FlagPrevious {
            UserDefaults.standard.set(v3FlagPrevious, forKey: OnboardingV3FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV3FeatureFlag.enabledKey)
        }
        if let v4FlagPrevious {
            UserDefaults.standard.set(v4FlagPrevious, forKey: OnboardingV4FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV4FeatureFlag.enabledKey)
        }
        try await super.tearDown()
    }

    func testIntroProofLogsV4StepViewedOnStart() throws {
        _ = try makeV4Model()

        XCTAssertTrue(analytics.contains(.stepViewed, step: "introProof"))
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["v2Enabled"], "v4")
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["stage"], OnboardingV4Stage.start.rawValue)
    }

    func testIntroProofNextLogsCompletedAndAdvancesToHeightWeight() throws {
        let model = try makeV4Model()
        XCTAssertEqual(model.currentV4Step, .introProof)

        model.goNext()

        XCTAssertTrue(analytics.contains(.stepCompleted, step: "introProof"))
        XCTAssertEqual(analytics.lastProperties(for: .stepCompleted)?["v2Enabled"], "v4")
        XCTAssertTrue(analytics.contains(.stepViewed, step: "heightWeight"))
        XCTAssertEqual(model.currentV4Step, .heightWeight)
    }

    private func makeV4Model() throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsLogger: analytics,
            analyticsEntry: .preAuth,
            flowScope: .v2Full,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }
}

private final class CapturingOnboardingAnalyticsLogger: OnboardingAnalyticsLogging, @unchecked Sendable {

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
