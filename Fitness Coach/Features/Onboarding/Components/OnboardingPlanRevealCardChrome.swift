//
//  OnboardingPlanRevealCardChrome.swift
//  Fitness Coach
//
//  Forma — Shared chrome, entrance, and layout helpers for plan reveal cards.
//

import SwiftUI

// MARK: - Entrance

enum OnboardingPlanRevealEntranceStyle {
    case fadeOnly
    case scaleIn
    case fadeScale
    case springIn
    case fadeUp
}

enum OnboardingPlanRevealEntranceStage: Hashable, CaseIterable {
    case celebrationTitle
    case achievementBadge
    case heroIllustration
    case goalCard
    case journey
    case firstWeek
    case nutrition
    case coach

    var delay: Double {
        switch self {
        case .celebrationTitle: OnboardingPlanRevealTiming.celebrationTitle
        case .achievementBadge: OnboardingPlanRevealTiming.achievementBadge
        case .heroIllustration: OnboardingPlanRevealTiming.heroIllustration
        case .goalCard: OnboardingPlanRevealTiming.goalCard
        case .journey: OnboardingPlanRevealTiming.journey
        case .firstWeek: OnboardingPlanRevealTiming.firstWeek
        case .nutrition: OnboardingPlanRevealTiming.nutrition
        case .coach: OnboardingPlanRevealTiming.coach
        }
    }

    var style: OnboardingPlanRevealEntranceStyle {
        switch self {
        case .celebrationTitle: .fadeOnly
        case .achievementBadge: .scaleIn
        case .heroIllustration: .fadeScale
        case .goalCard: .springIn
        case .journey, .firstWeek, .nutrition: .fadeUp
        case .coach: .fadeOnly
        }
    }

    var animation: Animation {
        switch style {
        case .fadeOnly, .fadeUp:
            return Animation.easeOut(duration: OnboardingPlanRevealTiming.fadeDuration)
        case .scaleIn, .fadeScale:
            return Animation.easeOut(duration: OnboardingPlanRevealTiming.fadeDuration)
        case .springIn:
            return OnboardingMotion.revealSpring
        }
    }
}

private struct OnboardingPlanRevealVisibleStagesKey: EnvironmentKey {
    static let defaultValue: Set<OnboardingPlanRevealEntranceStage> =
        Set(OnboardingPlanRevealEntranceStage.allCases)
}

private struct OnboardingPlanRevealGoalSweepActiveKey: EnvironmentKey {
    static let defaultValue = false
}

private struct OnboardingPlanRevealSuccessHandoffKey: EnvironmentKey {
    static let defaultValue = false
}

private struct OnboardingPlanRevealCompactLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onboardingPlanRevealVisibleStages: Set<OnboardingPlanRevealEntranceStage> {
        get { self[OnboardingPlanRevealVisibleStagesKey.self] }
        set { self[OnboardingPlanRevealVisibleStagesKey.self] = newValue }
    }

    var onboardingPlanRevealGoalSweepActive: Bool {
        get { self[OnboardingPlanRevealGoalSweepActiveKey.self] }
        set { self[OnboardingPlanRevealGoalSweepActiveKey.self] = newValue }
    }

    var onboardingPlanRevealUsesSuccessHandoff: Bool {
        get { self[OnboardingPlanRevealSuccessHandoffKey.self] }
        set { self[OnboardingPlanRevealSuccessHandoffKey.self] = newValue }
    }

    var onboardingPlanRevealUsesCompactLayout: Bool {
        get {
            if onboardingPlanRevealLayoutProfile == .compact {
                return true
            }
            return self[OnboardingPlanRevealCompactLayoutKey.self]
        }
        set { self[OnboardingPlanRevealCompactLayoutKey.self] = newValue }
    }
}

extension View {
    func onboardingPlanRevealEntrance(_ stage: OnboardingPlanRevealEntranceStage) -> some View {
        modifier(OnboardingPlanRevealEntranceModifier(stage: stage))
    }

    func onboardingPlanRevealGoalSweep() -> some View {
        modifier(OnboardingPlanRevealGoalSweepModifier())
    }
}

private struct OnboardingPlanRevealEntranceModifier: ViewModifier {
    @Environment(\.onboardingPlanRevealVisibleStages) private var visibleStages
    @Environment(\.onboardingPlanRevealUsesSuccessHandoff) private var usesSuccessHandoff
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let stage: OnboardingPlanRevealEntranceStage

    private var isVisible: Bool {
        reduceMotion || visibleStages.contains(stage)
    }

    func body(content: Content) -> some View {
        content
            .opacity(resolvedOpacity)
            .offset(y: resolvedOffsetY)
            .scaleEffect(resolvedScale, anchor: scaleAnchor)
            .animation(reduceMotion ? nil : stage.animation, value: isVisible)
    }

    private var resolvedOpacity: Double {
        isVisible ? 1 : 0
    }

    private var resolvedOffsetY: CGFloat {
        guard !isVisible else { return 0 }
        switch stage.style {
        case .fadeOnly, .scaleIn, .fadeScale:
            return 0
        case .springIn:
            return 10
        case .fadeUp:
            return 8
        }
    }

    private var resolvedScale: CGFloat {
        guard !isVisible else { return 1 }
        if stage == .heroIllustration, usesSuccessHandoff {
            return 0.98
        }
        switch stage.style {
        case .fadeOnly, .fadeUp:
            return 1
        case .scaleIn:
            return 0.88
        case .fadeScale:
            return 0.94
        case .springIn:
            return 0.96
        }
    }

    private var scaleAnchor: UnitPoint {
        stage == .achievementBadge ? .leading : .center
    }
}

private struct OnboardingPlanRevealGoalSweepModifier: ViewModifier {
    @Environment(\.onboardingPlanRevealGoalSweepActive) private var sweepActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsSweep = false
    @State private var sweepProgress: CGFloat = -0.5

    func body(content: Content) -> some View {
        content
            .overlay {
                if showsSweep {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.18),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 0.32)
                        .offset(x: (width + width * 0.32) * sweepProgress - width * 0.32)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    )
                }
            }
            .onChange(of: sweepActive) { _, isActive in
                guard isActive, !reduceMotion else { return }
                showsSweep = true
                sweepProgress = -0.5
                withAnimation(OnboardingMotion.revealSweep) {
                    sweepProgress = 1.15
                }
                Task { @MainActor in
                    try? await Task.sleep(
                        nanoseconds: UInt64(OnboardingPlanRevealTiming.sweepDuration * 1_000_000_000)
                    )
                    showsSweep = false
                    sweepProgress = -0.5
                }
            }
    }
}

enum OnboardingPlanRevealEntranceAnimator {
    @MainActor
    static func revealAccumulating(
        stages: Set<OnboardingPlanRevealEntranceStage>,
        reduceMotion: Bool,
        onReveal: @escaping (OnboardingPlanRevealEntranceStage) -> Void,
        onGoalSweep: @escaping () -> Void = {}
    ) {
        if reduceMotion {
            for stage in OnboardingPlanRevealEntranceStage.allCases where stages.contains(stage) {
                onReveal(stage)
            }
            return
        }

        for stage in OnboardingPlanRevealEntranceStage.allCases where stages.contains(stage) {
            withAnimation(stage.animation.delay(stage.delay)) {
                onReveal(stage)
            }

            if stage == .goalCard {
                let sweepDelay = stage.delay + OnboardingPlanRevealTiming.goalSweepAfterGoalCard
                Task { @MainActor in
                    try? await Task.sleep(
                        nanoseconds: UInt64(sweepDelay * 1_000_000_000)
                    )
                    onGoalSweep()
                }
            }
        }
    }

    /// After plan reveal handoff — goal and journey are already visible; headline and protect footer animate in.
    @MainActor
    static func revealSavePlanContinuation(
        reduceMotion: Bool,
        onReveal: @escaping (OnboardingPlanRevealEntranceStage) -> Void,
        onInitialVisible: @escaping (Set<OnboardingPlanRevealEntranceStage>) -> Void
    ) {
        let carryOver: Set<OnboardingPlanRevealEntranceStage> = [
            .achievementBadge,
            .heroIllustration,
            .goalCard,
            .journey
        ]

        if reduceMotion {
            onInitialVisible(Set(OnboardingPlanRevealEntranceStage.allCases))
            return
        }

        onInitialVisible(carryOver)

        let timeline: [(OnboardingPlanRevealEntranceStage, TimeInterval)] = [
            (.celebrationTitle, OnboardingPlanRevealTiming.continuationCelebrationTitle),
            (.coach, OnboardingPlanRevealTiming.continuationCoachMessage),
            (.firstWeek, OnboardingPlanRevealTiming.continuationProtectFooter)
        ]

        for (stage, delay) in timeline {
            withAnimation(stage.animation.delay(delay)) {
                onReveal(stage)
            }
        }
    }
}

// MARK: - Section header

struct OnboardingPlanRevealSectionHeader: View {
    let title: String
    var usesHeaderTrait: Bool = true

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(OnboardingTheme.tertiaryText)
            .tracking(0.4)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .accessibilityAddTraits(usesHeaderTrait ? .isHeader : [])
    }
}

// MARK: - Card surfaces

enum OnboardingPlanRevealCardSurface: Hashable {
    case goalHero
    case standard
    case subtle
    case coach
}

struct OnboardingPlanRevealCardBackground: View {
    let surface: OnboardingPlanRevealCardSurface

    var body: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(surfaceFill)
            .overlay {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private var surfaceFill: AnyShapeStyle {
        switch surface {
        case .goalHero:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        FormaTokens.Color.accentMuted.opacity(0.85),
                        FormaTokens.Color.surfaceSubtle
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .standard:
            return AnyShapeStyle(OnboardingGradients.cardAccentWash)
        case .subtle:
            return AnyShapeStyle(FormaTokens.Color.surfaceSubtle)
        case .coach:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        FormaTokens.Color.accentMuted.opacity(0.42),
                        FormaTokens.Color.accentMuted.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var borderColor: Color {
        switch surface {
        case .goalHero:
            return OnboardingTheme.accent.opacity(0.18)
        case .standard, .coach:
            return OnboardingTheme.accent.opacity(OnboardingVisual.accentCardBorderOpacity)
        case .subtle:
            return OnboardingTheme.border.opacity(OnboardingVisual.neutralCardBorderOpacity)
        }
    }

    private var shadowColor: Color {
        surface == .goalHero ? OnboardingTheme.accent.opacity(0.08) : .clear
    }

    private var shadowRadius: CGFloat {
        surface == .goalHero ? OnboardingVisual.cardShadowRadius : 0
    }

    private var shadowY: CGFloat {
        surface == .goalHero ? OnboardingVisual.cardShadowY : 0
    }
}

extension View {
    func onboardingPlanRevealCardPadding() -> some View {
        modifier(OnboardingPlanRevealCardPaddingModifier())
    }
}

private struct OnboardingPlanRevealCardPaddingModifier: ViewModifier {
    @Environment(\.onboardingPlanRevealUsesCompactLayout) private var usesCompactLayout

    func body(content: Content) -> some View {
        content.padding(usesCompactLayout ? FormaTokens.Spacing.sm : OnboardingLayout.compactCardPadding)
    }
}

#if DEBUG
#Preview("Surfaces") {
    VStack(spacing: 12) {
        ForEach(
            [OnboardingPlanRevealCardSurface.goalHero, .standard, .subtle, .coach],
            id: \.self
        ) { surface in
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card)
                .fill(.clear)
                .frame(height: 56)
                .background { OnboardingPlanRevealCardBackground(surface: surface) }
        }
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
