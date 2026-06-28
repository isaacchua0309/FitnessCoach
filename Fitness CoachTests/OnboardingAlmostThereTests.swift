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
            FormaProductCopy.Onboarding.Flow.AlmostThere.title
        )
        XCTAssertEqual(
            OnboardingStep.almostThere.subtitle,
            FormaProductCopy.Onboarding.Flow.AlmostThere.subtitle
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.AlmostThere.continueCTA,
            "Next"
        )
    }

    func testAlmostThereFeatureBulletsMatchProductCopy() {
        let bullets = OnboardingFeatureBullet.almostThereDefaults
        let expected = FormaProductCopy.Onboarding.Flow.AlmostThereFeatures.bullets

        XCTAssertEqual(bullets.map(\.title), expected.map(\.title))
        XCTAssertEqual(bullets.map(\.subtitle), expected.map(\.subtitle))
    }

    func testAlmostThereRoutesNextToFormaProof() {
        XCTAssertEqual(
            OnboardingStep.almostThere.next(in: OnboardingStep.flow),
            .formaProof
        )
    }
}

@MainActor
final class OnboardingAlmostThereAnalyticsTests: XCTestCase {

    }

    func testAlmostThereLogsStepViewedAndCompletedOnNext() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(integration: integration)
        try await advanceModelToAlmostThere(model)

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

    private func advanceModelToAlmostThere(_ model: OnboardingModel) async throws {
        seedValidOnboardingForm(&model.formState)

        model.goNext() // introProof -> heightWeight
        model.goNext() // heightWeight
        model.goNext() // targetWeight
        model.goNext() // targetEncouragement
        model.goNext() // birthday
        model.goNext() // activityLevel
        model.goNext() // appleHealth (async permission)

        for _ in 0..<50 {
            if model.currentStep == .almostThere { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTFail("Expected onboarding to reach almostThere step")
    }

    private func seedValidOnboardingForm(_ formState: inout OnboardingFormState) {
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &formState)
        formState.sex = .female
        formState.activityLevel = .moderatelyActive
        OnboardingActivityLevelValues.applyDefaultsIfNeeded(to: &formState)
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
