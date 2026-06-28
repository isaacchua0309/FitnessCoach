//
//  OnboardingTrainingRhythmStepView.swift
//  Fitness Coach
//
//  Forma — Training rhythm chips (Screen B of tap-first activity onboarding).
//

import SwiftUI

struct OnboardingTrainingRhythmStepView: View {
    @Binding var formState: OnboardingFormState
    var showsEmbeddedHeader: Bool = false

    private var trainingDaysBinding: Binding<OnboardingTrainingDaysChip> {
        Binding(
            get: { formState.trainingDaysChip },
            set: { formState.trainingDaysChip = $0 }
        )
    }

    private var stepsBandBinding: Binding<OnboardingDailyStepsBand> {
        Binding(
            get: { formState.dailyStepsBand },
            set: { formState.dailyStepsBand = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if showsEmbeddedHeader {
                embeddedHeader
            }

            trainingDaysSection
            stepsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            formState.ensureTrainingRhythmValues()
        }
    }

    private var embeddedHeader: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V3.TrainingRhythm.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            Text(FormaProductCopy.Onboarding.V3.TrainingRhythm.subtitle)
                .font(.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trainingDaysSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V3.TrainingRhythm.trainingDaysSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            OnboardingPillGrid(
                items: OnboardingTrainingDaysChip.allCases,
                selection: trainingDaysBinding,
                titleForItem: \.displayLabel,
                columnCount: 3,
                accessibilityGroupLabel: FormaProductCopy.Onboarding.V3.TrainingRhythm.trainingDaysSectionTitle
            )
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V3.TrainingRhythm.stepsSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            OnboardingPillGrid(
                items: OnboardingDailyStepsBand.allCases,
                selection: stepsBandBinding,
                titleForItem: \.title,
                subtitleForItem: { band in
                    dynamicTypeSizeAllowsSubtitle ? band.subtitle : nil
                },
                columnCount: 2,
                accessibilityGroupLabel: FormaProductCopy.Onboarding.V3.TrainingRhythm.stepsSectionTitle
            )
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var dynamicTypeSizeAllowsSubtitle: Bool {
        dynamicTypeSize < .accessibility1
    }
}

#Preview("Defaults") {
    OnboardingTrainingRhythmStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Training days — 2") {
    OnboardingTrainingRhythmStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.trainingDaysChip = .two
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Steps — not sure") {
    OnboardingTrainingRhythmStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.dailyStepsBand = .notSure
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Steps — high") {
    OnboardingTrainingRhythmStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.dailyStepsBand = .high
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}


