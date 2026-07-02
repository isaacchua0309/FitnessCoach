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

    private var resolvedPreviewColorScheme: ColorScheme {
        ThemeResolver.resolveColorScheme(
            appearance: themeStore.appearance,
            systemColorScheme: systemColorScheme
        )
    }

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
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: FormaTokens.Spacing.sm),
                    GridItem(.flexible(), spacing: FormaTokens.Spacing.sm)
                ],
                spacing: FormaTokens.Spacing.sm
            ) {
                ForEach(AppThemePalette.allCases) { palette in
                    ThemePremiumPickerCard(
                        palette: palette,
                        preview: ThemePaletteCatalog.palette(
                            for: palette,
                            colorScheme: resolvedPreviewColorScheme
                        ),
                        isSelected: themeStore.palette == palette,
                        onSelect: { selectPalette(palette) }
                    )
                }
            }
            .padding(.vertical, FormaTokens.Spacing.xs)
            .formaFormSection()
        } header: {
            FormaSettingsSectionHeader(title: FormaProductCopy.Settings.Theme.colorThemeSectionTitle)
        }
    }

    private func selectPalette(_ palette: AppThemePalette) {
        guard themeStore.palette != palette else { return }
        ThemeSettingsHaptics.selectionChanged()
        themeStore.setPalette(palette)
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

// MARK: - Premium theme card

private struct ThemePremiumPickerCard: View {
    let palette: AppThemePalette
    let preview: ThemePalette
    let isSelected: Bool
    let onSelect: () -> Void

    private let cardCornerRadius = FormaCardChrome.cornerRadius
    private let previewCornerRadius: CGFloat = 10

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                gradientPreview

                HStack(spacing: 6) {
                    ThemeColorTokenDot(color: preview.primary)
                    ThemeColorTokenDot(color: preview.secondary)
                    ThemeColorTokenDot(color: preview.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(preview.displayName)
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(preview.subtitle)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: FormaTokens.Layout.minTouchTarget, alignment: .topLeading)
            .padding(FormaTokens.Spacing.sm)
            .background(cardBackground)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    selectedCheckmark
                        .padding(FormaTokens.Spacing.xs)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(palette.accessibilityLabel(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var gradientPreview: some View {
        RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
            .fill(preview.primaryGradient)
            .frame(height: 40)
            .overlay {
                RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                    .stroke(FormaTokens.Color.border.opacity(0.25), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    private var selectedCheckmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.body.weight(.semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(preview.textOnAccent, preview.primary)
            .shadow(color: preview.primary.opacity(0.35), radius: 4, y: 1)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(isSelected ? preview.softBackground : FormaTokens.Color.surfaceSubtle)
            .overlay {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? preview.primary.opacity(0.78) : FormaTokens.Color.border.opacity(0.55),
                        lineWidth: isSelected ? 2 : 0.75
                    )
            }
            .shadow(
                color: isSelected ? preview.primary.opacity(0.28) : .clear,
                radius: isSelected ? 10 : 0,
                y: isSelected ? 3 : 0
            )
    }
}

// MARK: - Color dots

private struct ThemeColorTokenDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .overlay {
                Circle()
                    .stroke(FormaTokens.Color.border.opacity(0.45), lineWidth: 0.5)
            }
            .frame(width: 11, height: 11)
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
