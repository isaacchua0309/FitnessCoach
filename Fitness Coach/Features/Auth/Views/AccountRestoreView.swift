//
//  AccountRestoreView.swift
//  Fitness Coach
//
//  Forma — Blocking restore UI during signed-in bootstrap (Phase 4).
//

import SwiftUI

struct AccountRestoreView: View {

    @ObservedObject var viewModel: AccountRestoreViewModel

    @Environment(\.formaResolvedTheme) private var resolvedTheme

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    var body: some View {
        ZStack {
            PublicEntryScreenBackground(palette: palette)

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                content
                    .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                    .frame(maxWidth: FormaTokens.Layout.maxContentWidth)

                Spacer(minLength: 0)

                if viewModel.phase.showsPrimaryAction {
                    actions
                        .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                        .padding(.bottom, FormaTokens.Spacing.lg)
                        .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .failed:
            terminalContent(
                icon: "exclamationmark.triangle",
                iconColor: palette.warning
            )
        case .partialContinue, .offlineContinue:
            terminalContent(
                icon: "icloud.and.arrow.down",
                iconColor: palette.accent
            )
        case .completed:
            terminalContent(
                icon: "checkmark.circle",
                iconColor: palette.accent,
                showsSpinner: false
            )
        case .checkingAccount, .restoringProfile, .restoringRecentLogs,
             .restoringWeightHistory, .preparingDashboard:
            progressContent
        }
    }

    private var progressContent: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            SwiftUI.ProgressView()
                .controlSize(.large)
                .tint(palette.accent)
                .accessibilityHidden(true)

            Text(viewModel.progressMessage)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)

            #if DEBUG
            if let debugDetail = viewModel.debugDetail {
                Text(debugDetail)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(palette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            #endif
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.progressMessage)
    }

    private func terminalContent(
        icon: String,
        iconColor: Color,
        showsSpinner: Bool = false
    ) -> some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            if showsSpinner {
                SwiftUI.ProgressView()
                    .controlSize(.large)
                    .tint(palette.accent)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
            }

            if let title = viewModel.title {
                Text(title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }

            Text(viewModel.progressMessage)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            #if DEBUG
            if let debugDetail = viewModel.debugDetail {
                Text(debugDetail)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(palette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            #endif
        }
    }

    private var actions: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            PublicEntryPrimaryButton(
                title: viewModel.primaryActionTitle,
                palette: palette,
                action: primaryAction
            )
            .disabled(viewModel.isRetrying)

            if viewModel.phase.showsSignOutAction {
                PublicEntrySecondaryLink(
                    title: FormaProductCopy.AccountRestore.Failed.signOutCTA,
                    palette: palette,
                    action: viewModel.signOut
                )
            }
        }
    }

    private func primaryAction() {
        switch viewModel.phase {
        case .failed:
            viewModel.retry()
        case .partialContinue, .offlineContinue:
            viewModel.continueToApp()
        case .checkingAccount, .restoringProfile, .restoringRecentLogs,
             .restoringWeightHistory, .preparingDashboard, .completed:
            break
        }
    }
}
