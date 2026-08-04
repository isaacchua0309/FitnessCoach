//
//  FormaThemeScreenModifier.swift
//  Fitness Coach
//
//  Forma — Applies root appearance override and propagates the resolved theme.
//

import SwiftUI

struct FormaRootThemeModifier: ViewModifier {
    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    func body(content: Content) -> some View {
        let _ = themeStore.themeRevision
        let state = FormaThemeRootState.make(store: themeStore, systemColorScheme: systemColorScheme)
        let theme = ThemeTokensProvider.tokens(from: state.resolved)
        FormaThemeAccess.update(resolved: state.resolved)

        return content
            .preferredColorScheme(state.preferredColorScheme)
            .environment(\.formaResolvedTheme, state.resolved)
            .environment(\.formaThemePalette, state.legacyPalette)
            .environment(\.theme, theme)
            // Re-publish so nested modifiers (e.g. formaThemeReactive) resolve ThemeStore.
            .environmentObject(themeStore)
            .tint(theme.tabBarSelectedIcon)
            .formaUIKitAppearance()
            .formaThemeReactive()
    }
}

extension View {

    /// Apply once at the app root. Requires `ThemeStore` / `ThemeManager` on the environment
    /// via `.environmentObject` applied *after* this modifier (ancestor), or use `formaRootTheme(store:)`.
    func formaRootTheme() -> some View {
        modifier(FormaRootThemeModifier())
    }

    /// Convenience that injects `ThemeStore` as an ancestor of the root theme modifier.
    func formaRootTheme(store: ThemeStore) -> some View {
        formaRootTheme().environmentObject(store)
    }
}

#if DEBUG
enum FormaThemeEnvironmentAssertions {

    @MainActor
    static func assertRootThemeReachable(
        from store: ThemeStore,
        systemColorScheme: ColorScheme
    ) {
        let state = FormaThemeRootState.make(store: store, systemColorScheme: systemColorScheme)
        assert(
            state.resolved.colors == store.resolvedTheme(systemColorScheme: systemColorScheme).colors,
            "Root theme state must match ThemeStore resolution."
        )
    }
}
#endif