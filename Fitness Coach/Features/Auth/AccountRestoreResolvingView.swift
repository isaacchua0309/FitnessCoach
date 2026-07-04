//
//  AccountRestoreResolvingView.swift
//  Fitness Coach
//
//  Forma — Blocking restore loading surface during signed-in bootstrap.
//

import SwiftUI

struct AccountRestoreResolvingView: View {

    var body: some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: FormaTokens.Spacing.lg) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(OnboardingTheme.ctaBackground)
                    .accessibilityHidden(true)

                Text(FormaProductCopy.AccountRestore.restoringMessage)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                    .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
