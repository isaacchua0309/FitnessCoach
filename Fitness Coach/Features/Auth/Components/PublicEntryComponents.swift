//
//  PublicEntryComponents.swift
//  Fitness Coach
//
//  Forma — Shared UI for public entry screens (welcome, sign-in, no-profile).
//

import SwiftUI

// MARK: - Buttons

struct PublicEntryPrimaryButton: View {
    let title: String
    let palette: PublicWelcomeTheme.Palette
    let action: () -> Void
    var accessibilityHint: String?

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(palette.accentForeground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                .fill(palette.ctaBackground)
        }
        .accessibilityHint(accessibilityHint ?? "")
    }
}

struct PublicEntrySecondaryLink: View {
    let title: String
    let palette: PublicWelcomeTheme.Palette
    let action: () -> Void
    var font: Font = FormaTokens.Typography.sectionSubtitle.weight(.semibold)
    var accessibilityHint: String?

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(palette.accent)
        }
        .buttonStyle(.plain)
        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        .accessibilityHint(accessibilityHint ?? "")
    }
}

// MARK: - Brand marks

enum PublicEntryBrandMarkStyle {
    case welcomeHero
    case appIcon
    case planSearch
}

struct PublicEntryBrandMark: View {
    let style: PublicEntryBrandMarkStyle
    let palette: PublicWelcomeTheme.Palette

    @ScaledMetric(relativeTo: .largeTitle) private var heroMarkDiameter: CGFloat = 72
    @ScaledMetric(relativeTo: .largeTitle) private var markDiameter: CGFloat = 56

    var body: some View {
        switch style {
        case .welcomeHero:
            welcomeHeroMark
        case .appIcon:
            appIconMark(diameter: markDiameter, cornerRadius: markDiameter * 0.22)
        case .planSearch:
            planSearchMark
        }
    }

    private var welcomeHeroMark: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.accent.opacity(0.34),
                            palette.accent.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: heroMarkDiameter * 0.72
                    )
                )
                .frame(width: heroMarkDiameter * 1.28, height: heroMarkDiameter * 1.28)
                .blur(radius: 10)

            appIconMark(diameter: heroMarkDiameter, cornerRadius: heroMarkDiameter / 2)
        }
    }

    private func appIconMark(diameter: CGFloat, cornerRadius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(palette.accentSoft)
                .frame(width: diameter * 1.18, height: diameter * 1.18)

            Image("FormaAppIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: diameter, height: diameter)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: palette.accent.opacity(0.16), radius: 12, y: 4)
        }
    }

    private var planSearchMark: some View {
        ZStack {
            Circle()
                .fill(palette.accentSoft)
                .frame(width: markDiameter * 1.18, height: markDiameter * 1.18)

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: markDiameter * 0.38, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
    }
}

// MARK: - Benefit chips

struct PublicEntryBenefitChipRow: View {
    let benefits: [(icon: String, title: String)]
    let palette: PublicWelcomeTheme.Palette
    var accessibilityLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            ForEach(benefits, id: \.title) { benefit in
                PublicEntryBenefitChip(
                    icon: benefit.icon,
                    title: benefit.title,
                    palette: palette
                )
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                        .stroke(palette.surfaceBorder.opacity(0.55), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PublicEntryBenefitChip: View {
    let icon: String
    let title: String
    let palette: PublicWelcomeTheme.Palette

    var body: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(palette.chipIconBackground)
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.accent.opacity(0.92))
            }
            .accessibilityHidden(true)

            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

// MARK: - Loading & errors

struct PublicEntryLoadingView: View {
    let message: String
    let palette: PublicWelcomeTheme.Palette

    var body: some View {
        ZStack {
            PublicEntryScreenBackground(palette: palette)

            VStack(spacing: FormaTokens.Spacing.sm) {
                SwiftUI.ProgressView()
                    .controlSize(.large)
                    .tint(palette.accent)

                Text(message)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

struct PublicEntryFailureBanner: View {
    let title: String
    let message: String
    let palette: PublicWelcomeTheme.Palette

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Label {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityHidden(true)
            }

            Text(message)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(palette.warning)
        .padding(FormaTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(palette.warningSoft)
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                        .stroke(palette.warning.opacity(0.35), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PublicEntryErrorScreen: View {
    let title: String
    let bodyCopy: String
    let retryCTA: String
    let palette: PublicWelcomeTheme.Palette
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            PublicEntryScreenBackground(palette: palette)

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(palette.warning)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(bodyCopy)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)

                Spacer(minLength: 0)

                PublicEntryPrimaryButton(
                    title: retryCTA,
                    palette: palette,
                    action: onRetry
                )
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, FormaTokens.Spacing.lg)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Title block

struct PublicEntryTitleBlock: View {
    let title: String
    let subtitle: String
    var supportingCopy: String?
    let palette: PublicWelcomeTheme.Palette
    var titleLineLimit: Int = 2

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.84)
                .lineLimit(titleLineLimit)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.88)

            if let supportingCopy {
                Text(supportingCopy)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
