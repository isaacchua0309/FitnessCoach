//
//  AccountRestorePendingStateView.swift
//  Fitness Coach
//
//  Forma — Restore-pending placeholder for main tabs (Phase 4).
//

import SwiftUI

struct AccountRestorePendingStateView: View {

    let title: String
    let message: String

    @Environment(\.formaResolvedTheme) private var resolvedTheme

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    init(
        title: String = FormaProductCopy.AccountRestore.Pending.title,
        message: String
    ) {
        self.title = title
        self.message = message
    }

    var body: some View {
        ZStack {
            PublicEntryScreenBackground(palette: palette)

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.md) {
                    SwiftUI.ProgressView()
                        .controlSize(.large)
                        .tint(palette.accent)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(message)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}
