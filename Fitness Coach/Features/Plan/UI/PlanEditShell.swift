//
//  PlanEditShell.swift
//  Fitness Coach
//
//  Forma — Reusable chrome for the Edit / Adjust Plan wizard.
//

import SwiftUI

// MARK: - Shell

struct PlanEditShell<Content: View>: View {
    let title: String
    let stepCount: Int
    let currentStepIndex: Int
    let heroState: PlanEditHeroState
    let confirmationTitle: String
    var showsConfirmation: Bool
    let isConfirmationEnabled: Bool
    let isConfirmationLoading: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @ViewBuilder var content: () -> Content

    private enum Layout {
        static let progressHeight: CGFloat = 3
        static let progressSpacing: CGFloat = 6
        static let sectionSpacing: CGFloat = FormaTokens.Spacing.sm
        static let bottomInset: CGFloat = FormaTokens.Spacing.md
    }

    var body: some View {
        VStack(spacing: 0) {
            PlanEditProgressIndicator(
                stepCount: stepCount,
                currentStepIndex: currentStepIndex
            )
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.xs)
            .padding(.bottom, Layout.sectionSpacing)

            PlanEditHeroCard(state: heroState)
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, Layout.sectionSpacing)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(FormaPlanTokens.Color.planBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(FormaPlanTokens.Color.planAccent)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(FormaProductCopy.PlanEditCommon.cancel, action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                if showsConfirmation {
                    Button(action: onConfirm) {
                        Group {
                            if isConfirmationLoading {
                                SwiftUI.ProgressView()
                                    .tint(FormaPlanTokens.Color.planAccent)
                            } else {
                                Text(confirmationTitle)
                            }
                        }
                    }
                    .foregroundStyle(confirmActionColor)
                    .disabled(!isConfirmationEnabled || isConfirmationLoading)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: Layout.bottomInset)
        }
    }

    private var confirmActionColor: Color {
        isConfirmationEnabled && !isConfirmationLoading
            ? FormaPlanTokens.Color.planAccent
            : FormaPlanTokens.Color.planDisabledAction
    }
}

// MARK: - Progress

struct PlanEditProgressIndicator: View {
    let stepCount: Int
    let currentStepIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(stepCount, 1), id: \.self) { index in
                Capsule()
                    .fill(
                        index <= currentStepIndex
                            ? FormaPlanTokens.Color.planProgressFill
                            : FormaPlanTokens.Color.planProgressTrack
                    )
                    .frame(height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStepIndex + 1) of \(max(stepCount, 1))")
    }
}

// MARK: - Hero card

struct PlanEditHeroCard: View {
    let state: PlanEditHeroState

    var body: some View {
        PlanEditCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(state.motivationalLine)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                    heroMetric(label: state.goalLabel, value: state.goalValue)
                    heroMetric(label: state.currentWeightLabel, value: state.currentWeight)
                    heroMetric(label: state.targetWeightLabel, value: state.targetWeight)
                }

                if let totalChangeLine = state.totalChangeLine {
                    Text(totalChangeLine)
                        .font(FormaTokens.Typography.caption.weight(.medium))
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let estimatedFinishLine = state.estimatedFinishLine {
                    Text(estimatedFinishLine)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private func heroMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(FormaTokens.Typography.caption2.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Edit Plan shell — Ocean Blue") {
    planEditShellPreview(palette: .oceanBlue, appearance: .dark)
}

#Preview("Edit Plan shell — Blossom Pink") {
    planEditShellPreview(palette: .blossomPink, appearance: .dark)
}

#Preview("Edit Plan shell — Emerald Green") {
    planEditShellPreview(palette: .emeraldGreen, appearance: .light)
}

#Preview("Edit Plan shell — Sunset Orange") {
    planEditShellPreview(palette: .sunsetOrange, appearance: .light)
}

@MainActor
private func planEditShellPreview(
    palette: AppThemePalette,
    appearance: AppAppearanceMode
) -> some View {
    let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
    let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)

    return NavigationStack {
        PlanEditShell(
            title: FormaProductCopy.PlanEditHero.shellTitle,
            stepCount: 5,
            currentStepIndex: 1,
            heroState: PlanEditHeroStateBuilder.build(projection: projection),
            confirmationTitle: FormaProductCopy.PlanEditCommon.next,
            showsConfirmation: true,
            isConfirmationEnabled: true,
            isConfirmationLoading: false,
            onCancel: {},
            onConfirm: {}
        ) {
            Form {
                Section {
                    Text("Step content")
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
    .formaThemePreview(appearance: appearance, palette: palette)
}
