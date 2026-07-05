    /// Mirrors `JourneyDashboardContent.visibleSections` for deterministic QA.
    static func visibleSections(
        for state: JourneyDashboardState,
        healthIntelligenceUIEnabled: Bool = false,
        healthIntelligenceSectionState: JourneyHealthIntelligenceSectionState? = nil
    ) -> [JourneyProductSection] {
        JourneyProductLayout.sectionOrder.filter { section in
            switch section {
            case .hero:
                return state.showsDashboardHeroSection
            case .nextAction:
                return state.showsNextActionSection
            case .weeklyProgress:
                return state.showsWeeklyProgressSection
            case .progress:
                return state.showsProgressSection
            case .highlights:
                return JourneyDashboardCompositionPolicy.showsHighlightsSection(
                    isUIEnabled: healthIntelligenceUIEnabled,
                    sectionState: healthIntelligenceSectionState
                )
            case .storyTimeline:
                return state.showsStoryTimelineSection
            case .chapters:
                return state.showsChapterSection
            }
        }
    }
