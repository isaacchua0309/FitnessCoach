//
//  OnboardingVisionScreenShell.swift
//  Fitness Coach
//
//  Forma — Fixed-viewport layout shell for onboarding marketing screens.
//

import SwiftUI

struct OnboardingVisionScreenShell<Progress: View, Content: View>: View {
    let accessibilityLabel: String
    var atmosphereStyle: OnboardingAtmosphereStyle = .milestone
    var activeStages: Set<OnboardingEntranceStage> = Set(OnboardingEntranceStage.allCases)
    var onAppear: (() -> Void)? = nil

    @ViewBuilder let progress: () -> Progress
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleStages: Set<OnboardingEntranceStage> = []

    var body: some View {
        ZStack {
            OnboardingMarketingAtmosphere(style: atmosphereStyle)

            VStack(spacing: 0) {
                progress()
                    .padding(.bottom, FormaTokens.Spacing.sm)
                    .onboardingEntrance(
                        visible: isVisible(.chrome),
                        stage: .chrome,
                        reduceMotion: reduceMotion
                    )

                GeometryReader { geometry in
                    content()
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                        .environment(\.onboardingContentHeight, geometry.size.height)
                        .environment(\.onboardingEntranceVisibleStages, visibleStages)
                        .environment(\.onboardingReduceMotion, reduceMotion)
                }
            }
            .padding(.horizontal, OnboardingTheme.pagePadding)
            .padding(.top, OnboardingLayout.progressHeaderTop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            OnboardingEntranceAnimator.reveal(
                stages: activeStages,
                reduceMotion: reduceMotion
            ) { stage, visible in
                if visible {
                    visibleStages.insert(stage)
                } else {
                    visibleStages.remove(stage)
                }
            }
            onAppear?()
        }
    }

    private func isVisible(_ stage: OnboardingEntranceStage) -> Bool {
        reduceMotion || visibleStages.contains(stage)
    }
}

// MARK: - Environment

private struct OnboardingEntranceVisibleStagesKey: EnvironmentKey {
    static let defaultValue: Set<OnboardingEntranceStage> = Set(OnboardingEntranceStage.allCases)
}

private struct OnboardingReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onboardingEntranceVisibleStages: Set<OnboardingEntranceStage> {
        get { self[OnboardingEntranceVisibleStagesKey.self] }
        set { self[OnboardingEntranceVisibleStagesKey.self] = newValue }
    }

    var onboardingReduceMotion: Bool {
        get { self[OnboardingReduceMotionKey.self] }
        set { self[OnboardingReduceMotionKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func onboardingStageEntrance(_ stage: OnboardingEntranceStage) -> some View {
        modifier(OnboardingStageEntranceModifier(stage: stage))
    }
}

private struct OnboardingStageEntranceModifier: ViewModifier {
    @Environment(\.onboardingEntranceVisibleStages) private var visibleStages
    @Environment(\.onboardingReduceMotion) private var reduceMotion

    let stage: OnboardingEntranceStage

    func body(content: Content) -> some View {
        content
            .onboardingEntrance(
                visible: reduceMotion || visibleStages.contains(stage),
                stage: stage,
                reduceMotion: reduceMotion
            )
    }
}

#if DEBUG
#Preview {
    OnboardingVisionScreenShell(
        accessibilityLabel: "Preview"
    ) {
        OnboardingStageProgressHeader(currentStep: .almostThere, showsTitles: false)
    } content: {
        VStack(spacing: 0) {
            OnboardingIllustrationContainer(style: .coachWaiting)
                .onboardingVisionZone(.hero)
                .onboardingStageEntrance(.hero)

            OnboardingHeroSection(
                headline: "Your personalized coach is waiting.",
                supporting: "You don't need more motivation."
            )
            .onboardingVisionZone(.narrative)
            .onboardingStageEntrance(.headline)

            OnboardingFooterMessage(message: "Forma turns your answers into daily targets.")
                .onboardingVisionZone(.footer)
                .onboardingStageEntrance(.footer)
        }
        .onboardingVisionZoneWeights(OnboardingVisionZoneWeights.almostThere)
    }
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
