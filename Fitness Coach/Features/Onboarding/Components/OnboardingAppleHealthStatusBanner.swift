//
//  OnboardingAppleHealthStatusBanner.swift
//  Fitness Coach
//
//  Forma — Inline status banner for Apple Health onboarding states.
//

import SwiftUI

struct OnboardingAppleHealthStatusBanner: View {
    enum Style: Equatable {
        case neutral
        case success
        case warning
    }

    let message: String
    var style: Style = .neutral

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            Text(message)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private var iconName: String {
        switch style {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .neutral:
            return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch style {
        case .success:
            return OnboardingTheme.accent
        case .warning:
            return OnboardingTheme.warning
        case .neutral:
            return OnboardingTheme.secondaryText
        }
    }

    private var textColor: Color {
        switch style {
        case .success:
            return OnboardingTheme.primaryText
        case .warning, .neutral:
            return OnboardingTheme.secondaryText
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .success:
            return OnboardingTheme.accentMuted
        case .warning:
            return OnboardingTheme.surfaceSubtle
        case .neutral:
            return OnboardingTheme.surfaceSubtle
        }
    }

    private var borderColor: Color {
        switch style {
        case .success:
            return OnboardingTheme.accent.opacity(0.22)
        case .warning, .neutral:
            return OnboardingTheme.border.opacity(0.45)
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        OnboardingAppleHealthStatusBanner(
            message: FormaProductCopy.Onboarding.Flow.AppleHealth.connectedMessage,
            style: .success
        )
        OnboardingAppleHealthStatusBanner(
            message: FormaProductCopy.Onboarding.Flow.AppleHealth.deniedMessage,
            style: .warning
        )
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
