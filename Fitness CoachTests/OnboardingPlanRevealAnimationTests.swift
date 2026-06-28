//
//  OnboardingPlanRevealAnimationTests.swift
//  Fitness CoachTests
//
//  Forma — Plan reveal celebration animation ordering.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingPlanRevealAnimationTests: XCTestCase {

    func testRevealStageDelaysFollowEmotionalHierarchy() {
        let timing = OnboardingPlanRevealTiming.self

        XCTAssertLessThan(timing.celebrationTitle, timing.achievementBadge)
        XCTAssertLessThan(timing.achievementBadge, timing.heroIllustration)
        XCTAssertLessThan(timing.heroIllustration, timing.goalCard)
        XCTAssertLessThan(timing.goalCard, timing.journey)
        XCTAssertLessThan(timing.journey, timing.firstWeek)
        XCTAssertLessThan(timing.firstWeek, timing.nutrition)
        XCTAssertLessThan(timing.nutrition, timing.coach)
        XCTAssertLessThan(timing.coach, timing.ctaPulse)
    }

    func testRevealFadeDurationMatchesGenerationTransition() {
        XCTAssertEqual(
            OnboardingPlanRevealTiming.fadeDuration,
            OnboardingGeneratingPlanTiming.stepTransitionAnimation,
            accuracy: 0.001
        )
    }

    func testRevealEntranceStagesAreOrderedByDelay() {
        let ordered = OnboardingPlanRevealEntranceStage.allCases
        for index in ordered.indices.dropLast() {
            let current = ordered[index]
            let next = ordered[index + 1]
            XCTAssertLessThan(current.delay, next.delay)
        }
    }
}
