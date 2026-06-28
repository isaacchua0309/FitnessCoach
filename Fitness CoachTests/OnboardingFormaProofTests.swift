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

    func testFormaProofComparisonModelUsesProductCopy() {
        let model = OnboardingFormaProofComparisonModel.default
        let copy = FormaProductCopy.Onboarding.Flow.Proof.WeightLossComparison.self

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
            OnboardingStep.formaProof.next(in: OnboardingStep.flow),
            .review
        )
    }
}

@MainActor
final class OnboardingFormaProofAnalyticsTests: XCTestCase {

    }

    func testFormaProofLogsStepViewedAndCompletedOnNext() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(integration: integration)
        try await advanceModelToFormaProof(model)

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

    private func advanceModelToFormaProof(_ model: OnboardingModel) async throws {
        try await advanceModelToAlmostThere(model)
        model.goNext()
        XCTAssertEqual(model.currentStep, .formaProof)
    }

    private func advanceModelToAlmostThere(_ model: OnboardingModel) async throws {
        seedValidOnboardingForm(&model.formState)

        model.goNext() // introProof -> heightWeight
        model.goNext() // heightWeight
        model.goNext() // targetWeight
        model.goNext() // targetEncouragement
        model.goNext() // birthday
        model.goNext() // activityLevel
        model.goNext() // appleHealth

        for _ in 0..<50 {
            if model.currentStep == .almostThere { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(model.currentStep, .almostThere)
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
