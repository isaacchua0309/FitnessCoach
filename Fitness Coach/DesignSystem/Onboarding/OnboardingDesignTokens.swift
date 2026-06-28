//
//  OnboardingDesignTokens.swift
//  Fitness Coach
//
//  Forma — Shared motion, visual, and typography tokens for onboarding marketing screens.
//

import SwiftUI

// MARK: - Motion

enum OnboardingMotion {
    static let entranceEase = Animation.easeOut(duration: 0.28)
    static let heroEase = Animation.easeOut(duration: 0.34)
    static let transitionEase = Animation.easeInOut(duration: 0.32)
    static let indicatorEase = Animation.easeInOut(duration: 0.22)
    static let pulseEase = Animation.easeInOut(duration: 2.1).repeatForever(autoreverses: true)
    static let ringDrawEase = Animation.easeOut(duration: 0.9)
    static let atmosphereDrift = Animation.easeInOut(duration: 5.5).repeatForever(autoreverses: true)
    static let orbitRotation = Animation.linear(duration: 10).repeatForever(autoreverses: false)

    static let revealSpring = Animation.spring(response: 0.40, dampingFraction: 0.86)
    static let revealSweep = Animation.easeOut(duration: 0.42)
    static let revealCTAPulse = Animation.easeInOut(duration: 0.30)

    static let chromeDelay: Double = 0
    static let headlineDelay: Double = 0.05
    static let heroDelay: Double = 0.1
    static let supportingDelay: Double = 0.2
    static let benefitsDelay: Double = 0.3
    static let footerDelay: Double = 0.4

    static let benefitReelInterval: Duration = .seconds(3.2)
}

// MARK: - Visual

enum OnboardingVisual {
    static let coachRingDiameter: CGFloat = 168
    static let coachHaloDiameter: CGFloat = 200
    static let targetRingDiameter: CGFloat = 184
    static let targetHaloDiameter: CGFloat = 216

    static let coachRingLineWidth: CGFloat = 4
    static let targetRingLineWidth: CGFloat = 5.5

    static let benefitIconCompact: CGFloat = 24
    static let benefitIconHero: CGFloat = 32

    static let cardShadowRadius: CGFloat = 16
    static let cardShadowY: CGFloat = 8
    static let ringShadowRadius: CGFloat = 12

    static let accentCardBorderOpacity: Double = 0.22
    static let neutralCardBorderOpacity: Double = 0.4

    static let accessibilityZoneScale: CGFloat = 0.88

    static let atmosphereOrbRadius: CGFloat = 140
    static let atmosphereBlur: CGFloat = 36
    static let atmosphereTopOrbOffset = CGPoint(x: 110, y: -120)
    static let atmosphereBottomOrbOffset = CGPoint(x: -120, y: 220)
    static let atmosphereHeroWashWidth: CGFloat = 340
    static let atmosphereHeroWashHeight: CGFloat = 260
    static let atmosphereHeroWashOffsetY: CGFloat = 40

    static let illustrationPlateCornerRadius: CGFloat = 28
    static let ringTickCount: Int = 12
}

// MARK: - Typography

enum OnboardingMarketingTypography {
    static let screenHeadline = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let visionHeadline = Font.system(.title, design: .rounded).weight(.bold)
    static let supporting = Font.title3.weight(.medium)
    static let benefitTitle = Font.system(.title3, design: .rounded).weight(.semibold)
    static let benefitTitlePlain = Font.title3.weight(.semibold)
    static let goalIntent = Font.subheadline.weight(.semibold)
    static let footer = Font.footnote.weight(.medium)
    static let metric = Font.system(size: 44, weight: .bold, design: .rounded)
}

// MARK: - Benefit item

struct OnboardingBenefitItem: Equatable, Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String

    init(icon: String, title: String) {
        self.id = title
        self.icon = icon
        self.title = title
    }
}

// MARK: - Illustration

enum OnboardingIllustrationStyle: Equatable {
    case coachWaiting
    case targetRing(
        intentLabel: String,
        weightLabel: String,
        pathStyle: OnboardingFormaProofPathStyle,
        ringProgress: Double
    )
}

// MARK: - Card surfaces

enum OnboardingCardSurfaceStyle {
    case elevated
    case accent
    case neutral
}

struct OnboardingCardSurface: ViewModifier {
    let style: OnboardingCardSurfaceStyle

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .fill(OnboardingTheme.cardElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            )
    }

    private var borderColor: Color {
        switch style {
        case .elevated, .neutral:
            return OnboardingTheme.border.opacity(OnboardingVisual.neutralCardBorderOpacity)
        case .accent:
            return OnboardingTheme.accent.opacity(OnboardingVisual.accentCardBorderOpacity)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .accent:
            return OnboardingTheme.accent.opacity(0.08)
        case .elevated, .neutral:
            return .clear
        }
    }

    private var shadowRadius: CGFloat {
        style == .accent ? OnboardingVisual.cardShadowRadius : 0
    }

    private var shadowY: CGFloat {
        style == .accent ? OnboardingVisual.cardShadowY : 0
    }
}

extension View {
    func onboardingCardSurface(_ style: OnboardingCardSurfaceStyle = .elevated) -> some View {
        modifier(OnboardingCardSurface(style: style))
    }
}

// MARK: - Gradients

enum OnboardingGradients {
  @MainActor
  static func heroGlow(centerOpacity: Double = 0.26, midOpacity: Double = 0.08) -> RadialGradient {
        RadialGradient(
            colors: [
                OnboardingTheme.accent.opacity(centerOpacity),
                OnboardingTheme.accent.opacity(midOpacity),
                .clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: OnboardingVisual.targetRingDiameter * 0.58
        )
    }

  @MainActor
  static var cardAccentWash: LinearGradient {
        LinearGradient(
            colors: [
                OnboardingTheme.accent.opacity(0.1),
                OnboardingTheme.accent.opacity(0.03),
                OnboardingTheme.cardElevated.opacity(0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

  @MainActor
  static var illustrationPlate: LinearGradient {
        LinearGradient(
            colors: [
                OnboardingTheme.accent.opacity(0.08),
                OnboardingTheme.surfaceSubtle.opacity(0.55),
                OnboardingTheme.cardElevated.opacity(0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @MainActor
    static var footerFade: LinearGradient {
        LinearGradient(
            colors: [
                OnboardingTheme.background.opacity(0),
                OnboardingTheme.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Entrance

enum OnboardingEntranceStage: Int, CaseIterable, Comparable {
    case chrome = 0
    case headline = 1
    case hero = 2
    case supporting = 3
    case benefits = 4
    case footer = 5

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var delay: Double {
        switch self {
        case .chrome: OnboardingMotion.chromeDelay
        case .headline: OnboardingMotion.headlineDelay
        case .hero: OnboardingMotion.heroDelay
        case .supporting: OnboardingMotion.supportingDelay
        case .benefits: OnboardingMotion.benefitsDelay
        case .footer: OnboardingMotion.footerDelay
        }
    }

    var usesScale: Bool {
        self == .hero
    }
}

struct OnboardingEntranceModifier: ViewModifier {
    let isVisible: Bool
    let stage: OnboardingEntranceStage
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
    }
}

extension View {
    func onboardingEntrance(
        visible: Bool,
        stage: OnboardingEntranceStage,
        reduceMotion: Bool
    ) -> some View {
        modifier(OnboardingEntranceModifier(isVisible: visible, stage: stage, reduceMotion: reduceMotion))
    }
}

enum OnboardingEntranceAnimator {
    @MainActor
    static func reveal(
        stages: Set<OnboardingEntranceStage>,
        reduceMotion: Bool,
        update: @escaping (OnboardingEntranceStage, Bool) -> Void
    ) {
        if reduceMotion {
            for stage in OnboardingEntranceStage.allCases {
                update(stage, stages.contains(stage))
            }
            return
        }

        for stage in OnboardingEntranceStage.allCases where stages.contains(stage) {
            let animation: Animation = stage == .hero
                ? OnboardingMotion.heroEase.delay(stage.delay)
                : OnboardingMotion.entranceEase.delay(stage.delay)
            withAnimation(animation) {
                update(stage, true)
            }
        }
    }
}
