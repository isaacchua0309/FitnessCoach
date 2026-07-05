//
//  FormaThemeEnvironment.swift
//  Fitness Coach
//
//  Forma — SwiftUI environment for the resolved theme.
//

import SwiftUI

enum FormaThemeEnvironment {

    static let defaultResolvedTheme = ResolvedAppTheme.resolve(
        preferences: .default,
        systemColorScheme: .dark
    )
}

// MARK: - Environment keys

private struct FormaResolvedThemeKey: EnvironmentKey {
    static let defaultValue = FormaThemeEnvironment.defaultResolvedTheme
}

private struct FormaColorsKey: EnvironmentKey {
    static let defaultValue = FormaThemeEnvironment.defaultResolvedTheme.colors
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = FormaThemeEnvironment.defaultResolvedTheme.themePalette
}

private struct ThemeTokensKey: EnvironmentKey {
    static let defaultValue = ThemeTokensProvider.productDefault
}

private struct FormaPlanColorsKey: EnvironmentKey {
    static let defaultValue = PlanThemeColorProvider.productDefault
}

extension EnvironmentValues {

    /// Fully resolved appearance + palette for the active screen tree.
    var formaResolvedTheme: ResolvedAppTheme {
        get { self[FormaResolvedThemeKey.self] }
        set {
            self[FormaResolvedThemeKey.self] = newValue
            self[FormaColorsKey.self] = newValue.colors
            self[ThemePaletteKey.self] = newValue.themePalette
            self[ThemeTokensKey.self] = ThemeTokensProvider.tokens(from: newValue)
            self[FormaPlanColorsKey.self] = PlanThemeColorProvider.planColors(from: newValue)
        }
    }

    /// Canonical semantic theme roles for the active resolved theme.
    var theme: ThemeTokens {
        get { self[ThemeTokensKey.self] }
        set { self[ThemeTokensKey.self] = newValue }
    }

    /// Semantic color palette for the active resolved theme.
    var formaColors: FormaColorPalette {
        get { self[FormaColorsKey.self] }
        set { self[FormaColorsKey.self] = newValue }
    }

    /// Canonical theme accent tokens for the active user palette.
    var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }

    /// Semantic colors for the Edit / Adjust Plan flow.
    var formaPlanColors: FormaPlanColors {
        get { self[FormaPlanColorsKey.self] }
        set { self[FormaPlanColorsKey.self] = newValue }
    }
}

// MARK: - Root injection

struct FormaThemeRootState: Equatable, Sendable {
    let resolved: ResolvedAppTheme
    let legacyPalette: FormaThemePalette
    let preferredColorScheme: ColorScheme?

    @MainActor
    static func make(
        store: ThemeStore,
        systemColorScheme: ColorScheme
    ) -> FormaThemeRootState {
        let resolved = store.resolvedTheme(systemColorScheme: systemColorScheme)
        let legacyPalette = store.legacyThemePalette(resolvingWith: systemColorScheme)
        return FormaThemeRootState(
            resolved: resolved,
            legacyPalette: legacyPalette,
            preferredColorScheme: store.preferredColorScheme
        )
    }
}

// MARK: - Static token reactivity

/// Establishes a SwiftUI dependency on the live theme store and resolved environment so
/// descendants that read `FormaTokens.Color` / `CoachDesignTokens.Color` (static bridge)
/// re-render when palette or appearance changes.
private struct FormaThemeReactiveModifier: ViewModifier {
    @Environment(\.formaResolvedTheme) private var resolvedTheme
    @Environment(\.theme) private var theme
    @EnvironmentObject private var themeStore: ThemeStore

    func body(content: Content) -> some View {
        let _ = resolvedTheme
        let _ = themeStore.themeRevision
        let _ = theme.accent
        return content
    }
}

extension View {

    /// Binds static token call sites to the injected resolved theme environment.
    func formaThemeReactive() -> some View {
        modifier(FormaThemeReactiveModifier())
    }
}

// MARK: - Preview helpers

extension View {

    /// Preview helper that mirrors root theme injection with a live `ThemeStore`.
    func formaThemePreview(
        appearance: AppAppearanceMode = .dark,
        palette: AppThemePalette = .oceanBlue,
        systemColorScheme: ColorScheme = .dark
    ) -> some View {
        let store = ThemeStore(userDefaults: ThemeStore.previewUserDefaults())
        store.setAppearance(appearance)
        store.setTheme(palette)
        return preferredColorScheme(ThemeResolver.preferredColorScheme(for: appearance))
            .environmentObject(store)
            .formaRootTheme()
    }

    /// Injects a fixed resolved theme (and legacy palette bridge) for previews.
    func formaResolvedTheme(_ theme: ResolvedAppTheme) -> some View {
        let store = ThemeStore(userDefaults: ThemeStore.previewUserDefaults())
        store.setAppearance(theme.preferences.appearance)
        store.setTheme(theme.preferences.palette)
        return environmentObject(store)
            .formaRootTheme()
    }

    /// Injects resolved plan-flow colors for previews and tests.
    func formaPlanColors(_ colors: FormaPlanColors) -> some View {
        environment(\.formaPlanColors, colors)
    }
}
