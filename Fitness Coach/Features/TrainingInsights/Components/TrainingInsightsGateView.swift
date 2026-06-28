//
//  TrainingInsightsGateView.swift
//  Fitness Coach
//
//  Forma — Training Insights when Apple Health is not connected.
//

import SwiftUI

struct TrainingInsightsGateView: View {

    let state: TrainingIntegrationState
    let onPrimaryAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrainingLayout.sectionSpacing) {
                header
                messageCard
                if showsBenefits {
                    benefitsCard
                }
                if let buttonTitle = TrainingIntegrationCopy.connectButtonTitle(for: state) {
                    primaryButton(title: buttonTitle)
                }
                if showsSecondaryNote {
                    secondaryNote
                }
            }
            .padding(.horizontal, TrainingLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.lg)
            .padding(.bottom, FormaTokens.Spacing.xl)
        }
        .fitPilotScrollBottomInset()
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            iconOrb

            Text(TrainingIntegrationCopy.gateTitle(for: state))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if case .failed(let message) = state {
                Text(TrainingIntegrationCopy.failedMessage(message))
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var iconOrb: some View {
        ZStack {
            Circle()
                .fill(FormaTokens.Color.accentMuted)
                .frame(width: FormaTokens.Radius.iconOrb, height: FormaTokens.Radius.iconOrb)

            if state.isRequestingPermission {
                SwiftUI.ProgressView()
                    .tint(FormaTokens.Color.accent)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FormaTokens.Color.accent)
            }
        }
        .accessibilityHidden(true)
    }

    private var messageCard: some View {
        FitPilotPlanCard {
            Text(TrainingIntegrationCopy.gateMessage(for: state))
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textLegal)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefitsCard: some View {
        FitPilotPlanCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                ForEach(TrainingIntegrationCopy.lockedBenefits, id: \.self) { benefit in
                    benefitRow(benefit)
                }
            }
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.accent.opacity(0.85))
                .padding(.top, 1)

            Text(text)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .center)
    }

    private func primaryButton(title: String) -> some View {
        Button(action: onPrimaryAction) {
            Text(title)
                .font(FormaTokens.Typography.bodyMedium)
                .frame(maxWidth: .infinity)
                .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(FormaTokens.Color.ctaBackground)
        .disabled(state.isRequestingPermission)
    }

    private var secondaryNote: some View {
        Text(TrainingIntegrationCopy.lockedSecondaryNote)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FormaTokens.Spacing.xs)
    }

    // MARK: - Helpers

    private var showsBenefits: Bool {
        switch state {
        case .notConnected, .failed:
            return true
        case .unavailable, .denied, .requestingPermission, .connected:
            return false
        }
    }

    private var showsSecondaryNote: Bool {
        switch state {
        case .notConnected, .failed:
            return true
        case .unavailable, .denied, .requestingPermission, .connected:
            return false
        }
    }

    private var iconName: String {
        switch state {
        case .unavailable:
            return "heart.slash"
        case .denied:
            return "lock.fill"
        default:
            return "heart.fill"
        }
    }
}

#Preview("Not connected") {
    TrainingInsightsGateView(state: .notConnected, onPrimaryAction: {})
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Denied") {
    TrainingInsightsGateView(state: .denied, onPrimaryAction: {})
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Unavailable") {
    TrainingInsightsGateView(state: .unavailable, onPrimaryAction: {})
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
