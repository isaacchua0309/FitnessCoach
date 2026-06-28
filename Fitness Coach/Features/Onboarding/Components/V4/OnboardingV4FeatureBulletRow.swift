//
//  OnboardingV4FeatureBulletRow.swift
//  Fitness Coach
//
//  Forma — Icon + title + subtitle row for v4 marketing screens.
//

import SwiftUI

struct OnboardingV4FeatureBullet: Equatable, Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String

    init(id: String? = nil, icon: String, title: String, subtitle: String) {
        self.id = id ?? title
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
}

extension OnboardingV4FeatureBullet {

    static var introProofDefaults: [OnboardingV4FeatureBullet] {
        FormaProductCopy.Onboarding.V4.IntroProofFeatures.bullets.map { bullet in
            OnboardingV4FeatureBullet(
                icon: bullet.icon,
                title: bullet.title,
                subtitle: bullet.subtitle
            )
        }
    }

    static var almostThereDefaults: [OnboardingV4FeatureBullet] {
        FormaProductCopy.Onboarding.V4.AlmostThereFeatures.bullets.map { bullet in
            OnboardingV4FeatureBullet(
                icon: bullet.icon,
                title: bullet.title,
                subtitle: bullet.subtitle
            )
        }
    }
}

struct OnboardingV4FeatureBulletRow: View {
    let bullet: OnboardingV4FeatureBullet

    @ScaledMetric(relativeTo: .body) private var iconContainerSize: CGFloat = 30

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(FormaTokens.Color.accentMuted)
                    .frame(width: iconContainerSize, height: iconContainerSize)

                Image(systemName: bullet.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent.opacity(0.92))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(bullet.title)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(bullet.subtitle)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bullet.title). \(bullet.subtitle)")
    }
}

struct OnboardingV4FeatureBulletList: View {
    let bullets: [OnboardingV4FeatureBullet]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            ForEach(bullets) { bullet in
                OnboardingV4FeatureBulletRow(bullet: bullet)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                        .stroke(OnboardingTheme.border.opacity(0.55), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
    }
}
