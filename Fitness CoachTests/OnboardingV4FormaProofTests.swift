//
//  OnboardingV4FormaProofTests.swift
//  Fitness CoachTests
//
//  Forma — V4 forma proof comparison copy, routing, and analytics tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV4FormaProofTests: XCTestCase {

    func testFormaProofStepUsesProductCopy() {
        XCTAssertEqual(
            OnboardingV4Step.formaProof.title,
            FormaProductCopy.Onboarding.V4.FormaProof.title
        )
        XCTAssertEqual(
            OnboardingV4Step.formaProof.subtitle,
            FormaProductCopy.Onboarding.V4.FormaProof.subtitle
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.V4.FormaProof.continueCTA,
            "Next"
        )
    }

    func testFormaProofComparisonModelUsesProductCopy() {
        let model = OnboardingV4FormaProofComparisonModel.default
        let copy = FormaProductCopy.Onboarding.V4.Proof.WeightLossComparison.self

        XCTAssertEqual(model.withoutFormaLabel, copy.withoutFormaLabel)
        XCTAssertEqual(model.withoutFormaValue, copy.withoutFormaValue)
        XCTAssertEqual(model.withFormaLabel, copy.withFormaLabel)
        XCTAssertEqual(model.withFormaValue, copy.withFormaValue)
        XCTAssertEqual(model.withoutFormaFill, copy.withoutFormaBarFill)
        XCTAssertEqual(model.withFormaFill, copy.withFormaBarFill)
        XCTAssertEqual(model.disclaimer, copy.disclaimer)
        XCTAssertEqual(model.chartAccessibilityLabel, copy.chartAccessibilityLabel)
    }

    func testFormaProofRoutesNextToReview() {
        XCTAssertEqual(
            OnboardingV4Step.formaProof.next(in: OnboardingV4Step.fullFlow),
            .review
        )
    }
}

@MainActor
final class OnboardingV4FormaProofAnalyticsTests: XCTestCase {

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

        draftSuiteName = "OnboardingV4FormaProofAnalyticsTests.\(UUID().uuidString)"
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

    func testFormaProofLogsStepViewedAndCompletedOnNext() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeV4Model(integration: integration)
        try await advanceModelToFormaProof(model)

        XCTAssertEqual(model.currentV4Step, .formaProof)
        XCTAssertTrue(analytics.contains(.stepViewed, step: "formaProof"))
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["stage"], OnboardingV4Stage.proof.rawValue)

        model.goNext()

        XCTAssertEqual(model.currentV4Step, .review)
        XCTAssertTrue(analytics.contains(.stepCompleted, step: "formaProof"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "review"))
    }

    private func makeV4Model(
        integration: TrainingIntegrationProviding
    ) throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsLogger: analytics,
            analyticsEntry: .preAuth,
            flowScope: .v2Full,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: integration
        )
    }

    private func advanceModelToFormaProof(_ model: OnboardingModel) async throws {
        try await advanceModelToAlmostThere(model)
        model.goNext()
        XCTAssertEqual(model.currentV4Step, .formaProof)
    }

    private func advanceModelToAlmostThere(_ model: OnboardingModel) async throws {
        seedValidV4Form(&model.formState)

        model.goNext() // introProof -> heightWeight
        model.goNext() // heightWeight
        model.goNext() // targetWeight
        model.goNext() // targetEncouragement
        model.goNext() // birthday
        model.goNext() // activityLevel
        model.goNext() // appleHealth

        for _ in 0..<50 {
            if model.currentV4Step == .almostThere { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(model.currentV4Step, .almostThere)
    }

    private func seedValidV4Form(_ formState: inout OnboardingFormState) {
        OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingV4BirthdayValues.applyDefaultsIfNeeded(to: &formState)
        formState.sex = .female
        formState.activityLevel = .moderatelyActive
        OnboardingV4ActivityLevelValues.applyDefaultsIfNeeded(to: &formState)
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
