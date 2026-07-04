//
//  AccountDeletionView.swift
//  Fitness Coach
//
//  Forma — Account deletion confirmation, progress, and recovery UI (Phase 6).
//

import SwiftUI

struct AccountDeletionView: View {

    @ObservedObject var viewModel: AccountDeletionViewModel
    let scope: AccountDeletionScope
    let onDismiss: () -> Void
    let onSuccess: () -> Void

    @FocusState private var isConfirmationFieldFocused: Bool

    private var presentation: AccountDeletionPresentation {
        AccountDeletionPresentationBuilder.build(scope: scope)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SettingsChromeAccessibility.detailSectionSpacing) {
                    consequenceSection

                    if viewModel.showsProgress {
                        progressSection
                    } else if viewModel.terminalSummary != nil, !(viewModel.terminalSummary?.isSuccessful ?? false) {
                        errorSection
                    } else if case .confirming = viewModel.phase {
                        confirmationSection
                    }
                }
                .formaSettingsDetailContent()
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.top, SettingsChromeAccessibility.detailPageTopPadding)
                .padding(.bottom, SettingsChromeAccessibility.detailPageBottomPadding)
            }
            .formaScreenBackground()
            .navigationTitle(presentation.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(presentation.cancelTitle) {
                        viewModel.cancelFlow()
                        onDismiss()
                    }
                    .accessibilityHint(presentation.cancelAccessibilityHint)
                    .disabled(viewModel.isPerformingDeletion && viewModel.progressStatus == .completed)
                }
            }
            .onAppear {
                if case .confirming = viewModel.phase {
                    isConfirmationFieldFocused = true
                }
            }
            .onChange(of: viewModel.terminalSummary?.isSuccessful) { _, isSuccessful in
                guard isSuccessful == true else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(750))
                    onSuccess()
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isPerformingDeletion)
    }

    // MARK: - Consequences

    private var consequenceSection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Label {
                Text(scope == .fullAccount
                    ? "Permanent account deletion"
                    : "Local device data deletion")
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.destructive)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(FormaTokens.Color.destructive)
            }
            .accessibilityAddTraits(.isHeader)

            FormaPlanCard(compact: true) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    ForEach(Array(presentation.consequenceBullets.enumerated()), id: \.offset) { _, bullet in
                        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                            Text("•")
                                .font(FormaTokens.Typography.body)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                                .accessibilityHidden(true)

                            Text(bullet)
                                .font(FormaTokens.Typography.body)
                                .foregroundStyle(FormaTokens.Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(bullet)
                    }
                }
            }
        }
    }

    // MARK: - Confirmation

    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            if AccountDeletionPolicy.requiresTypedConfirmation {
                typedConfirmationField
            }

            destructiveActionButton(
                title: presentation.confirmActionTitle,
                isEnabled: viewModel.canConfirmDeletion,
                accessibilityLabel: presentation.confirmActionAccessibilityLabel,
                accessibilityHint: presentation.confirmActionAccessibilityHint
            ) {
                viewModel.confirmDeletion()
            }
        }
    }

    private var typedConfirmationField: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(presentation.typedConfirmationPrompt)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                presentation.typedConfirmationPlaceholder,
                text: $viewModel.confirmationText
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .font(FormaTokens.Typography.body.monospaced())
            .padding(FormaTokens.Spacing.sm)
            .background(FormaTokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                    .stroke(FormaTokens.Color.border, lineWidth: 1)
            )
            .focused($isConfirmationFieldFocused)
            .accessibilityLabel(presentation.typedConfirmationPrompt)
            .accessibilityHint(presentation.typedConfirmationAccessibilityHint)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            if let status = viewModel.progressStatus {
                let label = AccountDeletionStatusFormatting.progressLabel(for: status)
                if !label.isEmpty {
                    HStack(spacing: FormaTokens.Spacing.sm) {
                        if status != .completed {
                            ProgressView()
                                .tint(FormaTokens.Color.accent)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(FormaTokens.Color.success)
                                .accessibilityHidden(true)
                        }

                        Text(label)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        status == .completed
                            ? label
                            : "\(FormaProductCopy.Settings.PrivacyData.deletionProgressAccessibilityLabel). \(label)"
                    )
                    .accessibilityAddTraits(status == .completed ? [] : .updatesFrequently)
                }
            }

            if viewModel.isPerformingDeletion,
               viewModel.progressStatus != .completed {
                secondaryActionButton(title: presentation.cancelTitle) {
                    viewModel.cancelFlow()
                    onDismiss()
                }
                .accessibilityHint(presentation.cancelAccessibilityHint)
            }
        }
    }

    // MARK: - Error / recovery

    @ViewBuilder
    private var errorSection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            if let message = viewModel.safeErrorMessage {
                Text(message)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.requiresReauthentication {
                primaryActionButton(
                    title: presentation.reauthenticateTitle,
                    accessibilityHint: presentation.reauthenticateAccessibilityHint
                ) {
                    viewModel.retryDeletion()
                }
            } else if viewModel.allowsRetry {
                primaryActionButton(title: presentation.retryTitle) {
                    viewModel.retryDeletion()
                }
            }

            secondaryActionButton(title: presentation.closeTitle) {
                viewModel.reset()
                onDismiss()
            }
        }
    }

    // MARK: - Buttons

    private func destructiveActionButton(
        title: String,
        isEnabled: Bool,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(
                    isEnabled
                        ? Color.white
                        : Color.white.opacity(0.7)
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: SettingsChromeAccessibility.minimumActionButtonHeight)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                .fill(
                    isEnabled
                        ? FormaTokens.Color.destructive
                        : FormaTokens.Color.destructive.opacity(0.45)
                )
        )
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    private func primaryActionButton(
        title: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.accent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: SettingsChromeAccessibility.minimumActionButtonHeight)
        }
        .buttonStyle(.plain)
        .background(actionButtonChrome)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(accessibilityHint ?? "")
    }

    private func secondaryActionButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(FormaTokens.Typography.body.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: SettingsChromeAccessibility.minimumActionButtonHeight)
        }
        .buttonStyle(.plain)
        .background(actionButtonChrome)
        .accessibilityAddTraits(.isButton)
    }

    private var actionButtonChrome: some View {
        RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
            .fill(FormaTokens.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                    .stroke(FormaTokens.Color.border, lineWidth: 1)
            )
    }
}

#if DEBUG
#Preview("Delete Account") {
    AccountDeletionView(
        viewModel: {
            let model = AccountDeletionViewModel()
            model.beginConfirmation(scope: .fullAccount)
            return model
        }(),
        scope: .fullAccount,
        onDismiss: {},
        onSuccess: {}
    )
    .formaThemePreview()
}

#Preview("Delete Local Data") {
    AccountDeletionView(
        viewModel: {
            let model = AccountDeletionViewModel()
            model.beginConfirmation(scope: .localDeviceOnly)
            return model
        }(),
        scope: .localDeviceOnly,
        onDismiss: {},
        onSuccess: {}
    )
    .formaThemePreview()
}
#endif
