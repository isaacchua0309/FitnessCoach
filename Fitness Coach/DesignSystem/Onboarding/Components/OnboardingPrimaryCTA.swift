//
//  OnboardingPrimaryCTA.swift
//  Fitness Coach
//
//  Forma — Shared primary action button for onboarding footers.
//

import SwiftUI

struct OnboardingPrimaryCTA: View {
    enum Variant {
        case standard
        case launch
    }

    let title: String
    var variant: Variant = .standard
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var accessibilityHint: String = ""
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launchGlow = false

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 48

    private var resolvedHeight: CGFloat {
        max(buttonHeight, FormaTokens.Layout.minTouchTarget)
    }

    var body: some View {
        Group {
            if variant == .launch {
                buttonCore.buttonStyle(OnboardingLaunchCTAPressStyle())
            } else {
                buttonCore.buttonStyle(.plain)
            }
        }
        .disabled(isLoading || !isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
        .onAppear {
            guard variant == .launch, isEnabled, !reduceMotion else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingPlanBlueprintLaunchTiming.readyDelay) {
                withAnimation(
                    .easeInOut(duration: OnboardingPlanBlueprintLaunchTiming.pulseDuration)
                        .repeatForever(autoreverses: true)
                ) {
                    launchGlow = true
                }
            }
        }
    }

    private var buttonCore: some View {
        Button(action: handleTap) {
            label
                .foregroundStyle(isEnabled && !isLoading ? OnboardingTheme.ctaText : OnboardingTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: resolvedHeight)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
                .overlay {
                    if showsLaunchGlow {
                        RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                            .stroke(OnboardingTheme.accent.opacity(launchGlow ? 0.55 : 0.25), lineWidth: 1.5)
                    }
                }
                .shadow(
                    color: showsLaunchGlow ? OnboardingTheme.accent.opacity(launchGlow ? 0.38 : 0.16) : .clear,
                    radius: showsLaunchGlow ? (launchGlow ? 12 : 5) : 0,
                    y: showsLaunchGlow ? 3 : 0
                )
        }
    }

    private var label: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            if isLoading {
                SwiftUI.ProgressView()
                    .tint(OnboardingTheme.ctaText)
            }
            Text(title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private var showsLaunchGlow: Bool {
        variant == .launch && isEnabled && !isLoading
    }

    private func handleTap() {
        OnboardingHaptics.primaryActionTapped(launch: variant == .launch)
        action()
    }

    @MainActor
    private var background: some View {
        Group {
            if isEnabled && !isLoading {
                OnboardingTheme.ctaBackground
            } else {
                OnboardingTheme.cardElevated
            }
        }
    }
}

private struct OnboardingLaunchCTAPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        OnboardingPrimaryCTA(title: "See what's next", action: {})
        OnboardingPrimaryCTA(title: "Build My Plan", variant: .launch, action: {})
        OnboardingPrimaryCTA(title: "Continue", isLoading: true, action: {})
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
