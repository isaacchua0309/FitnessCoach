//
//  OnboardingFormaProofTests.swift
//  Fitness CoachTests
//
//  Forma — forma proof comparison copy, routing, and analytics tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingFormaProofTests: XCTestCase {

    func testFormaProofStepUsesProductCopy() {
        XCTAssertEqual(
            OnboardingStep.formaProof.title,
            FormaProductCopy.Onboarding.Flow.FormaProof.title
        )
        XCTAssertEqual(
            OnboardingStep.formaProof.subtitle,
            FormaProductCopy.Onboarding.Flow.FormaProof.subtitle
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.FormaProof.continueCTA,
            "Next"
        )
    }

    func testFormaProofRoutesNextToReview() {
        XCTAssertEqual(
            OnboardingStep.formaProof.next(in: OnboardingStep.flow),
            .review
        )
    }
}

@MainActor
final class OnboardingFormaProofAnalyticsTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private let analytics = CapturingOnboardingAnalyticsLogger()

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingFormaProofAnalyticsTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testFormaProofLogsStepViewedAndCompletedOnNext() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(integration: integration)
        await OnboardingModelTestSupport.advanceTo(.formaProof, model: model, seedForm: true)

        XCTAssertEqual(model.currentStep, .formaProof)
        XCTAssertTrue(analytics.contains(.stepViewed, step: "forma_proof"))
        XCTAssertEqual(analytics.lastProperties(for: .stepViewed)?["stage"], OnboardingStage.proof.rawValue)

        model.goNext()

        XCTAssertEqual(model.currentStep, .review)
        XCTAssertTrue(analytics.contains(.stepCompleted, step: "forma_proof"))
        XCTAssertTrue(analytics.contains(.stepViewed, step: "review"))
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
