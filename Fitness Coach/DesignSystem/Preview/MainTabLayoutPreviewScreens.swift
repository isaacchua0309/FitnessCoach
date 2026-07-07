//
//  MainTabLayoutPreviewScreens.swift
//  Fitness Coach
//
//  Forma — Shared main-tab layout component and tab-top preview catalog.
//  Uses static mock data only; no Firebase, OpenAI, or network access required.
//

import SwiftUI

#if DEBUG

enum MainTabLayoutPreviewScreens {

    enum Metrics {
        /// Standard iPhone preview width.
        static let previewWidth: CGFloat = 390
        /// Height that captures page header plus the first dashboard sections.
        static let topLayoutHeight: CGFloat = 520
        /// Full-phone height for chat and scroll snapshots.
        static let fullPhoneHeight: CGFloat = 844
    }

    // MARK: - Shared components

    static func pageHeaderTitleOnly(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        PageHeader(title: FormaProductCopy.Today.Header.title)
            .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
            .padding(.vertical, FormaMainTabLayout.headerTopPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FormaTokens.Color.canvas)
            .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func pageHeaderWithSubtitle(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        PageHeader(
            title: FormaProductCopy.Journey.Header.title,
            subtitle: FormaProductCopy.Journey.Header.subtitle
        )
        .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
        .padding(.vertical, FormaMainTabLayout.headerTopPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func pageHeaderWithTrailingPill(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        PageHeader(
            title: FormaProductCopy.Today.Header.title,
            subtitle: MainTabLayoutPreviewFixtures.todayDateLine,
            trailingAction: {
                PageActionPill(title: FormaProductCopy.Today.Header.planStatusNeedsFocus)
            }
        )
        .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
        .padding(.vertical, FormaMainTabLayout.headerTopPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func sectionLabels(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaMainTabLayout.sectionSpacing) {
            SectionLabel(title: FormaProductCopy.Today.Mission.sectionTitle)
            SectionLabel(title: FormaProductCopy.Today.MacroBalance.sectionTitle, style: .muted)
            SectionLabel(title: FormaProductCopy.Coach.quickActionsSectionTitle)
        }
        .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func mainTabCards(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaMainTabLayout.sectionSpacing) {
                cardStyleSample(
                    title: "Surface",
                    style: .surface,
                    compact: false
                )
                cardStyleSample(
                    title: "Surface subtle · compact",
                    style: .surfaceSubtle,
                    compact: true
                )
                cardStyleSample(
                    title: "Accent leading",
                    style: .accentLeading,
                    compact: false
                )
                cardStyleSample(
                    title: "Bordered · compact",
                    style: .bordered,
                    compact: true
                )
            }
            .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func scaffoldSample(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        MainTabPageScaffold(
            title: FormaProductCopy.Today.Header.title,
            subtitle: MainTabLayoutPreviewFixtures.todayDateLine,
            trailingAction: {
                PageActionPill(title: FormaProductCopy.Today.Header.planStatusNeedsFocus)
            }
        ) {
            SectionLabel(title: FormaProductCopy.Today.Mission.sectionTitle)
            MainTabCard(style: .accentLeading) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    MainTabHeroText("1,420", tier: .primary)
                    Text("Remaining today")
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                }
            }

            SectionLabel(title: FormaProductCopy.Today.Water.sectionTitle)
            MainTabCard(style: .surfaceSubtle, compact: true) {
                Text("Quick log row")
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
            }
        }
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    // MARK: - Tab top layouts

    static func todayTop(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        let state = TodayPreviewData.partialDay
        return MainTabPageScaffold(
            title: FormaProductCopy.Today.Header.title,
            subtitle: TodayDashboardHeaderFormatting.dateLine(for: state.date),
            sectionSpacing: TodayLayout.sectionSpacing,
            trailingAction: {
                if let planStatusChip = TodayDashboardHeaderFormatting.planStatusChip(for: state.mission.status) {
                    PageActionPill(title: planStatusChip)
                }
            }
        ) {
            TodayReadOnlyView(
                state: state,
                actionCoordinator: TodayReadOnlyPreviewSupport.coordinator()
            )
        }
        .frame(height: Metrics.topLayoutHeight)
        .clipped()
        .todayLiveTheme()
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func coachEmptyTop(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        MainTabPageScaffold(
            title: FormaProductCopy.Coach.screenTitle,
            scrollMode: .embedded,
            showsPageHeader: false
        ) {
            CoachConversationView(
                messages: [],
                isSending: false,
                todayContext: MainTabLayoutPreviewFixtures.coachTodayContext,
                starterPrompts: CoachStarterPrompt.defaultQuickActionSpecs,
                isInputFocused: false
            ) {
                MainTabLayoutPreviewComposerStub()
            }
        }
        .frame(height: Metrics.topLayoutHeight)
        .clipped()
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func coachActiveChatTop(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        MainTabPageScaffold(
            title: FormaProductCopy.Coach.screenTitle,
            scrollMode: .embedded,
            showsPageHeader: false
        ) {
            CoachConversationView(
                messages: MainTabLayoutPreviewFixtures.coachActiveMessages,
                isSending: false,
                isInputFocused: false
            ) {
                MainTabLayoutPreviewComposerStub()
            }
        }
        .frame(height: Metrics.fullPhoneHeight)
        .clipped()
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func journeyTop(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        JourneyPreviewScreens.dashboard(.strongMomentum, palette: palette)
            .frame(height: Metrics.topLayoutHeight)
            .clipped()
    }

    static func planTop(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        PlanPreviewScreens.screen(.aggressiveCut, palette: palette, appearance: appearance)
            .frame(height: Metrics.topLayoutHeight)
            .clipped()
    }

    // MARK: - Snapshot routing

    static func snapshotView(
        for fixture: MainTabLayoutSnapshotFixture,
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        switch fixture {
        case .pageHeaderTitleOnly:
            pageHeaderTitleOnly(palette: palette, appearance: appearance)
        case .pageHeaderWithSubtitle:
            pageHeaderWithSubtitle(palette: palette, appearance: appearance)
        case .pageHeaderWithTrailingPill:
            pageHeaderWithTrailingPill(palette: palette, appearance: appearance)
        case .sectionLabels:
            sectionLabels(palette: palette, appearance: appearance)
        case .mainTabCards:
            mainTabCards(palette: palette, appearance: appearance)
        case .scaffoldSample:
            scaffoldSample(palette: palette, appearance: appearance)
        case .todayTop:
            todayTop(palette: palette, appearance: appearance)
        case .coachEmptyTop:
            coachEmptyTop(palette: palette, appearance: appearance)
        case .coachActiveChatTop:
            coachActiveChatTop(palette: palette, appearance: appearance)
        case .journeyTop:
            journeyTop(palette: palette, appearance: appearance)
        case .planTop:
            planTop(palette: palette, appearance: appearance)
        }
    }

    // MARK: - Private

    @ViewBuilder
    private static func cardStyleSample(
        title: String,
        style: FormaCardChrome.Style,
        compact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaMainTabLayout.sectionContentSpacing) {
            SectionLabel(title: title, style: .muted)
            MainTabCard(style: style, compact: compact) {
                Text("Sample card content")
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
            }
        }
    }
}

enum MainTabLayoutSnapshotFixture: String, CaseIterable {
    case pageHeaderTitleOnly
    case pageHeaderWithSubtitle
    case pageHeaderWithTrailingPill
    case sectionLabels
    case mainTabCards
    case scaffoldSample
    case todayTop
    case coachEmptyTop
    case coachActiveChatTop
    case journeyTop
    case planTop

    var exportHeight: CGFloat {
        switch self {
        case .coachActiveChatTop:
            return MainTabLayoutPreviewScreens.Metrics.fullPhoneHeight
        case .mainTabCards, .scaffoldSample:
            return MainTabLayoutPreviewScreens.Metrics.fullPhoneHeight
        default:
            return MainTabLayoutPreviewScreens.Metrics.topLayoutHeight
        }
    }
}

private enum MainTabLayoutPreviewFixtures {
    static var todayDateLine: String {
        TodayDashboardHeaderFormatting.dateLine(for: TodayPreviewData.partialDay.date)
    }

    static var coachTodayContext: CoachTodayContextState {
        CoachTodayContextState(
            caloriesLine: "1,420 eaten · 2,086 target",
            proteinLine: "Protein 112 / 198 g",
            waterLine: "Water 1,800 / 3,150 ml",
            activityLines: ["8,420 steps"],
            activityHintLine: nil,
            suggestedFocus: FormaProductCopy.Today.focusProteinLow
        )
    }

    static var coachActiveMessages: [ChatMessage] {
        CoachPreviewData.messages + [CoachPreviewData.confirmationMessage]
    }
}

private struct MainTabLayoutPreviewComposerStub: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        CoachComposer(
            text: $text,
            canPickAttachment: true,
            isFocused: $isFocused,
            isSending: false,
            onSend: {},
            onVoiceTap: {},
            onAttachmentSelect: { _ in },
            onRemoveAttachment: {},
            onRetryImageSelection: {}
        )
        .padding(.horizontal, FormaTokens.Spacing.md)
    }
}

// MARK: - Shared component previews

#Preview("PageHeader — title only") {
    MainTabLayoutPreviewScreens.pageHeaderTitleOnly()
}

#Preview("PageHeader — title + subtitle") {
    MainTabLayoutPreviewScreens.pageHeaderWithSubtitle()
}

#Preview("PageHeader — trailing pill") {
    MainTabLayoutPreviewScreens.pageHeaderWithTrailingPill()
}

#Preview("SectionLabel") {
    MainTabLayoutPreviewScreens.sectionLabels()
}

#Preview("MainTabCard — styles") {
    MainTabLayoutPreviewScreens.mainTabCards()
}

#Preview("MainTabPageScaffold — sample") {
    MainTabLayoutPreviewScreens.scaffoldSample()
}

// MARK: - Tab top layout previews

#Preview("Today — top layout") {
    MainTabLayoutPreviewScreens.todayTop()
        .frame(width: MainTabLayoutPreviewScreens.Metrics.previewWidth)
}

#Preview("Coach — empty top layout") {
    MainTabLayoutPreviewScreens.coachEmptyTop()
        .frame(width: MainTabLayoutPreviewScreens.Metrics.previewWidth)
}

#Preview("Coach — active chat top layout") {
    MainTabLayoutPreviewScreens.coachActiveChatTop()
        .frame(width: MainTabLayoutPreviewScreens.Metrics.previewWidth)
}

#Preview("Journey — top layout") {
    MainTabLayoutPreviewScreens.journeyTop()
        .frame(width: MainTabLayoutPreviewScreens.Metrics.previewWidth)
}

#Preview("Plan — top layout") {
    MainTabLayoutPreviewScreens.planTop()
        .frame(width: MainTabLayoutPreviewScreens.Metrics.previewWidth)
}

// MARK: - Theme matrix (shared components)

#Preview("PageHeader pill — Blossom Pink") {
    MainTabLayoutPreviewScreens.pageHeaderWithTrailingPill(palette: .blossomPink)
}

#Preview("Scaffold sample — Emerald Green") {
    MainTabLayoutPreviewScreens.scaffoldSample(palette: .emeraldGreen)
}

#Preview("Today top — Sunset Orange") {
    MainTabLayoutPreviewScreens.todayTop(palette: .sunsetOrange)
        .frame(width: MainTabLayoutPreviewScreens.Metrics.previewWidth)
}

#endif
