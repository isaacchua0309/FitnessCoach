//
//  OnboardingCompactFooter.swift
//  Fitness Coach
//
//  Forma — Compact sticky Back / Continue footer for tap-first onboarding.
//

import SwiftUI

struct OnboardingCompactFooter: View {
    var showsBack: Bool = true
    let continueTitle: String
    let canContinue: Bool
    var isLoading: Bool = false
    var showsRequiredHint: Bool = false
    let onBack: () -> Void
    let onContinue: () -> Void

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 48

    private var resolvedButtonHeight: CGFloat {
        max(buttonHeight, FormaTokens.Layout.minTouchTarget)
    }

    var body: some View {
        VStack(spacing: OnboardingLayout.footerInnerSpacing) {
            HStack(spacing: FormaTokens.Spacing.sm) {
                if showsBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: resolvedButtonHeight, height: resolvedButtonHeight)
                            .background(footerSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .accessibilityLabel(FormaProductCopy.Common.back)
                }

                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        if isLoading {
                            SwiftUI.ProgressView()
                                .tint(.white)
                        }
                        Text(continueTitle)
                            .font(FormaTokens.Typography.body.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(canContinue && !isLoading ? FormaTokens.Color.textPrimary : OnboardingTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: resolvedButtonHeight)
                    .background(primaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLoading || !canContinue)
                .accessibilityLabel(continueTitle)
                .accessibilityHint(canContinue ? "" : FormaProductCopy.Common.completeRequiredFields)
            }

            if showsRequiredHint, !canContinue, !isLoading {
                Text(FormaProductCopy.Common.completeRequiredFields)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(FormaProductCopy.Common.completeRequiredFields)
            }
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.compactFooterTopPadding)
        .padding(.bottom, OnboardingLayout.compactFooterBottomPadding)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var primaryBackground: some View {
        Group {
            if canContinue && !isLoading {
                OnboardingTheme.accent
            } else {
                FormaTokens.Color.surfaceElevated
            }
        }
    }

    private var footerSecondaryBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
            .fill(FormaTokens.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                    .stroke(OnboardingTheme.border, lineWidth: 1)
            )
    }
}

#Preview("Enabled") {
    VStack {
        Spacer()
        OnboardingCompactFooter(
            continueTitle: FormaProductCopy.Common.continueAction,
            canContinue: true,
            onBack: {},
            onContinue: {}
        )
    }
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    VStack {
        Spacer()
        OnboardingCompactFooter(
            continueTitle: FormaProductCopy.Common.continueAction,
            canContinue: false,
            showsRequiredHint: true,
            onBack: {},
            onContinue: {}
        )
    }
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Loading") {
    VStack {
        Spacer()
        OnboardingCompactFooter(
            showsBack: false,
            continueTitle: "Build my plan",
            canContinue: true,
            isLoading: true,
            onBack: {},
            onContinue: {}
        )
    }
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    VStack {
        Spacer()
        OnboardingCompactFooter(
            continueTitle: FormaProductCopy.Common.continueAction,
            canContinue: true,
            onBack: {},
            onContinue: {}
        )
    }
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
