//
//  MainTabLayoutManualQAChecklistTests.swift
//  Fitness CoachTests
//
//  Forma — Automated guardrails backing the unified main-tab layout manual QA matrix.
//  Run the human checklist in `MainTabLayoutManualQAChecklist` on device/simulator;
//  these tests catch wiring regressions without requiring live backends.
//

import XCTest
@testable import Fitness_Coach

final class MainTabLayoutManualQAChecklistTests: XCTestCase {

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testManualQAChecklistDocumentsAllSections() {
        XCTAssertEqual(MainTabLayoutManualQAChecklist.sections.count, 8)
        XCTAssertTrue(
            MainTabLayoutManualQAChecklist.sections.contains { $0.id == "today" }
        )
        XCTAssertTrue(
            MainTabLayoutManualQAChecklist.sections.contains { $0.id == "build-test" }
        )
    }

    // MARK: - 1. Today

    func testTodayUsesSharedScaffoldWithHeaderSubtitleAndMissionSection() throws {
        let todayView = try productionSource("Fitness Coach/Features/Today/TodayView.swift")

        XCTAssertTrue(todayView.contains("MainTabPageScaffold"))
        XCTAssertTrue(todayView.contains("FormaProductCopy.Today.Header.title"))
        XCTAssertTrue(todayView.contains("TodayDashboardHeaderFormatting.dateLine"))
        XCTAssertTrue(todayView.contains("TodayDashboardHeaderFormatting.planStatusChip"))
        XCTAssertTrue(todayView.contains("PageActionPill"))
        XCTAssertTrue(todayView.contains("TodayReadOnlyView"))
    }

    func testTodayMissionSectionUsesSharedSectionLabel() throws {
        let missionHero = try productionSource(
            "Fitness Coach/Features/Today/Components/TodayMissionHero.swift"
        )
        XCTAssertTrue(missionHero.contains("SectionLabel(title: mission.sectionTitle)"))
    }

    func testTodayWaterQuickAddUsesFlexibleGrid() throws {
        let water = try productionSource(
            "Fitness Coach/Features/Today/Components/TodayWaterQuickLogSection.swift"
        )
        XCTAssertTrue(water.contains("LazyVGrid"))
        XCTAssertTrue(water.contains("logWater(amountMl:"))
    }

    func testTodayScrollReservesTabBarClearance() {
        XCTAssertGreaterThan(FormaMainTabLayout.scrollContentBottomPadding, 0)
        XCTAssertEqual(
            FormaMainTabLayout.bottomContentInset(),
            FormaMainTabLayout.scrollContentBottomPadding + FormaMainTabLayout.tabBarBreathingRoom
        )
        XCTAssertLessThan(
            FormaMainTabLayout.bottomContentInset(),
            FormaMainTabLayout.tabBarReservedHeight,
            "Scroll padding must not re-reserve the system tab bar height."
        )
    }

    func testScaffoldDoesNotFeedbackMeasureSafeAreaIntoClearanceInset() throws {
        let scaffold = try productionSource(
            "Fitness Coach/DesignSystem/Layout/MainTabPageScaffold.swift"
        )
        let layout = try productionSource(
            "Fitness Coach/DesignSystem/Layout/FormaMainTabLayout.swift"
        )

        XCTAssertFalse(
            scaffold.contains("MainTabSafeAreaBottomPreferenceKey"),
            "Scaffold must not measure safeAreaInsets.bottom into a clearance inset."
        )
        XCTAssertFalse(
            scaffold.contains("measuredSafeAreaBottom"),
            "Scaffold must not retain measured bottom safe-area state for clearance."
        )
        XCTAssertFalse(
            scaffold.contains("MainTabTabBarClearanceSpacer"),
            "Scaffold must not reserve a second tab-bar clearance spacer; TabView owns that inset."
        )
        XCTAssertFalse(
            layout.contains("safeAreaBottom"),
            "Main-tab bottom inset must not take a measured safe-area value."
        )
        XCTAssertTrue(
            scaffold.contains("bottomContentInset(dynamicTypeSize:"),
            "Scroll mode should apply breathing-room padding inside scroll content."
        )
        XCTAssertTrue(
            scaffold.contains("scrollBounceBehavior(.basedOnSize)"),
            "Short main-tab pages should not bounce when content fits the viewport."
        )
        XCTAssertTrue(
            scaffold.contains("MainTabBottomAccessoryInsetModifier"),
            "Empty bottom accessories must not reserve a bottom safe-area inset."
        )
        XCTAssertFalse(
            scaffold.contains("UIScrollView.appearance()"),
            "Do not disable bounce globally via UIScrollView appearance."
        )
    }

    // MARK: - 2. Coach empty

    func testCoachEmptyStateShowsPageHeaderTodayContextAndQuickActions() throws {
        let conversation = try productionSource(
            "Fitness Coach/Features/Coach/Components/CoachConversationView.swift"
        )
        let emptyState = try productionSource(
            "Fitness Coach/Features/Coach/Components/CoachEmptyState.swift"
        )
        let starters = try productionSource(
            "Fitness Coach/Features/Coach/Components/CoachStarterPrompt.swift"
        )

        XCTAssertTrue(conversation.contains("CoachPageHeader"))
        XCTAssertTrue(conversation.contains("CoachEmptyState"))
        XCTAssertTrue(emptyState.contains("SectionLabel(title: FormaProductCopy.Coach.todaySoFarSectionTitle)"))
        XCTAssertTrue(emptyState.contains("CoachTodayContextCard"))
        XCTAssertTrue(starters.contains("Log a meal"))
        XCTAssertTrue(starters.contains("Add 500ml water"))
        XCTAssertTrue(starters.contains("Photo meal"))
        XCTAssertTrue(starters.contains("Daily review"))
    }

    func testCoachComposerUsesBottomSafeAreaInsetNotLegacyPadding() throws {
        let violations = CoachLayoutGuard.scan(repositoryRoot: repositoryRoot)
        if violations.isEmpty { return }
        XCTFail("Coach layout guard failed:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - 3. Coach active chat

    func testCoachActiveChatUsesConversationHeaderSubtitle() throws {
        let header = try productionSource(
            "Fitness Coach/Features/Coach/Components/CoachPageHeader.swift"
        )
        let conversation = try productionSource(
            "Fitness Coach/Features/Coach/Components/CoachConversationView.swift"
        )
        XCTAssertTrue(header.contains("FormaProductCopy.Coach.chatHeaderSubtitle"))
        XCTAssertEqual(
            FormaProductCopy.Coach.chatHeaderSubtitle,
            "Ask, log, or review your day."
        )
        XCTAssertTrue(conversation.contains("messages.isEmpty ? .dashboard : .conversation"))
    }

    func testCoachScrollAnchorsLatestMessageAboveComposer() throws {
        let conversation = try productionSource(
            "Fitness Coach/Features/Coach/Components/CoachConversationView.swift"
        )
        XCTAssertTrue(conversation.contains("CoachConversationScrollAnchor.bottom"))
        XCTAssertTrue(conversation.contains("safeAreaInset(edge: .bottom"))
        XCTAssertTrue(conversation.contains("scrollBounceBehavior(.basedOnSize)"))
        XCTAssertTrue(
            conversation.contains("bottomContentInset(dynamicTypeSize:"),
            "Coach transcript should use shared breathing-room padding, not a second tab-bar spacer."
        )
    }

    // MARK: - 4. Journey

    func testJourneyUsesSharedScaffoldAndYourJourneySection() throws {
        let journeyView = try productionSource("Fitness Coach/Features/Journey/JourneyView.swift")
        let dashboard = try productionSource(
            "Fitness Coach/Features/Journey/Components/JourneyDashboardContent.swift"
        )

        XCTAssertTrue(journeyView.contains("MainTabPageScaffold"))
        XCTAssertTrue(journeyView.contains("FormaProductCopy.Journey.Header.title"))
        XCTAssertTrue(journeyView.contains("FormaProductCopy.Journey.Header.subtitle"))
        XCTAssertTrue(dashboard.contains("FormaProductCopy.Journey.Hero.sectionTitle"))
        XCTAssertEqual(
            FormaProductCopy.Journey.Hero.sectionTitle.lowercased(),
            "your journey"
        )
    }

    // MARK: - 5. Plan

    func testPlanUsesCompactAdjustPillAndPreservesAdjustFlow() throws {
        let violations = PlanLayoutGuard.scan(repositoryRoot: repositoryRoot)
        if violations.isEmpty { return }
        XCTFail("Plan layout guard failed:\n\(violations.joined(separator: "\n"))")
    }

    func testPlanDashboardShowsHighROISectionsOnly() throws {
        let content = try productionSource(
            "Fitness Coach/Features/Plan/Components/PlanDashboardContent.swift"
        )
        XCTAssertTrue(content.contains("PlanMissionControlHeroSection"))
        XCTAssertTrue(content.contains("PlanDailyTargetsSection"))
        XCTAssertTrue(content.contains("PlanWeeklyRecommendationSection"))
        XCTAssertTrue(content.contains("PlanConfidenceSection"))
        XCTAssertTrue(content.contains("PlanReviewSection"))
        XCTAssertTrue(content.contains("PlanSettingsAccessRow"))
        XCTAssertFalse(content.contains("PlanStatusSection("))
        XCTAssertFalse(content.contains("PlanRationaleSection("))
        XCTAssertFalse(content.contains("PlanAdjustmentRulesSection("))
        XCTAssertFalse(content.contains("PlanAssumptionsSection("))
        XCTAssertFalse(content.contains("PlanAdjustPlanCTASection("))
    }

    func testPlanRemovedFloatingHeaderGearAndLegacyAdjustFromHeader() throws {
        let planView = try productionSource("Fitness Coach/Features/Plan/PlanView.swift")
        XCTAssertFalse(planView.contains("gearshape"))
        XCTAssertFalse(planView.contains("planHeaderTrailingActions"))
        XCTAssertTrue(planView.contains("FormaProductCopy.PlanMissionControl.adjustPlanPill"))
    }

    // MARK: - 6. Theme behavior

    func testSharedLayoutComponentsObserveLiveTheme() {
        let violations = MainTabSharedLayoutThemeGuard.scan(repositoryRoot: repositoryRoot)
        if violations.isEmpty { return }
        XCTFail("Shared layout theme guard failed:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - 7. Layout behavior

    func testResponsiveLayoutGuardPasses() {
        let violations = MainTabResponsiveLayoutGuard.scan(repositoryRoot: repositoryRoot)
        if violations.isEmpty { return }
        XCTFail("Responsive layout guard failed:\n\(violations.joined(separator: "\n"))")
    }

    func testAllFourTabsUseMainTabPageScaffold() throws {
        for relativePath in [
            "Fitness Coach/Features/Today/TodayView.swift",
            "Fitness Coach/Features/Coach/CoachView.swift",
            "Fitness Coach/Features/Journey/JourneyView.swift",
            "Fitness Coach/Features/Plan/PlanView.swift"
        ] {
            let source = try productionSource(relativePath)
            XCTAssertTrue(
                source.contains("MainTabPageScaffold"),
                "\(relativePath) must use MainTabPageScaffold."
            )
        }
    }

    // MARK: - 8. Build / preview coverage

    func testMainTabLayoutPreviewFixturesCoverTabTops() {
        let fixtureNames = Set(MainTabLayoutSnapshotFixture.allCases.map(\.rawValue))
        XCTAssertTrue(fixtureNames.isSuperset(of: [
            "todayTop",
            "coachEmptyTop",
            "coachActiveChatTop",
            "journeyTop",
            "planTop"
        ]))
    }

    // MARK: - Helpers

    private func productionSource(_ relativePath: String) throws -> String {
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
        if let previewStart = source.range(of: "#Preview") {
            return String(source[..<previewStart.lowerBound])
        }
        return source
    }
}

/// Human-readable manual QA script for unified main-tab layouts.
enum MainTabLayoutManualQAChecklist {

    struct Section: Identifiable {
        let id: String
        let title: String
        let steps: [String]
        let expected: [String]
    }

    static let sections: [Section] = [
        Section(
            id: "today",
            title: "Today",
            steps: [
                "Open Today on a loaded day.",
                "Confirm large title and date subtitle at the top.",
                "If mission status is needs focus, confirm the pill aligns with the title row.",
                "Scroll through mission, water quick-add, and meals.",
                "Tap a water preset and log a meal via Coach."
            ],
            expected: [
                "Today's Mission appears directly below the header.",
                "Water quick-add buttons respond.",
                "Page content uses the full height above the tab bar with no large empty lower block.",
                "Last scroll content clears the floating tab bar."
            ]
        ),
        Section(
            id: "coach-empty",
            title: "Coach empty / dashboard",
            steps: [
                "Open Coach with an empty transcript.",
                "Confirm Coach title, dashboard subtitle, Today so far card, and quick actions.",
                "Exercise Log a meal, Add 500ml water, Photo meal, and Daily review.",
                "Confirm composer stays pinned above the tab bar."
            ],
            expected: [
                "Header and empty-state content scroll together.",
                "No large empty block between content and the tab bar.",
                "Input bar never collides with the tab bar."
            ]
        ),
        Section(
            id: "coach-active",
            title: "Coach active chat",
            steps: [
                "Send a message and confirm conversation subtitle.",
                "Open keyboard and send another message.",
                "Use plus / photo / mic controls.",
                "Scroll to the latest message."
            ],
            expected: [
                "Subtitle reads “Ask, log, or review your day.”",
                "Keyboard does not break layout.",
                "Latest message stays above the composer."
            ]
        ),
        Section(
            id: "journey",
            title: "Journey",
            steps: [
                "Open Journey on a loaded dashboard.",
                "Confirm header and YOUR JOURNEY section.",
                "Use Log today CTA and open Goal Projection.",
                "Scroll to Weekly Review."
            ],
            expected: [
                "Page content uses the full height above the tab bar with no large empty lower block.",
                "Weekly Review card is not covered by the tab bar."
            ]
        ),
        Section(
            id: "plan",
            title: "Plan",
            steps: [
                "Open Plan on a loaded dashboard.",
                "Confirm header, subtitle, compact Adjust pill.",
                "Tap Adjust and confirm PlanEditWizard opens.",
                "Review Strategy, Daily Targets, Weekly Recommendation, and compact Plan Confidence.",
                "Confirm Plan Status, Why This Works, When to Adjust, Plan Assumptions, and bottom Adjust CTA are not on the scroll.",
                "Open settings from the bottom settings row."
            ],
            expected: [
                "Page content uses the full height above the tab bar with no large empty lower block.",
                "No legacy floating Adjust Plan header or header gear icon.",
                "Header Adjust is the primary adjust entry; Weekly Recommendation may still offer Review."
            ]
        ),
        Section(
            id: "theme",
            title: "Theme behavior",
            steps: [
                "Change theme in Settings.",
                "Visit Today, Coach, Journey, and Plan without killing the app."
            ],
            expected: [
                "Headers, cards, section labels, and action pills update immediately."
            ]
        ),
        Section(
            id: "layout",
            title: "Layout behavior",
            steps: [
                "Switch tabs repeatedly.",
                "Scroll each tab to top and bottom.",
                "Test iPhone SE and Pro Max simulators.",
                "Rotate if supported; watch for layout warnings."
            ],
            expected: [
                "No overlapping headers, pills, or tab-bar collisions.",
                "Large Dynamic Type wraps instead of clipping critical labels."
            ]
        ),
        Section(
            id: "build-test",
            title: "Build / test",
            steps: [
                "Clean build in Xcode.",
                "Run MainTabLayoutManualQAChecklistTests, PlanLayoutGuardTests, CoachLayoutGuardTests, MainTabSharedLayoutThemeTests, and MainTabResponsiveLayoutTests."
            ],
            expected: [
                "Zero compile errors from the layout migration.",
                "Guard tests pass."
            ]
        )
    ]
}
