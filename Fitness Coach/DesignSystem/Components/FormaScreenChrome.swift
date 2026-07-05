//
//  FormaScreenChrome.swift
//  Fitness Coach
//
//  Forma — Screen background and grouped-list modifiers.
//

import SwiftUI

extension View {
    func formaScreenBackground() -> some View {
        modifier(FormaScreenBackgroundModifier())
    }

    func formaGroupedList() -> some View {
        modifier(FormaGroupedListModifier())
    }

    func formaScrollBottomInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: FormaTokens.Layout.tabBarScrollPadding)
                .allowsHitTesting(false)
        }
    }

    func formaFormScreen() -> some View {
        self
            .modifier(FormaFormScreenModifier())
    }

    func formaFormSection() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    func formaSettingsRowChrome(isEnabled: Bool = true) -> some View {
        modifier(FormaSettingsRowChromeModifier(isEnabled: isEnabled))
    }

    /// Centers readable settings detail content and caps width on large phones.
    func formaSettingsDetailContent() -> some View {
        frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
    }

    /// Shared scroll layout for pushed settings detail screens.
    func formaSettingsDetailScreen<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            content()
                .formaSettingsDetailContent()
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.top, SettingsChromeAccessibility.detailPageTopPadding)
                .padding(.bottom, SettingsChromeAccessibility.detailPageBottomPadding)
        }
        .formaScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
    }
}

// MARK: - Environment-backed modifiers

private struct FormaScreenBackgroundModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(theme.appBackground.ignoresSafeArea())
    }
}

private struct FormaGroupedListModifier: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(FormaTokens.Spacing.sm)
            .scrollContentBackground(.hidden)
            .background(theme.appBackground.ignoresSafeArea())
            .tint(theme.accent)
            .onAppear {
                applyListAppearance()
            }
            .onChange(of: themeManager.selectedTheme) { _, _ in
                applyListAppearance()
            }
            .onChange(of: themeManager.themeRevision) { _, _ in
                applyListAppearance()
            }
            .onChange(of: systemColorScheme) { _, _ in
                applyListAppearance()
            }
    }

    private func applyListAppearance() {
        FormaUIKitAppearance.applyListAppearance(
            from: themeManager.tokens(systemColorScheme: systemColorScheme)
        )
    }
}

private struct FormaFormScreenModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.appBackground.ignoresSafeArea())
            .formaScrollBottomInset()
    }
}

private struct FormaSettingsRowChromeModifier: ViewModifier {
    let isEnabled: Bool

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .listRowInsets(FormaTokens.Layout.settingsRowInsets)
            .listRowBackground(SettingsListRowBackground(isEnabled: isEnabled, theme: theme))
            .allowsHitTesting(isEnabled)
    }
}

/// Decorative settings list-row fill. Must not participate in hit testing or it blocks row taps.
private struct SettingsListRowBackground: View {
    let isEnabled: Bool
    let theme: ThemeTokens

    var body: some View {
        Rectangle()
            .fill(
                isEnabled
                    ? theme.cardBackground
                    : theme.accentSoftBackground.opacity(0.45)
            )
            .allowsHitTesting(false)
    }
}
