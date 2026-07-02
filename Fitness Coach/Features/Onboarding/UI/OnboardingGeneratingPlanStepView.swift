//
//  OnboardingGeneratingPlanStepView.swift
//  Fitness Coach
//
//  Forma — Full-screen staged plan generation moment for onboarding.
//

import SwiftUI

struct OnboardingGeneratingPlanStepView: View {
    let presentation: OnboardingGeneratingPlanPresentation
    let viewState: OnboardingViewState
    let onRetry: () -> Void
    let onGoBack: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heroVisible = false
    @State private var titleVisible = false
    @State private var activeStepIndex = -1
    @State private var completedStepCount = 0
    @State private var showsSlowMessage = false
    @State private var lastAnnouncedStepIndex = -1

    private let checklist = FormaProductCopy.Onboarding.V2.Generating.checklist
    private let stepDurations = OnboardingGeneratingPlanTiming.stepActiveDurations

    private var isGenerating: Bool {
        viewState == .generatingPlanAnimated
    }

    private var showsSuccess: Bool {
        viewState == .generationSucceeded
    }

    private var showsFailure: Bool {
        viewState == .generationFailed
    }

    private var heroStyle: OnboardingGeneratingPlanHeroView.Style {
        if showsFailure { return .failure }
        if showsSuccess { return .success }
        return .generating
    }

    private var progress: Double {
        if showsSuccess { return 1 }
        guard !checklist.isEmpty else { return 0 }
        return Double(completedStepCount) / Double(checklist.count)
    }

    private var activeStepLabel: String? {
        guard activeStepIndex >= 0, activeStepIndex < checklist.count else { return nil }
        return checklist[activeStepIndex]
    }

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.lg) {
            Spacer(minLength: FormaTokens.Spacing.lg)

            OnboardingGeneratingPlanHeroView(style: heroStyle, progress: progress)
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1 : 0.96)

            titleSection

            if showsFailure {
                failureContent
            } else if showsSuccess {
                EmptyView()
            } else {
                stepSection
            }

            Spacer(minLength: FormaTokens.Spacing.lg)

            if !showsFailure, !showsSuccess {
                anticipationSection
            }
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .task(id: viewState == .generatingPlanAnimated) {
            guard viewState == .generatingPlanAnimated else { return }
            await runGenerationPresentation()
        }
        .onChange(of: viewState) { _, newValue in
            guard newValue == .generationSucceeded else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: OnboardingGeneratingPlanTiming.stepTransitionAnimation)) {
                heroVisible = true
                titleVisible = true
            }
        }
        .onChange(of: activeStepIndex) { _, newValue in
            announceStepChangeIfNeeded(newValue)
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Text(currentTitle)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if !showsFailure {
                Text(presentation.subtitle)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(titleVisible ? 1 : 0)
        .offset(y: titleVisible ? 0 : 6)
    }

    private var currentTitle: String {
        if showsFailure {
            return FormaProductCopy.Onboarding.V2.Generating.failureTitle
        }
        if showsSuccess {
            return FormaProductCopy.Onboarding.V2.Generating.successTitle
        }
        return FormaProductCopy.Onboarding.V2.Generating.title
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepSection: some View {
        if reduceMotion {
            reduceMotionStepList
        } else {
            activeStepCard
        }

        if showsSlowMessage {
            Text(FormaProductCopy.Onboarding.V2.Generating.slowGenerationMessage)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .transition(.opacity)
        }
    }

    private var activeStepCard: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            stepProgressDots

            if let activeStepLabel {
                HStack(spacing: FormaTokens.Spacing.md) {
                    SwiftUI.ProgressView()
                        .controlSize(.regular)
                        .tint(OnboardingTheme.primary)
                        .accessibilityHidden(true)

                    Text(activeStepLabel)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, FormaTokens.Spacing.cardPadding)
                .padding(.vertical, FormaTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(stepCardBackground)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
                .id(activeStepLabel)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: OnboardingGeneratingPlanTiming.stepTransitionAnimation),
            value: activeStepLabel
        )
    }

    private var reduceMotionStepList: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            ForEach(Array(checklist.enumerated()), id: \.offset) { index, item in
                reduceMotionStepRow(item: item, index: index)
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stepCardBackground)
    }

    private func reduceMotionStepRow(item: String, index: Int) -> some View {
        let status = stepStatus(for: index)
        return HStack(spacing: FormaTokens.Spacing.md) {
            stepIcon(for: status)
            Text(item)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(status == .pending ? OnboardingTheme.tertiaryText : OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(status == .active ? OnboardingTheme.accent.opacity(0.12) : .clear)
        )
    }

    private var stepProgressDots: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(0..<checklist.count, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 7, height: 7)
                    .overlay {
                        if stepStatus(for: index) == .completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 5, weight: .bold))
                                .foregroundStyle(OnboardingTheme.accent)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private func dotColor(for index: Int) -> Color {
        switch stepStatus(for: index) {
        case .pending:
            return OnboardingTheme.progressTrack.opacity(0.8)
        case .active:
            return OnboardingTheme.accent.opacity(0.35)
        case .completed:
            return OnboardingTheme.accent.opacity(0.2)
        }
    }

    private func stepIcon(for status: StepStatus) -> some View {
        Group {
            switch status {
            case .pending:
                Image(systemName: "circle")
                    .foregroundStyle(OnboardingTheme.tertiaryText.opacity(0.7))
            case .active:
                SwiftUI.ProgressView()
                    .controlSize(.small)
                    .tint(OnboardingTheme.primary)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(OnboardingTheme.accent)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }

    private enum StepStatus {
        case pending
        case active
        case completed
    }

    private func stepStatus(for index: Int) -> StepStatus {
        if index < completedStepCount { return .completed }
        if index == activeStepIndex { return .active }
        return .pending
    }

    private var stepCardBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(OnboardingTheme.card.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .stroke(OnboardingTheme.border.opacity(0.55), lineWidth: 1)
            )
    }

    // MARK: - Failure

    private var failureContent: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            Text(FormaProductCopy.Onboarding.V2.Generating.failureMessage)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onRetry) {
                Text(FormaProductCopy.Onboarding.V2.Generating.tryAgainCTA)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(OnboardingTheme.primary)

            Button(action: onGoBack) {
                Text(FormaProductCopy.Onboarding.V2.Generating.goBackCTA)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(OnboardingTheme.secondaryText)
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity)
        .background(stepCardBackground)
    }

    private var anticipationSection: some View {
        Text(FormaProductCopy.Onboarding.V2.Generating.anticipationText)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(OnboardingTheme.tertiaryText)
            .multilineTextAlignment(.center)
    }

    // MARK: - Accessibility

    private var accessibilitySummary: String {
        if showsFailure {
            return [
                FormaProductCopy.Onboarding.V2.Generating.failureTitle,
                FormaProductCopy.Onboarding.V2.Generating.failureMessage
            ].joined(separator: ". ")
        }
        if showsSuccess {
            return [
                FormaProductCopy.Onboarding.V2.Generating.successTitle,
                FormaProductCopy.Onboarding.Flow.PlanReveal.subtitle
            ].joined(separator: ". ")
        }
        if let activeStepLabel {
            return [
                FormaProductCopy.Onboarding.V2.Generating.title,
                activeStepLabel
            ].joined(separator: ". ")
        }
        return FormaProductCopy.Onboarding.V2.Generating.title
    }

    private func announceStepChangeIfNeeded(_ index: Int) {
        guard index >= 0, index < checklist.count, index != lastAnnouncedStepIndex else { return }
        lastAnnouncedStepIndex = index
        UIAccessibility.post(notification: .announcement, argument: checklist[index])
    }

    // MARK: - Animation

    @MainActor
    private func runGenerationPresentation() async {
        resetPresentationState()

        guard isGenerating else { return }
        OnboardingGeneratingPlanTiming.validateChecklistAlignment()

        if reduceMotion {
            heroVisible = true
            titleVisible = true
        } else {
            withAnimation(.easeOut(duration: 0.28)) {
                heroVisible = true
            }
            try? await Task.sleep(
                nanoseconds: UInt64(OnboardingGeneratingPlanTiming.titleSubtitleDelay * 1_000_000_000)
            )
            guard !Task.isCancelled, isGenerating else { return }
            withAnimation(.easeOut(duration: 0.26)) {
                titleVisible = true
            }
        }

        async let slowMessage: Void = showSlowGenerationMessageIfNeeded()
        await runStepSequence()
        _ = await slowMessage
    }

    @MainActor
    private func runStepSequence() async {
        try? await Task.sleep(
            nanoseconds: UInt64(OnboardingGeneratingPlanTiming.firstStepDelay * 1_000_000_000)
        )
        guard !Task.isCancelled, canContinueChecklistAnimation else { return }

        for (index, duration) in stepDurations.enumerated() {
            guard !Task.isCancelled, canContinueChecklistAnimation else { return }

            withAnimation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: OnboardingGeneratingPlanTiming.stepTransitionAnimation)
            ) {
                activeStepIndex = index
            }

            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled, canContinueChecklistAnimation else { return }

            withAnimation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: OnboardingGeneratingPlanTiming.stepTransitionAnimation)
            ) {
                completedStepCount = index + 1
                if index == stepDurations.count - 1 {
                    activeStepIndex = -1
                }
            }
        }

        guard !Task.isCancelled, canContinueChecklistAnimation else { return }
    }

    private var canContinueChecklistAnimation: Bool {
        viewState == .generatingPlanAnimated
    }

    @MainActor
    private func showSlowGenerationMessageIfNeeded() async {
        try? await Task.sleep(
            nanoseconds: UInt64(OnboardingGeneratingPlanTiming.slowGenerationThreshold * 1_000_000_000)
        )
        guard !Task.isCancelled, isGenerating, completedStepCount < checklist.count else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            showsSlowMessage = true
        }
    }

    @MainActor
    private func resetPresentationState() {
        heroVisible = reduceMotion
        titleVisible = reduceMotion
        activeStepIndex = -1
        completedStepCount = 0
        showsSlowMessage = false
        lastAnnouncedStepIndex = -1
    }
}

#if DEBUG
private enum OnboardingGeneratingPlanPreviewSupport {

    static func lossPresentation() -> OnboardingGeneratingPlanPresentation {
        OnboardingGeneratingPlanCopyBuilder.build(from: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(90, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(-12, in: &state)
            return state
        }())
    }

    static func gainPresentation() -> OnboardingGeneratingPlanPresentation {
        OnboardingGeneratingPlanCopyBuilder.build(from: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(8, in: &state)
            return state
        }())
    }

    static func maintainPresentation() -> OnboardingGeneratingPlanPresentation {
        OnboardingGeneratingPlanCopyBuilder.build(from: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(72, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(0, in: &state)
            return state
        }())
    }
}

#Preview("Generating — Loss") {
    OnboardingGeneratingPlanStepView(
        presentation: OnboardingGeneratingPlanPreviewSupport.lossPresentation(),
        viewState: .generatingPlanAnimated,
        onRetry: {},
        onGoBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Generating — Gain") {
    OnboardingGeneratingPlanStepView(
        presentation: OnboardingGeneratingPlanPreviewSupport.gainPresentation(),
        viewState: .generatingPlanAnimated,
        onRetry: {},
        onGoBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Generating — Maintain") {
    OnboardingGeneratingPlanStepView(
        presentation: OnboardingGeneratingPlanPreviewSupport.maintainPresentation(),
        viewState: .generatingPlanAnimated,
        onRetry: {},
        onGoBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Failed") {
    OnboardingGeneratingPlanStepView(
        presentation: OnboardingGeneratingPlanPreviewSupport.lossPresentation(),
        viewState: .generationFailed,
        onRetry: {},
        onGoBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Small iPhone") {
    OnboardingGeneratingPlanStepView(
        presentation: OnboardingGeneratingPlanPreviewSupport.lossPresentation(),
        viewState: .generatingPlanAnimated,
        onRetry: {},
        onGoBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
