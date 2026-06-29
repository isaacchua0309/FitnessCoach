//
//  PremiumWeightRulerView.swift
//  Fitness Coach
//
//  Forma — Compact dark card-style horizontal weight ruler.
//

import SwiftHorizontalRuler
import SwiftUI
import UIKit

/// Reusable premium ruler chrome wrapping a custom tiered tick renderer.
/// Keeps the scroll/snap behavior while presenting a dark graphite card surface,
/// edge fades, and a fixed UIKit center indicator (line + marker + glow).
struct PremiumWeightRulerView: View {
    @Binding var value: Double
    let config: HorizontalRulerConfig
    var height: CGFloat = OnboardingLayout.premiumRulerHeight

    var accessibilityLabel: String?
    var accessibilityValue: String?
    var accessibilityHint: String?

    private let cornerRadius = FormaTokens.Radius.card
    private let fadeWidth = OnboardingLayout.premiumRulerFadeWidth

    var body: some View {
        ZStack {
            cardBackground

            PremiumWeightRulerScrollViewRepresentable(value: $value, config: config)
                .padding(.horizontal, FormaTokens.Spacing.sm)
                .padding(.vertical, OnboardingLayout.premiumRulerVerticalPadding)

            edgeFades
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityValue(accessibilityValue ?? "")
        .accessibilityHint(accessibilityHint ?? "")
    }

    // MARK: - Chrome

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(OnboardingGradients.cardAccentWash)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        OnboardingTheme.border.opacity(OnboardingVisual.neutralCardBorderOpacity),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        OnboardingTheme.cardElevated.opacity(0.22),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height * 0.42)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
    }

    private var edgeFades: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [fadeEdgeColor, fadeEdgeColor.opacity(0.85), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fadeWidth)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [.clear, fadeEdgeColor.opacity(0.85), fadeEdgeColor],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fadeWidth)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @MainActor
    private var fadeEdgeColor: Color {
        OnboardingTheme.cardElevated
    }

    /// Shared ruler configuration for onboarding target-weight selection.
    static func makeConfig(
        range: ClosedRange<Double>,
        unitSystem: UnitSystem
    ) -> HorizontalRulerConfig {
        HorizontalRulerConfig(
            minValue: range.lowerBound,
            maxValue: range.upperBound,
            minorIncrement: OnboardingTargetWeightValues.selectionStep(for: unitSystem),
            majorIncrement: 1.0,
            tickSpacing: OnboardingLayout.premiumRulerTickSpacing,
            indicatorColor: UIColor(OnboardingTheme.progress),
            hapticStyle: .none,
            tickSound: false,
            labelFormatter: OnboardingTargetWeightValues.targetWeightTickFormatter
        )
    }
}

// MARK: - UIViewRepresentable

private struct PremiumWeightRulerScrollViewRepresentable: UIViewRepresentable {
    @Binding var value: Double
    let config: HorizontalRulerConfig

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PremiumWeightRulerHostView {
        let host = PremiumWeightRulerHostView(config: config)
        host.ruler.onValueChanged = { [weak coordinator = context.coordinator] newValue in
            coordinator?.handleValueChange(newValue)
        }
        host.ruler.setValue(value, animated: false)
        return host
    }

    func updateUIView(_ host: PremiumWeightRulerHostView, context: Context) {
        context.coordinator.parent = self

        let isInteracting = host.ruler.isDragging || host.ruler.isDecelerating
        guard !isInteracting else { return }

        if abs(host.ruler.currentValue - value) > config.minorIncrement {
            host.ruler.setValue(value, animated: false)
        }
    }

    final class Coordinator {
        var parent: PremiumWeightRulerScrollViewRepresentable

        init(parent: PremiumWeightRulerScrollViewRepresentable) {
            self.parent = parent
        }

        private var lastEmittedValue: Double?

        func handleValueChange(_ newValue: Double) {
            if let lastEmittedValue, lastEmittedValue == newValue { return }
            lastEmittedValue = newValue
            parent.value = newValue
        }
    }
}

private final class PremiumWeightRulerHostView: UIView {
    let ruler: PremiumWeightRulerScrollView

    init(config: HorizontalRulerConfig) {
        ruler = PremiumWeightRulerScrollView(config: config)
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        addSubview(ruler)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ruler.frame = bounds
    }
}

#if DEBUG
#Preview("Premium Weight Ruler — Loss") {
    PremiumWeightRulerPreview.loss
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Premium Weight Ruler — Maintain") {
    PremiumWeightRulerPreview.maintain
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

private enum PremiumWeightRulerPreview {
    @MainActor
    static var loss: some View {
        previewRuler(formState: OnboardingPreviewData.targetWeightLossFormState)
    }

    @MainActor
    static var maintain: some View {
        previewRuler(formState: OnboardingPreviewData.targetWeightMaintainFormState)
    }

    @MainActor
    private static func previewRuler(formState: OnboardingFormState) -> some View {
        let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(from: formState)!
        return PremiumWeightRulerView(
            value: .constant(OnboardingTargetWeightValues.displayGoalValue(from: formState)),
            config: PremiumWeightRulerView.makeConfig(
                range: range,
                unitSystem: formState.unitSystem
            ),
            accessibilityLabel: "Target weight",
            accessibilityValue: OnboardingTargetWeightValues.targetWeightLabel(
                valueKg: formState.parsedGoalWeightKg ?? 0,
                unitSystem: formState.unitSystem
            )
        )
    }
}
#endif
