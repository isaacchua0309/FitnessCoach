//
//  OnboardingBodyStepView.swift
//  Fitness Coach
//
//  Forma — Body basics step for onboarding (picker-first, no required keyboard).
//

import SwiftUI

struct OnboardingBodyStepView: View {
    @Binding var formState: OnboardingFormState
    @State private var isBodyFatExpanded = false
    @State private var activeMetricPicker: BodyMetricPicker?
    @State private var usesCustomBodyFatEntry = false
    @FocusState private var isBodyFatCustomFocused: Bool

    private enum BodyMetricPicker: String, Identifiable {
        case age
        case height
        case weight

        var id: String { rawValue }
    }

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    private var bodyFatValidationMessage: String? {
        let message = formState.validationMessage(for: .body)
        guard message == FormaProductCopy.Onboarding.Validation.bodyFatRange else { return nil }
        return message
    }

    private var shouldShowBodyFatSection: Bool {
        isBodyFatExpanded
            || formState.bodyFatPreset != nil
            || bodyFatValidationMessage != nil
    }

    private var bodyFatChipSelection: Binding<OnboardingBodyFatPreset> {
        Binding(
            get: {
                if usesCustomBodyFatEntry {
                    return .custom
                }
                return formState.bodyFatPreset ?? .unknown
            },
            set: { preset in
                switch preset {
                case .custom:
                    usesCustomBodyFatEntry = true
                case .unknown:
                    usesCustomBodyFatEntry = false
                    formState.selectBodyFatPreset(.unknown)
                    isBodyFatCustomFocused = false
                case .fifteen, .twenty, .twentyFive, .thirty:
                    usesCustomBodyFatEntry = false
                    formState.selectBodyFatPreset(preset)
                    isBodyFatCustomFocused = false
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if !isV2, !OnboardingV3StepPolicy.isActive {
                legacyHeader
            }

            unitPicker
            measurementsGroup
            genderSection
            bodyFatSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            formState.applyBodyBasicsDefaultsIfNeeded()
            syncBodyFatExpansion()
            syncCustomBodyFatMode()
        }
        .onChange(of: formState.estimatedBodyFatPercentageText) { _, _ in
            syncBodyFatExpansion()
            syncCustomBodyFatMode()
        }
        .onChange(of: bodyFatValidationMessage) { _, _ in
            syncBodyFatExpansion()
        }
        .sheet(item: $activeMetricPicker) { picker in
            metricPickerSheet(for: picker)
        }
    }

    // MARK: - Legacy header

    private var legacyHeader: some View {
        OnboardingSectionTitle(
            title: FormaProductCopy.Onboarding.V2.Body.title,
            subtitle: FormaProductCopy.Onboarding.V2.Body.subtitle
        )
    }

    // MARK: - Units

    private var unitPicker: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V2.Body.unitSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            Picker(FormaProductCopy.Onboarding.V2.Body.unitSectionTitle, selection: $formState.unitSystem) {
                Text(FormaProductCopy.Onboarding.V2.Body.unitMetricLabel).tag(UnitSystem.metric)
                Text(FormaProductCopy.Onboarding.V2.Body.unitImperialLabel).tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(FormaProductCopy.Onboarding.V2.Body.unitSectionTitle)
        }
    }

    // MARK: - Core measurements

    private var measurementsGroup: some View {
        VStack(spacing: 0) {
            metricRow(
                label: "Age",
                value: "\(resolvedAge)",
                unit: "years",
                picker: .age
            )

            metricDivider

            metricRow(
                label: "Height",
                value: formattedHeightValue,
                unit: heightUnitLabel,
                picker: .height
            )

            metricDivider

            metricRow(
                label: "Current weight",
                value: formattedWeightValue,
                unit: weightUnitLabel,
                picker: .weight
            )
        }
        .onboardingCompactCard()
    }

    private var metricDivider: some View {
        Divider()
            .overlay(OnboardingTheme.border)
            .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
    }

    private func metricRow(
        label: String,
        value: String,
        unit: String?,
        picker: BodyMetricPicker
    ) -> some View {
        Button {
            activeMetricPicker = picker
        } label: {
            HStack(spacing: FormaTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(displayMetricText(value: value, unit: unit))
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .minimumScaleFactor(0.85)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
            .padding(.vertical, OnboardingLayout.compactFieldVerticalPadding)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(displayMetricText(value: value, unit: unit))")
        .accessibilityHint("Opens picker")
    }

    private func displayMetricText(value: String, unit: String?) -> String {
        guard let unit, !unit.isEmpty else { return value }
        return "\(value) \(unit)"
    }

    @ViewBuilder
    private func metricPickerSheet(for picker: BodyMetricPicker) -> some View {
        switch picker {
        case .age:
            OnboardingWheelPickerSheet(
                title: "Age",
                values: OnboardingPickerValueSequence.integers(in: OnboardingV3PickerDefaults.ageRange),
                selection: ageBinding,
                format: { "\($0)" },
                isPresented: sheetBinding(for: picker)
            )
        case .height:
            if formState.unitSystem == .metric {
                OnboardingWheelPickerSheet(
                    title: "Height",
                    values: OnboardingPickerValueSequence.decimals(
                        in: OnboardingV3PickerDefaults.metricHeightCmRange,
                        step: 1
                    ),
                    selection: heightCmBinding,
                    format: formatHeightCm,
                    isPresented: sheetBinding(for: picker)
                )
            } else {
                OnboardingWheelPickerSheet(
                    title: "Height",
                    values: OnboardingPickerValueSequence.decimals(
                        in: OnboardingV3PickerDefaults.imperialHeightInchesRange,
                        step: 1
                    ),
                    selection: heightInchesBinding,
                    format: formatHeightInches,
                    isPresented: sheetBinding(for: picker)
                )
            }
        case .weight:
            if formState.unitSystem == .metric {
                OnboardingWheelPickerSheet(
                    title: "Current weight",
                    values: OnboardingPickerValueSequence.decimals(
                        in: OnboardingV3PickerDefaults.metricWeightKgRange,
                        step: 0.5
                    ),
                    selection: weightKgBinding,
                    format: formatWeight,
                    isPresented: sheetBinding(for: picker)
                )
            } else {
                OnboardingWheelPickerSheet(
                    title: "Current weight",
                    values: OnboardingPickerValueSequence.decimals(
                        in: OnboardingV3PickerDefaults.imperialWeightLbRange,
                        step: 1
                    ),
                    selection: weightLbBinding,
                    format: formatWeight,
                    isPresented: sheetBinding(for: picker)
                )
            }
        }
    }

    private func sheetBinding(for picker: BodyMetricPicker) -> Binding<Bool> {
        Binding(
            get: { activeMetricPicker == picker },
            set: { isPresented in
                if !isPresented, activeMetricPicker == picker {
                    activeMetricPicker = nil
                }
            }
        )
    }

    // MARK: - Gender

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V2.Body.genderLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            OnboardingSexPillGrid(selection: $formState.sex)
        }
    }

    // MARK: - Optional body fat

    private var bodyFatSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactFieldSpacing) {
            if shouldShowBodyFatSection {
                VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
                    Text(FormaProductCopy.Onboarding.V2.Body.bodyFatLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)

                    OnboardingPillGrid(
                        items: OnboardingBodyFatPreset.allCases,
                        selection: bodyFatChipSelection,
                        titleForItem: \.title,
                        columnCount: 3,
                        accessibilityGroupLabel: FormaProductCopy.Onboarding.V2.Body.bodyFatLabel
                    )

                    if bodyFatChipSelection.wrappedValue == .custom {
                        OnboardingTextField(
                            title: "Custom percentage",
                            placeholder: "e.g. 24",
                            text: $formState.estimatedBodyFatPercentageText,
                            helper: FormaProductCopy.Onboarding.V2.Body.bodyFatHelper,
                            statusLabel: FormaProductCopy.Onboarding.V2.Body.bodyFatOptionalLabel,
                            trailingUnit: FormaProductCopy.Onboarding.V2.Body.bodyFatUnit,
                            keyboard: .decimalPad,
                            isFocused: isBodyFatCustomFocused
                        )
                        .focused($isBodyFatCustomFocused)
                        .onboardingScrollTarget(id: "body-custom-bodyfat", isFocused: isBodyFatCustomFocused)
                    }

                    if let bodyFatValidationMessage {
                        Text(bodyFatValidationMessage)
                            .font(.caption)
                            .foregroundStyle(OnboardingTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isBodyFatExpanded = true
                    }
                } label: {
                    HStack(spacing: OnboardingLayout.compactLabelGap) {
                        Image(systemName: "plus.circle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.accent)

                        Text(FormaProductCopy.Onboarding.V2.Body.bodyFatDisclosureLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: OnboardingLayout.selectionRowMinHeight, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FormaProductCopy.Onboarding.V2.Body.bodyFatDisclosureLabel)
            }
        }
    }

    // MARK: - Bindings & formatting

    private var resolvedAge: Int {
        ageBinding.wrappedValue
    }

    private var ageBinding: Binding<Int> {
        Binding(
            get: {
                let trimmed = formState.ageText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let age = Int(trimmed), age > 0 {
                    return age
                }
                return OnboardingV3PickerDefaults.defaultAge
            },
            set: { formState.ageText = String($0) }
        )
    }

    private var heightCmBinding: Binding<Double> {
        Binding(
            get: {
                let trimmed = formState.heightCmText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let cm = Double(trimmed), cm > 0 {
                    return cm
                }
                return OnboardingV3PickerDefaults.defaultHeightCm
            },
            set: { formState.heightCmText = Self.formatStoredMetric($0) }
        )
    }

    private var heightInchesBinding: Binding<Double> {
        Binding(
            get: {
                let cm = heightCmBinding.wrappedValue
                return (cm / OnboardingFormState.centimetersPerInch).rounded()
            },
            set: { inches in
                let cm = inches * OnboardingFormState.centimetersPerInch
                formState.heightCmText = Self.formatStoredMetric(cm)
            }
        )
    }

    private var weightKgBinding: Binding<Double> {
        Binding(
            get: {
                let trimmed = formState.currentWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let kg = Double(trimmed), kg > 0 {
                    return kg
                }
                return OnboardingV3PickerDefaults.defaultWeightKg
            },
            set: { formState.currentWeightKgText = Self.formatStoredMetric($0) }
        )
    }

    private var weightLbBinding: Binding<Double> {
        Binding(
            get: {
                let kg = weightKgBinding.wrappedValue
                return (kg * OnboardingFormState.poundsPerKilogram).rounded()
            },
            set: { pounds in
                let kg = pounds / OnboardingFormState.poundsPerKilogram
                formState.currentWeightKgText = Self.formatStoredMetric(kg)
            }
        )
    }

    private var formattedHeightValue: String {
        if formState.unitSystem == .metric {
            return formatHeightCm(heightCmBinding.wrappedValue)
        }
        return formatHeightInches(heightInchesBinding.wrappedValue)
    }

    private var heightUnitLabel: String? {
        formState.unitSystem == .metric ? "cm" : nil
    }

    private var formattedWeightValue: String {
        formatWeight(
            formState.unitSystem == .metric
                ? weightKgBinding.wrappedValue
                : weightLbBinding.wrappedValue
        )
    }

    private var weightUnitLabel: String? {
        formState.unitSystem == .metric ? "kg" : "lb"
    }

    private func formatHeightCm(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private func formatHeightInches(_ inches: Double) -> String {
        let total = Int(inches.rounded())
        let feet = total / 12
        let remainder = total % 12
        return "\(feet)′ \(remainder)″"
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private static func formatStoredMetric(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 0.1) == 0 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }

    private func syncBodyFatExpansion() {
        if shouldShowBodyFatSection {
            isBodyFatExpanded = true
        }
    }

    private func syncCustomBodyFatMode() {
        if let preset = formState.bodyFatPreset, preset == .custom {
            usesCustomBodyFatEntry = true
        } else if formState.estimatedBodyFatPercentageText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty {
            usesCustomBodyFatEntry = false
        }
    }
}

// MARK: - Previews

#Preview("Empty defaults") {
    OnboardingBodyStepView(formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Valid metric") {
    OnboardingBodyStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Valid imperial") {
    OnboardingBodyStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.unitSystem = .imperial
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Body fat preset") {
    OnboardingBodyStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.estimatedBodyFatPercentageText = "20"
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Body fat custom valid") {
    OnboardingBodyStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.estimatedBodyFatPercentageText = "24"
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Body fat invalid") {
    OnboardingBodyStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.estimatedBodyFatPercentageText = "71"
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

