//
//  MainTabPageScaffold.swift
//  Fitness Coach
//
//  Forma — Shared visual shell for main tab root screens.
//

import SwiftUI

enum MainTabPageScaffoldScrollMode {
    /// Wraps content in a `ScrollView` with tab-bar clearance insets.
    case scrollView
    /// Content manages its own scrolling (Coach conversation surface).
    case embedded
}

struct MainTabScrollTarget: Equatable {
    let id: String
    var anchor: UnitPoint = .center
    /// Increment to request a scroll even when `id` is unchanged.
    var trigger: Int = 0
}

struct MainTabPageScaffold<
    TrailingAction: View,
    BottomAccessory: View,
    Content: View
>: View {
    let title: String
    var subtitle: String?
    var scrollMode: MainTabPageScaffoldScrollMode
    var sectionSpacing: CGFloat
    var showsCrossDeviceRefreshBanner: Bool
    var showsPageHeader: Bool
    var scrollTarget: MainTabScrollTarget?

    @ViewBuilder var trailingAction: () -> TrailingAction
    @ViewBuilder var bottomAccessory: () -> BottomAccessory
    @ViewBuilder var content: () -> Content

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var measuredSafeAreaBottom = FormaMainTabLayout.defaultBottomSafeAreaFallback

    init(
        title: String,
        subtitle: String? = nil,
        scrollMode: MainTabPageScaffoldScrollMode = .scrollView,
        sectionSpacing: CGFloat = FormaMainTabLayout.sectionSpacing,
        showsCrossDeviceRefreshBanner: Bool = false,
        showsPageHeader: Bool = true,
        scrollTarget: MainTabScrollTarget? = nil,
        @ViewBuilder trailingAction: @escaping () -> TrailingAction,
        @ViewBuilder bottomAccessory: @escaping () -> BottomAccessory,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrollMode = scrollMode
        self.sectionSpacing = sectionSpacing
        self.showsCrossDeviceRefreshBanner = showsCrossDeviceRefreshBanner
        self.showsPageHeader = showsPageHeader
        self.scrollTarget = scrollTarget
        self.trailingAction = trailingAction
        self.bottomAccessory = bottomAccessory
        self.content = content
    }

    var body: some View {
        let _ = themeManager.themeRevision
        let _ = theme.accent

        VStack(spacing: 0) {
            if showsPageHeader {
                PageHeader(title: title, subtitle: subtitle, trailingAction: trailingAction)
                    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
                    .padding(.top, FormaMainTabLayout.headerTopPadding)
                    .padding(.bottom, FormaMainTabLayout.headerBottomPadding)
            }

            scrollBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: MainTabSafeAreaBottomPreferenceKey.self,
                        value: geometry.safeAreaInsets.bottom
                    )
            }
        }
        .onPreferenceChange(MainTabSafeAreaBottomPreferenceKey.self) { measured in
            let resolved = measured > 0 ? measured : FormaMainTabLayout.defaultBottomSafeAreaFallback
            if measuredSafeAreaBottom != resolved {
                measuredSafeAreaBottom = resolved
            }
        }
        .background(theme.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            if showsCrossDeviceRefreshBanner {
                crossDeviceRefreshBanner
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                bottomAccessory()
                MainTabTabBarClearanceSpacer(safeAreaBottom: measuredSafeAreaBottom)
            }
        }
        .formaThemeReactive()
    }

    @ViewBuilder
    private var scrollBody: some View {
        switch scrollMode {
        case .scrollView:
            scrollViewContent
        case .embedded:
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var scrollViewContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    content()
                }
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
                .padding(.bottom, FormaMainTabLayout.scrollContentBottomPadding)
            }
            .onChange(of: scrollTarget?.trigger) { _, _ in
                guard let scrollTarget else { return }
                withAnimation {
                    proxy.scrollTo(scrollTarget.id, anchor: scrollTarget.anchor)
                }
            }
        }
    }

    private var crossDeviceRefreshBanner: some View {
        ProgressView()
            .controlSize(.small)
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.top, FormaTokens.Spacing.sm)
            .accessibilityLabel("Syncing latest updates")
    }
}

// MARK: - Convenience initializers

extension MainTabPageScaffold where TrailingAction == EmptyView, BottomAccessory == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        scrollMode: MainTabPageScaffoldScrollMode = .scrollView,
        sectionSpacing: CGFloat = FormaMainTabLayout.sectionSpacing,
        showsCrossDeviceRefreshBanner: Bool = false,
        scrollTarget: MainTabScrollTarget? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            scrollMode: scrollMode,
            sectionSpacing: sectionSpacing,
            showsCrossDeviceRefreshBanner: showsCrossDeviceRefreshBanner,
            scrollTarget: scrollTarget,
            trailingAction: { EmptyView() },
            bottomAccessory: { EmptyView() },
            content: content
        )
    }
}

extension MainTabPageScaffold where BottomAccessory == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        scrollMode: MainTabPageScaffoldScrollMode = .scrollView,
        sectionSpacing: CGFloat = FormaMainTabLayout.sectionSpacing,
        showsCrossDeviceRefreshBanner: Bool = false,
        scrollTarget: MainTabScrollTarget? = nil,
        @ViewBuilder trailingAction: @escaping () -> TrailingAction,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            scrollMode: scrollMode,
            sectionSpacing: sectionSpacing,
            showsCrossDeviceRefreshBanner: showsCrossDeviceRefreshBanner,
            scrollTarget: scrollTarget,
            trailingAction: trailingAction,
            bottomAccessory: { EmptyView() },
            content: content
        )
    }
}

extension MainTabPageScaffold where TrailingAction == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        scrollMode: MainTabPageScaffoldScrollMode = .scrollView,
        sectionSpacing: CGFloat = FormaMainTabLayout.sectionSpacing,
        showsCrossDeviceRefreshBanner: Bool = false,
        scrollTarget: MainTabScrollTarget? = nil,
        @ViewBuilder bottomAccessory: @escaping () -> BottomAccessory,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            scrollMode: scrollMode,
            sectionSpacing: sectionSpacing,
            showsCrossDeviceRefreshBanner: showsCrossDeviceRefreshBanner,
            scrollTarget: scrollTarget,
            trailingAction: { EmptyView() },
            bottomAccessory: bottomAccessory,
            content: content
        )
    }
}

#if DEBUG
#Preview {
    MainTabPageScaffold(
        title: "Today",
        subtitle: "Monday, 6 July",
        trailingAction: {
            PageActionPill(title: "Needs focus")
        }
    ) {
        MainTabCard {
            Text("Hero section")
        }
        SectionLabel(title: "Water")
        MainTabCard(style: .accentLeading) {
            Text("Quick log")
        }
    }
    .formaThemePreview()
}
#endif
