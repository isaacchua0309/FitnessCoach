//
//  OnboardingPageShell.swift
//  Fitness Coach
//
//  Forma — Reusable page shell for onboarding screens.
//

import SwiftUI

struct OnboardingPageShell<Content: View>: View {
    var currentStep: OnboardingStep?
    var title: String?
    var subtitle: String?
    var helperText: String?
    var showsProgressHeader: Bool = true
    var usesScrollView: Bool = true

    var showsBackButton: Bool = true
    var primaryTitle: String = FormaProductCopy.Common.continueAction
    var isPrimaryEnabled: Bool = true
    var isPrimaryLoading: Bool = false
    var onBack: (() -> Void)?
    let onPrimary: () -> Void

    @ViewBuilder var content: () -> Content

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 48

    private var resolvedTitle: String {
        title ?? currentStep?.title ?? ""
    }

    private var resolvedSubtitle: String? {
        if let subtitle { return subtitle }
        return currentStep?.subtitle
    }

    private var resolvedButtonHeight: CGFloat {
        max(buttonHeight, FormaTokens.Layout.minTouchTarget)
    }

    var body: some View {
        VStack(spacing: 0) {
            scrollableBody
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OnboardingTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var scrollableBody: some View {
        if usesScrollView {
            ScrollView {
                bodyStack
            }
            .scrollIndicators(.hidden)
        } else {
            bodyStack
        }
    }

    private var bodyStack: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if showsProgressHeader, let currentStep {
                OnboardingStageProgressHeader(currentStep: currentStep)
                    .padding(.top, OnboardingLayout.progressHeaderTop)
            } else {
                headerBlock
                    .padding(.top, OnboardingLayout.progressHeaderTop)
            }

            content()
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.bottom, OnboardingLayout.scrollBottomPadding)
        .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var headerBlock: some View {
        if !resolvedTitle.isEmpty || resolvedSubtitle != nil || helperText != nil {
            VStack(alignment: .leading, spacing: OnboardingLayout.progressTitleSpacing) {
                if !resolvedTitle.isEmpty {
                    Text(resolvedTitle)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }

                if let resolvedSubtitle {
                    Text(resolvedSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let helperText {
                    Text(helperText)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(OnboardingTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(
                            "\(FormaProductCopy.Onboarding.Flow.Components.helperAccessibilityPrefix). \(helperText)"
                        )
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var footer: some View {
        VStack(spacing: OnboardingLayout.footerInnerSpacing) {
            HStack(spacing: FormaTokens.Spacing.sm) {
                if showsBackButton, let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: resolvedButtonHeight, height: resolvedButtonHeight)
                            .background(footerSecondaryBackground)
                            .clipShape(
                                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPrimaryLoading)
                    .accessibilityLabel(FormaProductCopy.Common.back)
                }

                OnboardingPrimaryCTA(
                    title: primaryTitle,
                    isEnabled: isPrimaryEnabled,
                    isLoading: isPrimaryLoading,
                    action: onPrimary
                )
            }
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.footerVerticalPadding)
        .padding(.bottom, OnboardingLayout.footerVerticalPadding)
        .background {
            Rectangle()
                .fill(OnboardingTheme.cardElevated)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var footerSecondaryBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
            .fill(OnboardingTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                    .stroke(OnboardingTheme.border, lineWidth: 1)
            )
    }
}
