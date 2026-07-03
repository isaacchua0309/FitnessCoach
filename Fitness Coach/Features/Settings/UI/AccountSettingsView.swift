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
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                profileHeader
                accountDetailsCard
                logoutSection
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, FormaTokens.Spacing.sm)
        }
        .formaScreenBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
        .confirmationDialog(
            presentation.logoutConfirmationTitle,
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button(FormaProductCopy.Account.logoutConfirmActionTitle, role: .destructive) {
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
                    Text(email)
                        .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .textSelection(.enabled)
                }

                if let email = presentation.header.email, presentation.header.displayName != nil {
                    Text(email)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .textSelection(.enabled)
                }
            }

            if presentation.showsProviderBadge {
                providerBadge
            }
        }
        .frame(maxWidth: .infinity)
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
        FormaPlanCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(presentation.detailRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        accountRowDivider
                    }
                    AccountInfoRow(
                        label: row.label,
                        value: row.value,
                        allowsTextSelection: row.allowsTextSelection
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
            showsLogoutConfirmation = true
        } label: {
            Text(FormaProductCopy.Account.logoutButtonTitle)
                .font(FormaTokens.Typography.body.weight(.medium))
                .foregroundStyle(FormaTokens.Color.destructive.opacity(presentation.canLogOut ? 0.95 : 0.5))
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
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
}

// MARK: - Account row

private struct AccountInfoRow: View {
    let label: String
    let value: String
    var allowsTextSelection: Bool = false

    private let labelColumnWidth: CGFloat = 76

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(width: labelColumnWidth, alignment: .leading)

            valueText
                .frame(maxWidth: .infinity, alignment: .leading)
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
