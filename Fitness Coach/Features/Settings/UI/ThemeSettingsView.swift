//
//  ThemeSettingsView.swift
//  Fitness Coach
//
//  Forma — Appearance and color theme preferences.
//

import SwiftUI

struct ThemeSettingsView: View {

    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        List {
            appearanceSection
            colorThemeSection
        }
        .formaGroupedList()
        .navigationTitle(FormaProductCopy.Settings.Theme.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
        .onAppear {
            themeStore.recordSettingsViewed()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var appearanceSection: some View {
        if AppAppearanceMode.settingsSelectableCases.count > 1 {
            appearanceOptionsSection
        }
    }

    private var appearanceOptionsSection: some View {
        Section {
            ForEach(AppAppearanceMode.settingsSelectableCases) { mode in
                ThemeAppearanceOptionRow(
                    mode: mode,
                    isSelected: themeStore.appearance == mode,
                    onSelect: { themeStore.setAppearance(mode) }
                )
                .formaSettingsRowChrome()
            }
        } header: {
            FormaSettingsSectionHeader(title: FormaProductCopy.Settings.Theme.appearanceSectionTitle)
        }
    }

    private var colorThemeSection: some View {
        Section {
            ForEach(AppThemePalette.allCases) { palette in
                ThemeColorPaletteOptionRow(
                    palette: palette,
                    previewPalette: themeStore.previewLegacyThemePalette(
                        for: palette,
                        resolvingWith: systemColorScheme
                    ),
                    isSelected: themeStore.palette == palette,
                    onSelect: { themeStore.setPalette(palette) }
                )
                .formaSettingsRowChrome()
            }
        } header: {
            FormaSettingsSectionHeader(title: FormaProductCopy.Settings.Theme.colorThemeSectionTitle)
        }
    }
}

// MARK: - Appearance row

private struct ThemeAppearanceOptionRow: View {
    let mode: AppAppearanceMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(mode.description)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
            .padding(.vertical, 2)
            .padding(FormaTokens.Spacing.xs)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                        .fill(FormaTokens.Theme.softBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                                .stroke(FormaTokens.Theme.primary.opacity(0.72), lineWidth: 1.4)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode.accessibilityLabel(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Color palette row

private struct ThemeColorPaletteOptionRow: View {
    let palette: AppThemePalette
    let previewPalette: FormaThemePalette
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                    Image(systemName: previewPalette.iconSymbol)
                        .font(.title3)
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(palette.displayName)
                            .font(FormaTokens.Typography.body)
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(palette.description)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(FormaTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(FormaTokens.Theme.primary)
                            .accessibilityHidden(true)
                    }
                }

                ThemePalettePreviewSwatches(palette: previewPalette)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .padding(FormaTokens.Spacing.xs)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                        .fill(FormaTokens.Theme.softBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                                .stroke(FormaTokens.Theme.primary.opacity(0.72), lineWidth: 1.4)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(palette.accessibilityLabel(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Swatches

struct ThemePalettePreviewSwatches: View {
    let palette: FormaThemePalette

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            ForEach(Array(palette.previewSwatches.enumerated()), id: \.offset) { index, swatch in
                Circle()
                    .fill(swatch)
                    .overlay {
                        Circle()
                            .stroke(FormaTokens.Color.border, lineWidth: 1)
                    }
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("theme-swatch-\(index)")
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Ocean Blue Light") {
    ThemeSettingsPreviewHost(appearance: .light, palette: .oceanBlue)
}

#Preview("Blossom Pink Light") {
    ThemeSettingsPreviewHost(appearance: .light, palette: .blossomPink)
}

#Preview("Emerald Green Light") {
    ThemeSettingsPreviewHost(appearance: .light, palette: .emeraldGreen)
}

#Preview("Sunset Orange Light") {
    ThemeSettingsPreviewHost(appearance: .light, palette: .sunsetOrange)
}

#Preview("Ocean Blue Dark") {
    ThemeSettingsPreviewHost(appearance: .dark, palette: .oceanBlue)
}

#Preview("Blossom Pink Dark") {
    ThemeSettingsPreviewHost(appearance: .dark, palette: .blossomPink)
}

#Preview("Emerald Green Dark") {
    ThemeSettingsPreviewHost(appearance: .dark, palette: .emeraldGreen)
}

#Preview("Sunset Orange Dark") {
    ThemeSettingsPreviewHost(appearance: .dark, palette: .sunsetOrange)
}

private struct ThemeSettingsPreviewHost: View {
    let appearance: AppAppearanceMode
    let palette: AppThemePalette

    @StateObject private var store: ThemeStore

    init(appearance: AppAppearanceMode, palette: AppThemePalette) {
        self.appearance = appearance
        self.palette = palette
        let defaults = UserDefaults(suiteName: "ThemeSettingsPreview.\(UUID().uuidString)")!
        let store = ThemeStore(userDefaults: defaults)
        store.setAppearance(appearance)
        store.setPalette(palette)
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            ThemeSettingsView()
        }
        .environmentObject(store)
        .formaThemePreview(appearance: appearance, palette: palette)
    }
}
