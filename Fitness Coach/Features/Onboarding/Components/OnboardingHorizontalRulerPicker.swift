//
//  OnboardingHorizontalRulerPicker.swift
//  Fitness Coach
//
//  Forma — Scrollable horizontal ruler for metric selection.
//

import SwiftUI

struct OnboardingRulerConfiguration: Equatable, Sendable {
    let values: [Double]
    let unitLabel: String
    let tickSpacing: CGFloat
    let majorTickEvery: Int

    init(
        range: ClosedRange<Double>,
        step: Double,
        unitLabel: String,
        tickSpacing: CGFloat = 12,
        majorTickEvery: Int = 5
    ) {
        values = OnboardingRulerMath.buildValues(in: range, step: step)
        self.unitLabel = unitLabel
        self.tickSpacing = tickSpacing
        self.majorTickEvery = max(1, majorTickEvery)
    }

    init(
        values: [Double],
        unitLabel: String,
        tickSpacing: CGFloat = 12,
        majorTickEvery: Int = 5
    ) {
        self.values = values
        self.unitLabel = unitLabel
        self.tickSpacing = tickSpacing
        self.majorTickEvery = max(1, majorTickEvery)
    }
}

enum OnboardingRulerPresentation: Equatable {
    case standard
    case hero
}

struct OnboardingHorizontalRulerPicker: View {
    let configuration: OnboardingRulerConfiguration
    @Binding var value: Double
    let formatValue: (Double) -> String
    var presentation: OnboardingRulerPresentation = .standard
    var centerDisplayText: String?
    var accessibilityValueText: String?

    @State private var selectedIndex: Int = 0
    @State private var suppressSelectionHaptics = true

    @ScaledMetric(relativeTo: .body) private var standardIndicatorHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .title) private var heroIndicatorHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .caption) private var standardTickLabelSize: CGFloat = 9
    @ScaledMetric(relativeTo: .body) private var heroTickLabelSize: CGFloat = 11

    init(
        configuration: OnboardingRulerConfiguration,
        value: Binding<Double>,
        formatValue: @escaping (Double) -> String = OnboardingHorizontalRulerPicker.defaultFormatter,
        presentation: OnboardingRulerPresentation = .standard,
        centerDisplayText: String? = nil,
        accessibilityValueText: String? = nil
    ) {
        self.configuration = configuration
        _value = value
        self.formatValue = formatValue
        self.presentation = presentation
        self.centerDisplayText = centerDisplayText
        self.accessibilityValueText = accessibilityValueText
        let initialIndex = OnboardingRulerMath.index(for: value.wrappedValue, in: configuration.values) ?? 0
        _selectedIndex = State(initialValue: initialIndex)
    }

    private var isHero: Bool { presentation == .hero }
    private var rulerHeight: CGFloat { isHero ? OnboardingLayout.heroRulerHeight : 88 }
    private var indicatorHeight: CGFloat { isHero ? heroIndicatorHeight : standardIndicatorHeight }

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            if !isHero {
                selectedValueLabel
            }

            ZStack {
                RoundedRectangle(cornerRadius: isHero ? FormaTokens.Radius.card : OnboardingTheme.compactCornerRadius, style: .continuous)
                    .fill(FormaTokens.Color.surfaceSubtle)
                    .overlay {
                        if !isHero {
                            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                                .stroke(OnboardingTheme.border.opacity(0.55), lineWidth: 1)
                        }
                    }

                rulerScrollView

                if isHero {
                    heroCenterValue
                }

                centerIndicator
            }
            .frame(height: rulerHeight)
        }
        .onAppear {
            syncIndexFromValue()
            DispatchQueue.main.async {
                suppressSelectionHaptics = false
            }
        }
        .onChange(of: value) { _, _ in
            syncIndexFromValue()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FormaProductCopy.Onboarding.Flow.Components.rulerAccessibilityLabel)
        .accessibilityValue(accessibilityValueLabel)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                stepSelection(by: 1)
            case .decrement:
                stepSelection(by: -1)
            @unknown default:
                break
            }
        }
    }

    private var selectedValueLabel: some View {
        Text(displayLabel)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(OnboardingTheme.primaryText)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var heroCenterValue: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            Text(displayLabel)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.82)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.18), value: displayLabel)
                .accessibilityHidden(true)

            Capsule()
                .fill(OnboardingTheme.accent)
                .frame(width: 2, height: indicatorHeight * 0.55)
                .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }

    private var displayLabel: String {
        if let centerDisplayText {
            return centerDisplayText
        }
        return OnboardingRulerMath.accessibilityValueLabel(
            value: value,
            unitLabel: configuration.unitLabel,
            formatter: formatValue
        )
    }

    private var accessibilityValueLabel: String {
        if let accessibilityValueText {
            return accessibilityValueText
        }
        return displayLabel
    }

    private var rulerScrollView: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(configuration.values.indices, id: \.self) { index in
                        tickView(for: index)
                            .frame(width: configuration.tickSpacing)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, rulerHorizontalPadding(in: proxy.size.width))
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding(
                get: { selectedIndex as Int? },
                set: { newIndex in
                    guard let newIndex else { return }
                    applyIndex(newIndex)
                }
            ))
            .accessibilityHidden(true)
        }
        .padding(.top, isHero ? 44 : 0)
    }

    private func rulerHorizontalPadding(in width: CGFloat) -> CGFloat {
        max(width / 2, configuration.tickSpacing)
    }

    private var centerIndicator: some View {
        Group {
            if !isHero {
                Rectangle()
                    .fill(OnboardingTheme.accent)
                    .frame(width: 2, height: indicatorHeight)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tickView(for index: Int) -> some View {
        let isMajor = index % configuration.majorTickEvery == 0
        let majorHeight: CGFloat = isHero ? 30 : 22
        let minorHeight: CGFloat = isHero ? 16 : 12
        let labelSize = isHero ? heroTickLabelSize : standardTickLabelSize

        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(isMajor ? OnboardingTheme.secondaryText : OnboardingTheme.border)
                .frame(width: isMajor ? 1.5 : 1, height: isMajor ? majorHeight : minorHeight)
            if isMajor, let tickValue = configuration.values[safe: index] {
                Text(formatValue(tickValue))
                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Color.clear.frame(height: isHero ? 14 : 12)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func syncIndexFromValue() {
        let snapped = OnboardingRulerMath.snapValue(value, in: configuration.values)
        if snapped != value {
            value = snapped
        }
        if let index = OnboardingRulerMath.index(for: snapped, in: configuration.values) {
            selectedIndex = index
        }
    }

    private func applyIndex(_ index: Int) {
        let clamped = OnboardingRulerMath.clampedIndex(index, count: configuration.values.count)
        let previous = value
        selectedIndex = clamped
        if let updated = OnboardingRulerMath.value(at: clamped, in: configuration.values) {
            value = updated
            if updated != previous, !suppressSelectionHaptics {
                OnboardingHaptics.selectionChanged()
            }
        }
    }

    private func stepSelection(by delta: Int) {
        applyIndex(selectedIndex + delta)
    }

    static func defaultFormatter(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Unit presets

enum OnboardingRulerPickerFactory {

    static func weightDeltaKg(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        presentation: OnboardingRulerPresentation = .standard,
        centerDisplayText: String? = nil,
        accessibilityValueText: String? = nil
    ) -> OnboardingHorizontalRulerPicker {
        OnboardingHorizontalRulerPicker(
            configuration: rulerConfiguration(
                range: range,
                step: OnboardingTargetWeightValues.rulerStepKg,
                unitSystem: .metric,
                presentation: presentation
            ),
            value: value,
            presentation: presentation,
            centerDisplayText: centerDisplayText,
            accessibilityValueText: accessibilityValueText
        )
    }

    static func weightDeltaLb(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        presentation: OnboardingRulerPresentation = .standard,
        centerDisplayText: String? = nil,
        accessibilityValueText: String? = nil
    ) -> OnboardingHorizontalRulerPicker {
        OnboardingHorizontalRulerPicker(
            configuration: rulerConfiguration(
                range: range,
                step: OnboardingTargetWeightValues.rulerStepLb,
                unitSystem: .imperial,
                presentation: presentation
            ),
            value: value,
            presentation: presentation,
            centerDisplayText: centerDisplayText,
            accessibilityValueText: accessibilityValueText
        )
    }

    static func weightLossKg(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        presentation: OnboardingRulerPresentation = .standard,
        centerDisplayText: String? = nil,
        accessibilityValueText: String? = nil
    ) -> OnboardingHorizontalRulerPicker {
        OnboardingHorizontalRulerPicker(
            configuration: rulerConfiguration(
                range: range,
                step: OnboardingGoalWeightBounds.metricStepKg,
                unitSystem: .metric,
                presentation: presentation
            ),
            value: value,
            presentation: presentation,
            centerDisplayText: centerDisplayText,
            accessibilityValueText: accessibilityValueText
        )
    }

    static func weightLossLb(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        presentation: OnboardingRulerPresentation = .standard,
        centerDisplayText: String? = nil,
        accessibilityValueText: String? = nil
    ) -> OnboardingHorizontalRulerPicker {
        OnboardingHorizontalRulerPicker(
            configuration: rulerConfiguration(
                range: range,
                step: OnboardingGoalWeightBounds.imperialStepLb,
                unitSystem: .imperial,
                presentation: presentation
            ),
            value: value,
            presentation: presentation,
            centerDisplayText: centerDisplayText,
            accessibilityValueText: accessibilityValueText
        )
    }

    static func weightKg(
        value: Binding<Double>,
        range: ClosedRange<Double> = OnboardingPickerDefaults.metricWeightKgRange
    ) -> OnboardingHorizontalRulerPicker {
        OnboardingHorizontalRulerPicker(
            configuration: .init(
                range: range,
                step: 0.5,
                unitLabel: OnboardingFormatter.weightUnitAbbreviation(for: .metric)
            ),
            value: value
        )
    }

    static func weightLb(
        value: Binding<Double>,
        range: ClosedRange<Double> = OnboardingPickerDefaults.imperialWeightLbRange
    ) -> OnboardingHorizontalRulerPicker {
        OnboardingHorizontalRulerPicker(
            configuration: .init(
                range: range,
                step: 1,
                unitLabel: OnboardingFormatter.weightUnitAbbreviation(for: .imperial)
            ),
            value: value
        )
    }

    private static func rulerConfiguration(
        range: ClosedRange<Double>,
        step: Double,
        unitSystem: UnitSystem,
        presentation: OnboardingRulerPresentation
    ) -> OnboardingRulerConfiguration {
        let tickSpacing = presentation == .hero
            ? OnboardingLayout.heroRulerTickSpacing
            : 12
        return OnboardingRulerConfiguration(
            range: range,
            step: step,
            unitLabel: OnboardingFormatter.weightUnitAbbreviation(for: unitSystem),
            tickSpacing: tickSpacing,
            majorTickEvery: presentation == .hero ? 4 : 5
        )
    }
}
