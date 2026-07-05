//
//  FormaInlineEmptyState.swift
//  Fitness Coach
//
//  Forma — Compact title / body / optional CTA for in-card empty states.
//

import SwiftUI

struct FormaInlineEmptyState: View {
    var title: String?
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var actionAccessibilityHint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            if let title {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(message)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(title == nil ? FormaTokens.Color.textPrimary : FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                FormaQuickActionChip(
                    title: actionTitle,
                    action: action,
                    accessibilityHint: actionAccessibilityHint
                )
                .padding(.top, title == nil ? 0 : FormaTokens.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Quick action chip

enum FormaQuickActionChipStyle {
    case secondary
    case primary
}

struct FormaQuickActionChip: View {
    let title: String
    let action: () -> Void
    var style: FormaQuickActionChipStyle = .secondary
    var accessibilityHint: String?

    @Environment(\.themePalette) private var palette

    var body: some View {
        Group {
            switch style {
            case .secondary:
                Button(title, action: action)
                    .buttonStyle(FormaThemedChipButtonStyle())
            case .primary:
                Button(title, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(palette.primaryButtonBackground)
            }
        }
        .font(FormaTokens.Typography.caption.weight(.semibold))
        .accessibilityHint(accessibilityHint ?? "")
        .formaThemeReactive()
    }
}

private struct FormaThemedChipButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.themePalette) private var palette
    @Environment(\.formaColors) private var colors

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .foregroundStyle(foreground(isPressed: configuration.isPressed))
            .background(background(isPressed: configuration.isPressed), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 0.5)
            }
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func foreground(isPressed: Bool) -> Color {
        guard isEnabled else { return colors.textTertiary }
        return isPressed
            ? palette.primary.opacity(0.85)
            : palette.primary
    }

    private func background(isPressed: Bool) -> Color {
        guard isEnabled else { return colors.surfaceSubtle }
        return isPressed
            ? palette.softBackground.opacity(0.9)
            : palette.softBackground
    }

    private var borderColor: Color {
        isEnabled
            ? palette.borderTint.opacity(0.35)
            : colors.border.opacity(0.45)
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard isEnabled, !reduceMotion else { return 1 }
        return isPressed ? 0.96 : 1
    }
}
