//
//  JourneyRevampQAChecklistSupport.swift
//  Fitness CoachTests
//
//  Shared assertions for Journey revamp QA scenarios.
//

import XCTest
@testable import Fitness_Coach

enum JourneyRevampQAChecklistSupport {

    static let removedClutterSectionIDs: Set<String> = [
        "beforeToday",
        "personalRecords",
        "detailedAnalytics",
        "journeyLevel",
        "habitInsights",
        "whyProgress",
        "consistencyCalendar",
        "coachInsights",
        "achievements",
    ]

    static let bannedLiveCopyPhrases: [String] = [
        "You've lost 0 kg",
        "Keep logging to unlock personal records",
        "Detailed analytics",
        "Before vs Today",
        "Before vs today",
        "Your first monthly recap is building",
        "Your consistency is starting to create a useful pattern",
        "Level 1 / 25 XP",
        "Keep logging to unlock habit insights",
        "Not enough data yet",
        "Maintenance estimate building",
        "Log weight to see weekly change",
        "Missing signals:",
        "Limited confidence",
        "Requires: 7 days",
    ]

    static let shamePhrases: [String] = [
        "you failed",
        "falling behind",
        "not good enough",
        "shame",
        "lazy",
        "bad week",
        "you're slipping",
    ]

    /// Mirrors `JourneyDashboardContent.visibleSections` for deterministic QA.
    static func visibleSections(for state: JourneyDashboardState) -> [JourneyProductSection] {
        JourneyDashboardSectionSupport.visibleSections(for: state)
    }

    static func assertNoRemovedClutter(file: StaticString = #filePath, line: UInt = #line) {
        let identifiers = Set(JourneyProductLayout.sectionOrder.map(\.rawValue))
        for clutter in removedClutterSectionIDs {
            XCTAssertFalse(
                identifiers.contains(clutter),
                "Removed clutter section reintroduced: \(clutter)",
                file: file,
                line: line
            )
        }
    }

    static func assertNoBannedLiveCopy(
        in dashboard: JourneyDashboardState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let copy = allCopyStrings(from: dashboard)
        for phrase in bannedLiveCopyPhrases {
            XCTAssertFalse(
                copy.localizedCaseInsensitiveContains(phrase),
                "Banned Journey copy found: \(phrase)",
                file: file,
                line: line
            )
        }
    }

    static func assertNoShameLanguage(
        in dashboard: JourneyDashboardState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let copy = allCopyStrings(from: dashboard).lowercased()
        for phrase in shamePhrases {
            XCTAssertFalse(
                copy.contains(phrase),
                "Shame phrase found: \(phrase)",
                file: file,
                line: line
            )
        }
        XCTAssertFalse(
            copy.contains("fail"),
            "Journey copy should not use failure framing",
            file: file,
            line: line
        )
    }

    static func assertNoFakeZeroPercentMonthlyRecap(
        _ recap: JourneyMonthlyRecapState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for row in recap.rows {
            XCTAssertNotEqual(
                row.value,
                "0%",
                "Fake zero-percent recap row: \(row.id)",
                file: file,
                line: line
            )
            XCTAssertFalse(
                row.value.hasSuffix("%") && row.value.hasPrefix("0"),
                "Fake zero-percent recap row: \(row.id)",
                file: file,
                line: line
            )
        }
    }

    static func assertHeroDoesNotShowZeroKgLost(
        _ hero: JourneyTransformationState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            hero.primaryMessage.contains("0 kg"),
            "Hero must not show zero kg transformation",
            file: file,
            line: line
        )
        XCTAssertFalse(
            hero.primaryMessage.localizedCaseInsensitiveContains("0.0 kg"),
            file: file,
            line: line
        )
    }

    static func assertProjectionIsLockedOrLearning(
        _ projection: JourneyGoalProjectionState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch projection.status {
        case .insufficientData, .flatTrend:
            break
        case .hidden, .towardGoal, .awayFromGoal, .goalReached:
            XCTFail(
                "Expected locked/learning projection, got \(projection.status)",
                file: file,
                line: line
            )
        }
    }

    static func assertAccessibilityContract(
        for dashboard: JourneyDashboardState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(dashboard.transformation.accessibilitySummary.isEmpty, file: file, line: line)
        XCTAssertFalse(dashboard.dashboardHero.accessibilitySummary.isEmpty, file: file, line: line)
        XCTAssertFalse(dashboard.progressSection.accessibilitySummary.isEmpty, file: file, line: line)
        XCTAssertFalse(dashboard.milestone.accessibilitySummary.isEmpty, file: file, line: line)
        XCTAssertFalse(dashboard.insight.accessibilitySummary.isEmpty, file: file, line: line)
        XCTAssertFalse(dashboard.monthlyRecap.accessibilitySummary.isEmpty, file: file, line: line)
        XCTAssertFalse(dashboard.chapter.accessibilitySummary.isEmpty, file: file, line: line)

        if dashboard.transformation.showsProgressBar {
            XCTAssertFalse(
                dashboard.transformation.progressBarAccessibilityValue.isEmpty,
                file: file,
                line: line
            )
            XCTAssertTrue(
                dashboard.transformation.progressBarAccessibilityValue.localizedCaseInsensitiveContains("percent"),
                file: file,
                line: line
            )
        }
    }

    static func assertWeeklyProgressAccessibility(
        for dashboard: JourneyDashboardState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)
        let detail = UnifiedWeeklyReviewPresentationBuilder.buildDetail(dashboard: dashboard)

        XCTAssertFalse(unified.confidenceAccessibilityLabel.isEmpty, file: file, line: line)
        XCTAssertFalse(unified.cardStateTitle.isEmpty, file: file, line: line)
        XCTAssertFalse(unified.cardSummary.isEmpty, file: file, line: line)
        XCTAssertFalse(detail.accessibilityLabel.isEmpty, file: file, line: line)
        XCTAssertTrue(
            detail.accessibilityLabel.contains(unified.confidenceAccessibilityLabel),
            file: file,
            line: line
        )

        if let primary = unified.primaryCTA {
            XCTAssertFalse(primary.accessibilityLabel.isEmpty, file: file, line: line)
        }
    }

    static func assertSmallScreenLayoutContract(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let screenWidth: CGFloat = 375
        let contentWidth = min(
            screenWidth - (JourneyLayout.horizontalPadding * 2),
            FormaTokens.Layout.maxContentWidth
        )

        XCTAssertGreaterThan(contentWidth, 280, file: file, line: line)

        let journeyInset = JourneyLayout.scrollBottomInset(
            bottomSafeArea: FormaTokens.Layout.homeIndicatorSafeAreaEstimate,
            dynamicTypeSize: .large
        )
        XCTAssertGreaterThan(
            journeyInset,
            FormaTokens.Layout.floatingTabBarHeight + FormaTokens.Layout.homeIndicatorSafeAreaEstimate,
            file: file,
            line: line
        )
        XCTAssertGreaterThanOrEqual(JourneyLayout.tabBarBreathingRoom, FormaTokens.Spacing.lg, file: file, line: line)
        XCTAssertGreaterThanOrEqual(JourneyLayout.scrollBottomContentPadding, FormaTokens.Spacing.sm, file: file, line: line)
        XCTAssertGreaterThan(JourneyLayout.sectionSpacing, FormaTokens.Spacing.sm, file: file, line: line)
    }

    private static func allCopyStrings(from dashboard: JourneyDashboardState) -> String {
        [
            dashboard.header.title,
            dashboard.header.subtitle,
            dashboard.dashboardHero.weekLabel,
            dashboard.dashboardHero.chapterTitle,
            dashboard.dashboardHero.encouragingSentence,
            dashboard.dashboardHero.compactStats.map(\.label).joined(separator: " "),
            dashboard.progressSection.sectionTitle,
            dashboard.progressSection.rows.map { "\($0.title) \($0.value)" }.joined(separator: " "),
            dashboard.transformation.title,
            dashboard.transformation.primaryMessage,
            dashboard.transformation.body,
            dashboard.transformation.progressLabel,
            dashboard.goalProjection.title,
            dashboard.goalProjection.detail,
            dashboard.milestone.title,
            dashboard.milestone.rewardCopy,
            dashboard.weeklyHabit.emptyMessage ?? "",
            dashboard.weeklyHabit.accessibilitySummary,
            dashboard.insight.learningTitle ?? "",
            dashboard.insight.learningDetail ?? "",
            dashboard.monthlyRecap.teaserTitle ?? "",
            dashboard.monthlyRecap.teaserDetail ?? "",
            dashboard.chapter.chapterTitle,
            dashboard.chapter.nextUnlockLabel ?? "",
            dashboard.chapter.emptyMessage ?? "",
            dashboard.chapter.progressItems.map(\.title).joined(separator: " "),
            dashboard.screenPresentation.unlockDashboard.nextActionCard?.title ?? "",
            dashboard.screenPresentation.unlockDashboard.nextActionCard?.detail ?? "",
        ]
        .joined(separator: " ")
        + " "
        + dashboard.insight.insights.map { "\($0.title) \($0.detail)" }.joined(separator: " ")
        + " "
        + dashboard.monthlyRecap.rows.map { "\($0.title) \($0.value)" }.joined(separator: " ")
        + " "
        + dashboard.storyTimeline.displayEvents.map { "\($0.title) \($0.subtitle ?? "")" }.joined(separator: " ")
    }
}
