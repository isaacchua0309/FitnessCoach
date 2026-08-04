//
//  MainTabPageScaffold.swift
//  Fitness Coach
//
//  Forma — Shared visual shell for main tab root screens.
//

import SwiftUI

enum MainTabPageScaffoldScrollMode {
    /// Wraps content in a `ScrollView` with scroll-content breathing-room padding.
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

        pageShell
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(theme.appBackground.ignoresSafeArea())
            .overlay(alignment: .top) {
                if showsCrossDeviceRefreshBanner {
                    crossDeviceRefreshBanner
                }
            }
            // Only real bottom chrome (e.g. future accessories) may reserve bottom safe area.
            // Never feed measured safeAreaInsets.bottom back into a clearance spacer here —
            // that creates a layout feedback loop that shrinks the scroll viewport until
            // page content can be dragged fully off-screen.
            .modifier(MainTabBottomAccessoryInsetModifier(accessory: bottomAccessory))
            .formaThemeReactive()
    }

    private var pageShell: some View {
        VStack(spacing: 0) {
            if showsPageHeader {
                PageHeader(title: title, subtitle: subtitle, trailingAction: trailingAction)
                    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
                    .padding(.top, FormaMainTabLayout.headerTopPadding)
                    .padding(.bottom, FormaMainTabLayout.headerBottomPadding)
            }

            scrollBody
        }
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
                // Breathing room only. System TabView already owns tab-bar + home-indicator insets.
                .padding(.bottom, FormaMainTabLayout.bottomContentInset(dynamicTypeSize: dynamicTypeSize))
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// Applies a bottom `safeAreaInset` only when the accessory is a real view.
/// `EmptyView` accessories must not reserve layout space on tab-root screens.
private struct MainTabBottomAccessoryInsetModifier<Accessory: View>: ViewModifier {
    @ViewBuilder var accessory: () -> Accessory

    @ViewBuilder
    func body(content: Content) -> some View {
        if Accessory.self == EmptyView.self {
            content
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                accessory()
            }
        }
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
        showsPageHeader: Bool = true,
        scrollTarget: MainTabScrollTarget? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            scrollMode: scrollMode,
            sectionSpacing: sectionSpacing,
            showsCrossDeviceRefreshBanner: showsCrossDeviceRefreshBanner,
            showsPageHeader: showsPageHeader,
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
        showsPageHeader: Bool = true,
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
            showsPageHeader: showsPageHeader,
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
        showsPageHeader: Bool = true,
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
            showsPageHeader: showsPageHeader,
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
