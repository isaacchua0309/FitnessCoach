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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            PlanHeroCard(state: heroState)
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, Layout.sectionSpacing)
                .animation(
                    PlanEditMotion.animation(PlanEditMotion.heroUpdate, reduceMotion: reduceMotion),
                    value: heroState
                )

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
        .planEditSupportsDynamicType()
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .animation(
            PlanEditMotion.animation(PlanEditMotion.progress, reduceMotion: reduceMotion),
            value: currentStepIndex
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FormaProductCopy.PlanEditAccessibility.progressLabel)
        .accessibilityValue(
            PlanEditAccessibility.progressValue(
                currentStep: currentStepIndex,
                stepCount: stepCount
            )
        )
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
