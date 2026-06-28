//
//  OnboardingV4HorizontalRulerPicker.swift
//  Fitness Coach
//
//  Forma — Scrollable horizontal ruler for v4 metric selection.
//

import SwiftUI

struct OnboardingV4RulerConfiguration: Equatable, Sendable {
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
        values = OnboardingV4RulerMath.buildValues(in: range, step: step)
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

struct OnboardingV4HorizontalRulerPicker: View {
    let configuration: OnboardingV4RulerConfiguration
    @Binding var value: Double
    let formatValue: (Double) -> String
    var centerDisplayText: String?
    var accessibilityValueText: String?

    @State private var selectedIndex: Int = 0

    private let indicatorHeight: CGFloat = 36

    init(
        configuration: OnboardingV4RulerConfiguration,
        value: Binding<Double>,
        formatValue: @escaping (Double) -> String = OnboardingV4HorizontalRulerPicker.defaultFormatter,
        centerDisplayText: String? = nil,
        accessibilityValueText: String? = nil
    ) {
        self.configuration = configuration
        _value = value
        self.formatValue = formatValue
        self.centerDisplayText = centerDisplayText
        self.accessibilityValueText = accessibilityValueText
        let initialIndex = OnboardingV4RulerMath.index(for: value.wrappedValue, in: configuration.values) ?? 0
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            selectedValueLabel

            ZStack {
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .fill(FormaTokens.Color.surfaceSubtle)
                    .overlay {
                        RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                            .stroke(OnboardingTheme.border.opacity(0.55), lineWidth: 1)
                    }

                rulerScrollView

                centerIndicator
            }
            .frame(height: 88)
        }
        .onAppear {
            syncIndexFromValue()
        }
        .onChange(of: value) { _, _ in
            syncIndexFromValue()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FormaProductCopy.Onboarding.V4.Components.rulerAccessibilityLabel)
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

    private var displayLabel: String {
        if let centerDisplayText {
            return centerDisplayText
        }
        return OnboardingV4RulerMath.accessibilityValueLabel(
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
    }

    private func rulerHorizontalPadding(in width: CGFloat) -> CGFloat {
        max(width / 2, configuration.tickSpacing)
    }

    private var centerIndicator: some View {
        Rectangle()
            .fill(OnboardingTheme.accent)
            .frame(width: 2, height: indicatorHeight)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tickView(for index: Int) -> some View {
        let isMajor = index % configuration.majorTickEvery == 0
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(isMajor ? OnboardingTheme.secondaryText : OnboardingTheme.border)
                .frame(width: 1, height: isMajor ? 22 : 12)
            if isMajor, let tickValue = configuration.values[safe: index] {
                Text(formatValue(tickValue))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Color.clear.frame(height: 12)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func syncIndexFromValue() {
        let snapped = OnboardingV4RulerMath.snapValue(value, in: configuration.values)
        if snapped != value {
            value = snapped
        }
        if let index = OnboardingV4RulerMath.index(for: snapped, in: configuration.values) {
            selectedIndex = index
        }
    }

    private func applyIndex(_ index: Int) {
        let clamped = OnboardingV4RulerMath.clampedIndex(index, count: configuration.values.count)
        selectedIndex = clamped
        if let updated = OnboardingV4RulerMath.value(at: clamped, in: configuration.values) {
            value = updated
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

enum OnboardingV4RulerPickerFactory {

    static func weightLossKg(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        centerDisplayText: String? = nil,
        accessibilityValueText: String? = nil
    ) -> OnboardingV4HorizontalRulerPicker {
        OnboardingV4HorizontalRulerPicker(
            configuration: .init(
                range: range,
                step: OnboardingGoalWeightBounds.metricStepKg,
                unitLabel: OnboardingFormatter.weightUnitAbbreviation(for: .metric)
            ),
            value: value,
            centerDisplayText: centerDisplayText,
            accessibilityValueText: accessibilityValueText
        )
    }

    static func weightLossLb(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        centerDisplayText: String? = nil,
        accessibilityValueText: String? = nil
    ) -> OnboardingV4HorizontalRulerPicker {
        OnboardingV4HorizontalRulerPicker(
            configuration: .init(
                range: range,
                step: OnboardingGoalWeightBounds.imperialStepLb,
                unitLabel: OnboardingFormatter.weightUnitAbbreviation(for: .imperial)
            ),
            value: value,
            centerDisplayText: centerDisplayText,
            accessibilityValueText: accessibilityValueText
        )
    }

    static func weightKg(
        value: Binding<Double>,
        range: ClosedRange<Double> = OnboardingV3PickerDefaults.metricWeightKgRange
    ) -> OnboardingV4HorizontalRulerPicker {
        OnboardingV4HorizontalRulerPicker(
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
        range: ClosedRange<Double> = OnboardingV3PickerDefaults.imperialWeightLbRange
    ) -> OnboardingV4HorizontalRulerPicker {
        OnboardingV4HorizontalRulerPicker(
            configuration: .init(
                range: range,
                step: 1,
                unitLabel: OnboardingFormatter.weightUnitAbbreviation(for: .imperial)
            ),
            value: value
        )
    }
}
