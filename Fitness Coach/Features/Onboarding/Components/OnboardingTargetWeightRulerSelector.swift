//
//  OnboardingTargetWeightRulerSelector.swift
//  Fitness Coach
//
//  Forma — Target-weight horizontal ruler (SwiftHorizontalRuler adapter).
//

import SwiftHorizontalRuler
import SwiftUI
import UIKit

/// Absolute target-weight ruler for onboarding. Persists canonical kg via `OnboardingFormState`.
struct OnboardingTargetWeightRulerSelector: View {
    @Binding var formState: OnboardingFormState

    private let copy = FormaProductCopy.Onboarding.Flow.TargetWeight.self

    @State private var lastHapticDisplayValue: Double?

    var body: some View {
        if let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(from: formState),
           formState.parsedCurrentWeightKg != nil {
            FormaThemedHorizontalRuler(
                value: displayBinding,
                config: rulerConfig(for: range)
            )
            .frame(height: OnboardingLayout.heroRulerHeight)
            .frame(maxWidth: .infinity)
            .background(OnboardingTheme.surfaceSubtle)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(copy.rulerAccessibilityLabel)
            .accessibilityValue(accessibilityAnnouncement)
            .accessibilityHint(copy.interactionHint)
            .id(OnboardingTargetWeightValues.selectorIdentity(for: formState))
            .onAppear {
                lastHapticDisplayValue = OnboardingTargetWeightValues.displayGoalValue(from: formState)
            }
            .onChange(of: displayValue) { previous, next in
                guard lastHapticDisplayValue != nil else {
                    lastHapticDisplayValue = next
                    return
                }
                guard previous != next else { return }
                OnboardingHaptics.selectionChanged()
                lastHapticDisplayValue = next
            }
        }
    }

    // MARK: - Binding (display units → canonical kg)

    private var displayValue: Double {
        OnboardingTargetWeightValues.displayGoalValue(from: formState)
    }

    private var displayBinding: Binding<Double> {
        Binding(
            get: { displayValue },
            set: { newDisplay in
                OnboardingTargetWeightValues.setGoalFromDisplay(newDisplay, in: &formState)
            }
        )
    }

    // MARK: - SwiftHorizontalRuler config

    private func rulerConfig(for range: ClosedRange<Double>) -> HorizontalRulerConfig {
        let unitSystem = formState.unitSystem
        let minorStep = OnboardingTargetWeightValues.selectionStep(for: unitSystem)
        let majorStep = majorIncrement(for: unitSystem)

        return HorizontalRulerConfig(
            minValue: range.lowerBound,
            maxValue: range.upperBound,
            minorIncrement: minorStep,
            majorIncrement: majorStep,
            tickSpacing: OnboardingLayout.heroRulerTickSpacing,
            indicatorColor: OnboardingTargetWeightRulerUIKitBridge.indicatorColor,
            hapticStyle: .none,
            tickSound: false,
            labelFormatter: OnboardingTargetWeightValues.targetWeightTickFormatter
        )
    }

    private func majorIncrement(for unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric:
            return 1.0
        case .imperial:
            return 1.0
        }
    }

    // MARK: - Accessibility

    private var accessibilityAnnouncement: String {
        guard let goalKg = OnboardingTargetWeightValues.resolvedGoalKg(from: formState) else {
            return copy.rulerAccessibilityLabel
        }

        let targetLabel = OnboardingTargetWeightValues.targetWeightLabel(
            valueKg: goalKg,
            unitSystem: formState.unitSystem
        )
        let journey = OnboardingTargetWeightValues.currentToTargetSummary(for: formState)
        let delta = OnboardingTargetWeightValues.differenceLabel(for: formState)

        return [targetLabel, journey, delta]
            .compactMap { $0 }
            .joined(separator: ". ")
    }
}

// MARK: - Themed UIViewRepresentable

/// Wraps `HorizontalRulerScrollView` and reapplies Forma semantic colors whenever
/// layout, traits, or palette change. SwiftHorizontalRuler only exposes indicator color
/// in its config; tick, label, and background colors are bridged here.
private struct FormaThemedHorizontalRuler: UIViewRepresentable {
    @Binding var value: Double
    let config: HorizontalRulerConfig

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> FormaThemedHorizontalRulerHostView {
        let host = FormaThemedHorizontalRulerHostView(config: config)
        host.ruler.onValueChanged = { [weak coordinator = context.coordinator] newValue in
            coordinator?.handleValueChange(newValue)
        }
        host.ruler.setValue(value, animated: false)
        host.applyFormaTheme()
        return host
    }

    func updateUIView(_ host: FormaThemedHorizontalRulerHostView, context: Context) {
        context.coordinator.parent = self
        host.applyFormaTheme()

        guard !host.ruler.isDragging, !host.ruler.isDecelerating else { return }
        if abs(host.ruler.currentValue - value) > config.minorIncrement {
            host.ruler.setValue(value, animated: false)
        }
    }

    final class Coordinator {
        var parent: FormaThemedHorizontalRuler
        private var lastHapticValue: Double

        init(parent: FormaThemedHorizontalRuler) {
            self.parent = parent
            self.lastHapticValue = parent.value
        }

        func handleValueChange(_ newValue: Double) {
            parent.value = newValue
        }
    }
}

/// Hosts the package scroll view and re-applies Forma colors after UIKit trait updates.
private final class FormaThemedHorizontalRulerHostView: UIView {
    let ruler: HorizontalRulerScrollView

    init(config: HorizontalRulerConfig) {
        ruler = HorizontalRulerScrollView(config: config)
        super.init(frame: .zero)
        backgroundColor = .clear
        addSubview(ruler)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ruler.frame = bounds
        applyFormaTheme()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyFormaTheme()
    }

    func applyFormaTheme() {
        OnboardingTargetWeightRulerUIKitBridge.apply(to: ruler)
    }
}

// MARK: - UIKit bridge

/// Bridges Forma semantic SwiftUI tokens to `UIColor` for SwiftHorizontalRuler surfaces.
private enum OnboardingTargetWeightRulerUIKitBridge {
    @MainActor
    static var indicatorColor: UIColor {
        uiColor(OnboardingTheme.progress)
    }

    @MainActor
    private static var minorTickColor: UIColor {
        uiColor(OnboardingTheme.border).withAlphaComponent(0.35)
    }

    @MainActor
    private static var majorTickColor: UIColor {
        uiColor(OnboardingTheme.secondaryText)
    }

    @MainActor
    private static var labelColor: UIColor {
        uiColor(OnboardingTheme.tertiaryText)
    }

    @MainActor
    private static var backgroundColor: UIColor {
        uiColor(OnboardingTheme.surfaceSubtle)
    }

    @MainActor
    static func apply(to ruler: HorizontalRulerScrollView) {
        ruler.backgroundColor = backgroundColor

        for subview in ruler.subviews {
            subview.backgroundColor = backgroundColor
        }

        applyIndicatorTheme(to: ruler)
        applyTickAndLabelTheme(to: ruler)
    }

    @MainActor
    private static func uiColor(_ color: Color) -> UIColor {
        UIColor(color)
    }

    @MainActor
    private static func applyIndicatorTheme(to ruler: HorizontalRulerScrollView) {
        let indicator = indicatorColor.cgColor
        for layer in ruler.layer.sublayers ?? [] {
            if let shape = layer as? CAShapeLayer {
                shape.fillColor = indicator
            } else {
                layer.backgroundColor = indicator
            }
        }
    }

    @MainActor
    private static func applyTickAndLabelTheme(to ruler: HorizontalRulerScrollView) {
        guard let scrollView = ruler.subviews.first,
              let contentView = scrollView.subviews.first else {
            return
        }

        let tickLayers = (contentView.layer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }
        if tickLayers.indices.contains(0) {
            tickLayers[0].strokeColor = minorTickColor.cgColor
        }
        if tickLayers.indices.contains(1) {
            tickLayers[1].strokeColor = majorTickColor.cgColor
        }

        for layer in contentView.layer.sublayers ?? [] {
            guard let textLayer = layer as? CATextLayer else { continue }
            textLayer.foregroundColor = labelColor.cgColor
        }
    }
}
