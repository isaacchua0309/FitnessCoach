//
//  OnboardingAlmostThereTests.swift
//  Fitness CoachTests
//
//  Forma — almost there copy, routing, and analytics tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingAlmostThereTests: XCTestCase {

    func testAlmostThereStepUsesProductCopy() {
        XCTAssertEqual(
            OnboardingStep.almostThere.title,
            "Your plan is almost ready"
        )
        XCTAssertEqual(
            OnboardingStep.almostThere.subtitle,
            "We've got what we need to build your personalized plan."
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AlmostThere.continueCTA,
            "Continue"
        )
    }

    func testAlmostThereRoutesNextToFormaProof() {
        XCTAssertEqual(
            OnboardingStep.almostThere.next(in: OnboardingStep.flow),
            .formaProof
        )
    }

    func testAlmostThereFeaturesUseProductionSafeCopy() {
        let features = OnboardingAlmostThereValues.features
        XCTAssertEqual(features.count, 4)
        XCTAssertEqual(features[0].title, "Fast meal tracking")
        XCTAssertEqual(features[1].title, "Daily targets")
        XCTAssertEqual(features[2].title, "Progress journey")
        XCTAssertEqual(features[3].title, "Smart coaching")
    }

    func testAlmostThereCopyAvoidsUnimplementedClaims() {
        let copy = FormaProductCopy.Onboarding.Flow.AlmostThere.self
        let joined = [
            copy.title,
            copy.subtitle,
            copy.summaryHeadline,
            copy.summarySupporting,
            copy.trustStrip,
            copy.accessibilitySummary
        ].joined(separator: " ")
            + OnboardingAlmostThereValues.features.map { "\($0.title) \($0.subtitle)" }.joined(separator: " ")

        XCTAssertFalse(joined.localizedCaseInsensitiveContains("challenge friends"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("leaderboard"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("adaptive goal"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("dynamic calories"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("adjust automatically"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("adjust to your lifestyle"))
    }

    func testAlmostThereAccessibilitySummary() {
        XCTAssertEqual(
            OnboardingAlmostThereValues.accessibilitySummary,
            FormaProductCopy.Onboarding.Flow.AlmostThere.accessibilitySummary
        )
        XCTAssertTrue(
            OnboardingAlmostThereValues.accessibilitySummary.contains("Your plan is almost ready")
        )
    }

    func testAlmostThereStepDoesNotShowProgressHeaderInShell() {
        XCTAssertFalse(OnboardingStep.almostThere.showsProgressHeader)
    }
}

@MainActor
final class OnboardingAlmostThereAnalyticsTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private let analytics = CapturingOnboardingAnalyticsLogger()

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingAlmostThereAnalyticsTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testAlmostThereLogsStepViewedAndCompletedOnNext() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(integration: integration)
        await OnboardingModelTestSupport.advanceTo(.almostThere, model: model, seedForm: true)

        XCTAssertEqual(model.currentStep, .almostThere)
        XCTAssertTrue(analytics.contains(.stepViewed, step: "almost_there"))
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["stage"], OnboardingStage.proof.rawValue)

        model.goNext()

        XCTAssertEqual(model.currentStep, .formaProof)
        XCTAssertTrue(analytics.contains(.stepCompleted, step: "almost_there"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "forma_proof"))
    }

    private func makeOnboardingModel(
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
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: integration
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
