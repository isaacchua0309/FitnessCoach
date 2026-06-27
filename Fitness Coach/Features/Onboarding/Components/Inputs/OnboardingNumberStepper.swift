//
//  OnboardingNumberStepper.swift
//  Fitness Coach
//
//  Forma — Plus/minus stepper for tap-first numeric onboarding inputs.
//

import SwiftUI

struct OnboardingNumberStepper<Value: BinaryInteger>: View {
    var title: String?
    @Binding var value: Value
    let range: ClosedRange<Value>
    var step: Value = 1
    var unit: String?
    var fineTuneLabel: String?
    var onFineTune: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    private var displayText: String {
        guard let unit, !unit.isEmpty else { return "\(value)" }
        return "\(value) \(unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            if let title {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            HStack(spacing: FormaTokens.Spacing.sm) {
                stepButton(systemImage: "minus", action: decrement, isEnabled: canDecrement)

                Button {
                    onFineTune?()
                } label: {
                    Text(displayText)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(controlSize, FormaTokens.Layout.minTouchTarget))
                }
                .buttonStyle(.plain)
                .disabled(onFineTune == nil)
                .accessibilityLabel("Current value, \(displayText)")
                .accessibilityHint(onFineTune == nil ? "" : "Opens fine-tune picker")

                stepButton(systemImage: "plus", action: increment, isEnabled: canIncrement)
            }
            .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .fill(FormaTokens.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .stroke(OnboardingTheme.border, lineWidth: 1)
            )

            if let fineTuneLabel, onFineTune != nil {
                Button(action: { onFineTune?() }) {
                    Text(fineTuneLabel)
                        .font(FormaTokens.Typography.caption.weight(.medium))
                        .foregroundStyle(OnboardingTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(fineTuneLabel)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var canDecrement: Bool {
        value > range.lowerBound
    }

    private var canIncrement: Bool {
        value < range.upperBound
    }

    private func decrement() {
        guard canDecrement else { return }
        let next = value - step
        value = max(range.lowerBound, next)
    }

    private func increment() {
        guard canIncrement else { return }
        let next = value + step
        value = min(range.upperBound, next)
    }

    private func stepButton(
        systemImage: String,
        action: @escaping () -> Void,
        isEnabled: Bool
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isEnabled ? OnboardingTheme.accent : OnboardingTheme.tertiaryText)
                .frame(
                    width: max(controlSize, FormaTokens.Layout.minTouchTarget),
                    height: max(controlSize, FormaTokens.Layout.minTouchTarget)
                )
                .background(
                    Circle()
                        .fill(isEnabled ? FormaTokens.Color.accentMuted : FormaTokens.Color.surfaceSubtle)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(systemImage == "minus" ? "Decrease" : "Increase")
    }
}

#Preview("Training days") {
    OnboardingNumberStepper(
        title: "Training days per week",
        value: .constant(3),
        range: 0...7,
        unit: "days"
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("With fine tune") {
    OnboardingNumberStepper(
        title: "Age",
        value: .constant(28),
        range: 16...90,
        fineTuneLabel: "Pick exact age",
        onFineTune: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
