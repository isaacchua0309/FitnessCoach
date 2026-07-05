//
//  AdjustPlanView.swift
//  Fitness Coach
//
//  Forma — Root shell for the Adjust / Edit Plan wizard.
//

import SwiftUI

private enum AdjustPlanViewLayout {
    static let sectionSpacing: CGFloat = FormaTokens.Spacing.sm
    static let bottomInset: CGFloat = FormaTokens.Layout.tabBarScrollPadding
}

struct AdjustPlanView<Content: View>: View {
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

    @Environment(\.formaPlanColors) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            AdjustPlanStepIndicator(
                stepCount: stepCount,
                currentStepIndex: currentStepIndex
            )
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.xs)
            .padding(.bottom, AdjustPlanViewLayout.sectionSpacing)

            AdjustPlanSummaryCard(state: heroState)
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, AdjustPlanViewLayout.sectionSpacing)
                .animation(
                    PlanEditMotion.animation(PlanEditMotion.heroUpdate, reduceMotion: reduceMotion),
                    value: heroState
                )

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(theme.background.ignoresSafeArea())
        .adjustPlanHeader(
            title: title,
            confirmationTitle: confirmationTitle,
            showsConfirmation: showsConfirmation,
            isConfirmationEnabled: isConfirmationEnabled,
            isConfirmationLoading: isConfirmationLoading,
            onCancel: onCancel,
            onConfirm: onConfirm
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: AdjustPlanViewLayout.bottomInset)
        }
        .planEditSupportsDynamicType()
        .formaThemeReactive()
    }
}

#if DEBUG
#Preview("Adjust Plan — Ocean Blue") {
    adjustPlanViewPreview(palette: .oceanBlue, appearance: .dark)
}

#Preview("Adjust Plan — Blossom Pink") {
    adjustPlanViewPreview(palette: .blossomPink, appearance: .dark)
}

@MainActor
private func adjustPlanViewPreview(
    palette: AppThemePalette,
    appearance: AppAppearanceMode
) -> some View {
    let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
    let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)

    return NavigationStack {
        AdjustPlanView(
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
#endif
