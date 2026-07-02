//
//  ThemeSettingsLivePreview.swift
//  Fitness Coach
//
//  Forma — Compact live preview of themed UI accents in Theme settings.
//

import SwiftUI

/// Non-interactive sample of production-themed controls. Reads active `FormaTokens` only.
struct ThemeSettingsLivePreview: View {
    private let sampleProgress = 0.68
    private let ringSize: CGFloat = 46
    private let ringLineWidth: CGFloat = 4

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                primaryButtonSample
                Spacer(minLength: 0)
                tabSelectionSample
            }

            HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                progressSample
                Spacer(minLength: 0)
                coachLogPillSample
            }
        }
        .padding(FormaTokens.Spacing.sm)
        .background(previewChrome)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(FormaProductCopy.Settings.Theme.livePreviewAccessibilityLabel)
    }

    // MARK: - Samples

    private var primaryButtonSample: some View {
        Text(FormaProductCopy.Settings.Theme.livePreviewPrimaryButton)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.ctaText)
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .background(FormaTokens.Color.ctaBackground, in: RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
            .accessibilityHidden(true)
    }

    private var progressSample: some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(FormaTokens.Color.progressTrack, lineWidth: ringLineWidth)

                Circle()
                    .trim(from: 0, to: sampleProgress)
                    .stroke(
                        FormaTokens.Color.progress,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(FormaProductCopy.Settings.Theme.livePreviewProgressValue)
                    .font(FormaTokens.Typography.caption2.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .monospacedDigit()
            }
            .frame(width: ringSize, height: ringSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(FormaProductCopy.Settings.Theme.livePreviewProgressLabel)
                    .font(FormaTokens.Typography.caption2.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .lineLimit(1)

                TodayMetricProgressBar(progress: sampleProgress, subdued: false)
                    .frame(width: 72)
            }
        }
        .accessibilityHidden(true)
    }

    private var tabSelectionSample: some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            tabIcon(systemName: "house.fill", isSelected: true)
            tabIcon(systemName: "bubble.left.and.bubble.right", isSelected: false)
            tabIcon(systemName: "chart.line.uptrend.xyaxis", isSelected: false)
        }
        .accessibilityHidden(true)
    }

    private func tabIcon(systemName: String, isSelected: Bool) -> some View {
        Image(systemName: systemName)
            .font(.caption.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? FormaTokens.Theme.primary : FormaTokens.Color.textTertiary)
            .frame(width: 28, height: 28)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(FormaTokens.Theme.softBackground)
                }
            }
    }

    private var coachLogPillSample: some View {
        Label {
            Text(FormaProductCopy.Settings.Theme.livePreviewLogPill)
                .font(FormaTokens.Typography.caption.weight(.semibold))
        } icon: {
            Image(systemName: "fork.knife")
                .font(.caption.weight(.semibold))
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .background(FormaTokens.Color.surfaceSubtle, in: Capsule())
        .overlay {
            Capsule()
                .stroke(FormaTokens.Theme.primary.opacity(0.42), lineWidth: 0.75)
        }
        .foregroundStyle(FormaTokens.Theme.primary)
        .accessibilityHidden(true)
    }

    private var previewChrome: some View {
        RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
            .fill(FormaTokens.Color.surfaceSubtle)
            .overlay {
                RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                    .stroke(FormaTokens.Color.border.opacity(0.55), lineWidth: 0.75)
            }
    }
}

#if DEBUG
#Preview("Ocean Blue") {
    ThemeSettingsLivePreview()
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(palette: .oceanBlue)
}

#Preview("Sunset Orange Dark") {
    ThemeSettingsLivePreview()
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: .dark, palette: .sunsetOrange)
}
#endif
