//
//  FormaThemeScreenModifier.swift
//  Fitness Coach
//
//  Forma — Applies root appearance override and propagates the resolved theme.
//

import SwiftUI

struct FormaRootThemeModifier: ViewModifier {
    @ObservedObject var store: ThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    func body(content: Content) -> some View {
        let state = FormaThemeRootState.make(store: store, systemColorScheme: systemColorScheme)
        FormaThemeAccess.update(resolved: state.resolved)

        return content
            .preferredColorScheme(state.preferredColorScheme)
            .environment(\.formaResolvedTheme, state.resolved)
            .environment(\.formaThemePalette, state.legacyPalette)
            .tint(state.resolved.colors.accent)
    }
}

extension View {

    /// Apply once at the app root. Do not nest inside feature screens.
    func formaRootTheme(store: ThemeStore) -> some View {
        modifier(FormaRootThemeModifier(store: store))
    }

    /// Deprecated — use `formaRootTheme(store:)` at the app root only.
    func formaThemeScreen(store: ThemeStore) -> some View {
        formaRootTheme(store: store)
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
