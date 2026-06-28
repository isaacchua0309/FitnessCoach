//
//  ExistingUserProfileLookupFailedView.swift
//  Fitness Coach
//
//  Forma — Retry UI when profile lookup fails during returning-member sign-in.
//

import SwiftUI

struct ExistingUserProfileLookupFailedView: View {

    let onRetry: () -> Void

    private let copy = FormaProductCopy.PublicEntry.ExistingUserSignIn.ProfileLookupFailed.self

    @Environment(\.colorScheme) private var colorScheme

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            PublicEntryScreenBackground(palette: palette)

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .accessibilityHidden(true)

                    Text(copy.title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(copy.body)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)

                Spacer(minLength: 0)

                Button(action: onRetry) {
                    Text(copy.retryCTA)
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(palette.accentForeground)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                }
                .buttonStyle(.plain)
                .background {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                        .fill(palette.accent)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, FormaTokens.Spacing.lg)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ExistingUserProfileLookupFailedView(onRetry: {})
}
