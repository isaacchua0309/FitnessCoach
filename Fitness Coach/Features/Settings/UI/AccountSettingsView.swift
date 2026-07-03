//
//  AccountSettingsView.swift
//  Fitness Coach
//
//  Forma — Consumer account screen (Settings → Account).
//

import SwiftUI

struct AccountSettingsView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.performAppSignOut) private var performAppSignOut
    @Environment(\.settingsAnalyticsCoordinator) private var analyticsCoordinator
    @State private var showsLogoutConfirmation = false

    @ScaledMetric(relativeTo: .title2) private var avatarDiameter: CGFloat = 56

    private var presentation: AccountSettingsPresentation {
        AccountSettingsPresentationBuilder.build(
            input: AccountSettingsPresentationInput(
                authState: authManager.authState,
                displayName: authManager.accountDisplayName,
                email: authManager.accountEmail,
                signInProvider: authManager.accountSignInProvider
            )
        )
    }

    var body: some View {
        formaSettingsDetailScreen {
            VStack(alignment: .leading, spacing: SettingsChromeAccessibility.detailSectionSpacing) {
                profileHeader
                accountDetailsCard
                logoutSection
            }
        }
        .navigationTitle("Account")
        .confirmationDialog(
            presentation.logoutConfirmationTitle,
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button(FormaProductCopy.Account.logoutConfirmActionTitle, role: .destructive) {
                analyticsCoordinator.logLogoutConfirmed()
                AccountSettingsLogoutHandler.perform(
                    performAppSignOut: performAppSignOut,
                    authManagerSignOut: authManager.signOut
                )
            }
            Button(FormaProductCopy.Account.logoutCancelActionTitle, role: .cancel) {}
        } message: {
            Text(presentation.logoutConfirmationMessage)
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            avatarView

            VStack(spacing: FormaTokens.Spacing.xs) {
                if let displayName = presentation.header.displayName {
                    Text(displayName)
                        .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                } else if let email = presentation.header.email {
                    emailText(email, style: .primary)
                }

                if let email = presentation.header.email, presentation.header.displayName != nil {
                    emailText(email, style: .secondary)
                }
            }

            if presentation.showsProviderBadge {
                providerBadge
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func emailText(_ email: String, style: EmailTextStyle) -> some View {
        Text(email)
            .font(style == .primary
                ? FormaTokens.Typography.sectionTitle.weight(.semibold)
                : FormaTokens.Typography.sectionSubtitle)
            .foregroundStyle(
                style == .primary
                    ? FormaTokens.Color.textPrimary
                    : FormaTokens.Color.textSecondary
            )
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .accessibilityLabel("Email, \(email)")
    }

    private enum EmailTextStyle {
        case primary
        case secondary
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            FormaTokens.Color.accent.opacity(0.5),
                            FormaTokens.Color.accent.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: avatarDiameter + 6, height: avatarDiameter + 6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            FormaTokens.Color.accent.opacity(0.18),
                            FormaTokens.Color.surfaceElevated
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: avatarDiameter * 0.55
                    )
                )
                .frame(width: avatarDiameter, height: avatarDiameter)
                .overlay {
                    Circle()
                        .stroke(FormaTokens.Color.border, lineWidth: 0.5)
                }

            if presentation.header.showsProgress {
                SwiftUI.ProgressView()
                    .tint(FormaTokens.Color.textPrimary)
            } else {
                Text(presentation.header.initials)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.accent)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
        }
        .accessibilityLabel(presentation.header.avatarAccessibilityLabel)
    }

    private var providerBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(FormaTokens.Typography.caption)
            Text(presentation.header.providerBadge)
                .font(FormaTokens.Typography.caption.weight(.medium))
        }
        .foregroundStyle(FormaTokens.Color.textSecondary)
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(FormaTokens.Color.surface)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(FormaTokens.Color.border, lineWidth: 1)
                }
        )
        .padding(.top, 2)
        .accessibilityLabel(presentation.header.providerBadge)
    }

    // MARK: - Details card

    private var accountDetailsCard: some View {
        FormaPlanCard(compact: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(presentation.detailRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        accountRowDivider
                    }
                    AccountInfoRow(
                        label: row.label,
                        value: row.value,
                        allowsTextSelection: row.allowsTextSelection,
                        usesMultilineValue: row.allowsTextSelection
                    )
                }
            }
        }
    }

    private var accountRowDivider: some View {
        Divider()
            .overlay(FormaTokens.Color.border)
            .padding(.vertical, FormaTokens.Spacing.xs)
    }

    // MARK: - Logout

    private var logoutSection: some View {
        Button {
            analyticsCoordinator.logLogoutTapped()
            showsLogoutConfirmation = true
        } label: {
            Text(FormaProductCopy.Account.logoutButtonTitle)
                .font(FormaTokens.Typography.body.weight(.medium))
                .foregroundStyle(logoutTitleColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: SettingsChromeAccessibility.minimumActionButtonHeight)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                .fill(FormaTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                        .stroke(FormaTokens.Color.border, lineWidth: 1)
                )
        )
        .disabled(!presentation.canLogOut)
        .accessibilityLabel(FormaProductCopy.Account.logoutButtonTitle)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(presentation.logoutButtonAccessibilityHint)
    }

    private var logoutTitleColor: Color {
        presentation.canLogOut
            ? FormaTokens.Color.destructive
            : FormaTokens.Color.destructive.opacity(0.45)
    }
}

// MARK: - Account row

private struct AccountInfoRow: View {
    let label: String
    let value: String
    var allowsTextSelection: Bool = false
    var usesMultilineValue: Bool = false

    var body: some View {
        Group {
            if usesMultilineValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                    valueText
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
                    Text(label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .frame(
                            width: SettingsChromeAccessibility.detailLabelColumnWidth,
                            alignment: .leading
                        )

                    valueText
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FormaTokens.Spacing.xs)
    }

    @ViewBuilder
    private var valueText: some View {
        let text = Text(value)
            .font(FormaTokens.Typography.sectionSubtitle)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)

        if allowsTextSelection {
            text.textSelection(.enabled)
        } else {
            text
        }
    }
}

// MARK: - Previews

#Preview("Signed in") {
    NavigationStack {
        AccountSettingsView()
    }
    .environmentObject(AuthManager())
}
