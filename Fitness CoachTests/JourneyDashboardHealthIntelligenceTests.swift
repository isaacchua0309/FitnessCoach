//
//  JourneyDashboardHealthIntelligenceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyDashboardHealthIntelligenceTests: XCTestCase {

    func testHighlightsAppearsAfterProgressInLayout() {
        let order = JourneyProductLayout.sectionOrder
        let progressIndex = order.firstIndex(of: .progress)
        let highlightsIndex = order.firstIndex(of: .highlights)
        let storyIndex = order.firstIndex(of: .storyTimeline)

        XCTAssertEqual(progressIndex, 3)
        XCTAssertEqual(highlightsIndex, 4)
        XCTAssertEqual(storyIndex, 5)
    }

    func testVisibleSectionsExcludeLegacyHealthIntelligenceMount() {
        let sections = JourneyDashboardSectionSupport.visibleSections(
            for: JourneyPreviewData.strongMomentum,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: JourneyHealthIntelligencePreviewData.strongWeek
        )

        XCTAssertFalse(sections.contains(.highlights))
        XCTAssertTrue(sections.contains(.highlights))
    }

    func testVisibleSectionsExcludeHighlightsWhenStateMissing() {
        let sections = JourneyDashboardSectionSupport.visibleSections(
            for: JourneyPreviewData.strongMomentum,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: nil
        )

        XCTAssertFalse(sections.contains(.highlights))
    }

    func testHealthIntelligenceSectionStateStillBuildsMilestonePayload() {
        let section = JourneyHealthIntelligencePreviewData.strongWeek

        XCTAssertEqual(section.milestones.phase, .loaded)
        XCTAssertFalse(section.milestones.items.isEmpty)
        XCTAssertEqual(section.progress.phase, .loaded)
    }
}
