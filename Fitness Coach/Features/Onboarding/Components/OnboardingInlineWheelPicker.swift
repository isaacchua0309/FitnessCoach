//
//  OnboardingInlineWheelPicker.swift
//  Fitness Coach
//
//  Forma — Inline wheel picker for onboarding (single or side-by-side columns).
//

import SwiftUI

struct OnboardingInlineWheelPicker<Value: Hashable>: View {
    let columns: [OnboardingWheelColumn<Value>]
    @Binding var selections: [String: Value]
    var wheelHeight: CGFloat = OnboardingLayout.measurementWheelHeight
    var showsCardChrome: Bool = true
    var verticalPadding: CGFloat = FormaTokens.Spacing.sm
    var wheelItemFont: Font = FormaTokens.Typography.body

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(columns) { column in
                columnPicker(column)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, verticalPadding)
        .modifier(OnboardingWheelCardChrome(enabled: showsCardChrome))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FormaProductCopy.Onboarding.Flow.Components.wheelPickerAccessibilityLabel)
    }

    @ViewBuilder
    private func columnPicker(_ column: OnboardingWheelColumn<Value>) -> some View {
        if column.values.isEmpty {
            Text(FormaProductCopy.Error.checkInputs)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: wheelHeight)
        } else {
            Picker(column.accessibilityLabel, selection: binding(for: column)) {
                ForEach(column.values, id: \.self) { value in
                    Text(column.format(value))
                        .font(wheelItemFont)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: wheelHeight)
            .clipped()
            .accessibilityLabel(column.accessibilityLabel)
        }
    }

    private func binding(for column: OnboardingWheelColumn<Value>) -> Binding<Value> {
        Binding(
            get: {
                if let selected = selections[column.id], column.values.contains(selected) {
                    return selected
                }
                return column.values[0]
            },
            set: { selections[column.id] = $0 }
        )
    }
}

// MARK: - Birthday convenience

struct OnboardingBirthdayWheelPicker: View {
    @Binding var birthDate: Date?
    var wheelHeight: CGFloat = OnboardingLayout.birthdayWheelHeight
    var showsCardChrome: Bool = true
    var wheelItemFont: Font = .system(.title3, design: .rounded).weight(.medium)

    @State private var month: Int
    @State private var day: Int
    @State private var year: Int
    @State private var suppressSelectionHaptics = true

    private let calendar: Calendar

    init(
        birthDate: Binding<Date?>,
        wheelHeight: CGFloat = OnboardingLayout.birthdayWheelHeight,
        showsCardChrome: Bool = true,
        wheelItemFont: Font = .system(.title3, design: .rounded).weight(.medium),
        calendar: Calendar = .current
    ) {
        _birthDate = birthDate
        self.wheelHeight = wheelHeight
        self.showsCardChrome = showsCardChrome
        self.wheelItemFont = wheelItemFont
        self.calendar = calendar

        let reference = birthDate.wrappedValue ?? BirthDateAgeResolver.syntheticBirthDate(
            fromAge: OnboardingPickerDefaults.defaultAge,
            referenceDate: Date(),
            calendar: calendar
        )
        _month = State(initialValue: calendar.component(.month, from: reference))
        _day = State(initialValue: calendar.component(.day, from: reference))
        _year = State(initialValue: calendar.component(.year, from: reference))
    }

    var body: some View {
        let columns = OnboardingBirthdayWheelFactory.columns(calendar: calendar)

        OnboardingInlineWheelPicker(
            columns: [columns.month, columns.day, columns.year],
            selections: Binding(
                get: {
                    [
                        columns.month.id: month,
                        columns.day.id: day,
                        columns.year.id: year
                    ]
                },
                set: { newValues in
                    if let newMonth = newValues[columns.month.id] { month = newMonth }
                    if let newDay = newValues[columns.day.id] { day = newDay }
                    if let newYear = newValues[columns.year.id] { year = newYear }
                    syncBirthDate()
                }
            ),
            wheelHeight: wheelHeight,
            showsCardChrome: showsCardChrome,
            verticalPadding: OnboardingLayout.birthdayWheelVerticalPadding,
            wheelItemFont: wheelItemFont
        )
        .onAppear {
            syncBirthDate()
            DispatchQueue.main.async {
                suppressSelectionHaptics = false
            }
        }
        .onChange(of: birthDate) { _, _ in
            guard !suppressSelectionHaptics else { return }
            OnboardingHaptics.selectionChanged()
        }
    }

    private func syncBirthDate() {
        birthDate = OnboardingBirthdayWheelFactory.birthDate(
            month: month,
            day: day,
            year: year,
            calendar: calendar
        )
    }
}

// MARK: - Height / weight presets

enum OnboardingHeightWeightWheelPicker {

    @ViewBuilder
    static func metric(formState: Binding<OnboardingFormState>) -> some View {
        pairedMeasurementCard {
            labeledColumn(title: FormaProductCopy.Onboarding.Flow.HeightWeight.heightLabel) {
                OnboardingMetricWheelPicker.heightCm(
                    selection: heightCmBinding(formState),
                    showsCardChrome: false
                )
            }

            labeledColumn(title: FormaProductCopy.Onboarding.Flow.HeightWeight.weightLabel) {
                OnboardingMetricWheelPicker.weightKg(
                    selection: weightKgBinding(formState),
                    showsCardChrome: false
                )
            }
        }
    }

    @ViewBuilder
    static func imperial(formState: Binding<OnboardingFormState>) -> some View {
        pairedMeasurementCard {
            labeledColumn(title: FormaProductCopy.Onboarding.Flow.HeightWeight.heightLabel) {
                OnboardingInlineWheelPicker(
                    columns: [
                        OnboardingWheelColumn(
                            id: "feet",
                            accessibilityLabel: FormaProductCopy.Onboarding.Flow.HeightWeight.feetLabel,
                            values: Array(OnboardingHeightWeightValues.imperialFeetRange),
                            format: { "\($0) ft" }
                        ),
                        OnboardingWheelColumn(
                            id: "inches",
                            accessibilityLabel: FormaProductCopy.Onboarding.Flow.HeightWeight.inchesLabel,
                            values: Array(OnboardingHeightWeightValues.imperialInchesRange),
                            format: { "\($0) in" }
                        )
                    ],
                    selections: imperialHeightSelectionsBinding(formState),
                    showsCardChrome: false
                )
            }

            labeledColumn(title: FormaProductCopy.Onboarding.Flow.HeightWeight.weightLabel) {
                OnboardingImperialWheelPicker.weightLb(
                    selection: weightLbBinding(formState),
                    showsCardChrome: false
                )
            }
        }
    }

    static func heightCmBinding(_ formState: Binding<OnboardingFormState>) -> Binding<Double> {
        Binding(
            get: { OnboardingHeightWeightValues.resolvedHeightCm(from: formState.wrappedValue) },
            set: { OnboardingHeightWeightValues.setHeightCm($0, in: &formState.wrappedValue) }
        )
    }

    static func weightKgBinding(_ formState: Binding<OnboardingFormState>) -> Binding<Double> {
        Binding(
            get: { OnboardingHeightWeightValues.resolvedWeightKg(from: formState.wrappedValue) },
            set: { OnboardingHeightWeightValues.setWeightKg($0, in: &formState.wrappedValue) }
        )
    }

    static func weightLbBinding(_ formState: Binding<OnboardingFormState>) -> Binding<Double> {
        Binding(
            get: { OnboardingHeightWeightValues.resolvedWeightLb(from: formState.wrappedValue) },
            set: { OnboardingHeightWeightValues.setWeightLb($0, in: &formState.wrappedValue) }
        )
    }

    static func imperialHeightSelectionsBinding(
        _ formState: Binding<OnboardingFormState>
    ) -> Binding<[String: Int]> {
        Binding(
            get: {
                [
                    "feet": OnboardingHeightWeightValues.imperialFeet(from: formState.wrappedValue),
                    "inches": OnboardingHeightWeightValues.imperialInches(from: formState.wrappedValue)
                ]
            },
            set: { values in
                let feet = values["feet"] ?? OnboardingHeightWeightValues.imperialFeet(from: formState.wrappedValue)
                let inches = values["inches"] ?? OnboardingHeightWeightValues.imperialInches(from: formState.wrappedValue)
                OnboardingHeightWeightValues.setImperialHeight(
                    feet: feet,
                    inches: inches,
                    in: &formState.wrappedValue
                )
            }
        )
    }

    @ViewBuilder
    private static func pairedMeasurementCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
            content()
        }
        .padding(FormaTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FormaProductCopy.Onboarding.Flow.HeightWeight.title)
    }

    @ViewBuilder
    private static func labeledColumn<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingWheelCardChrome: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.onboardingCompactCard()
        } else {
            content
        }
    }
}

enum OnboardingMetricWheelPicker {

    static func heightCm(
        selection: Binding<Double>,
        showsCardChrome: Bool = true
    ) -> some View {
        singleColumn(
            id: "heightCm",
            accessibilityLabel: FormaProductCopy.Onboarding.Validation.height,
            values: OnboardingPickerValueSequence.decimals(
                in: OnboardingPickerDefaults.metricHeightCmRange,
                step: 1
            ),
            selection: selection,
            format: { value in
                value.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(value))"
                    : String(format: "%.1f", value)
            },
            suffix: "cm",
            showsCardChrome: showsCardChrome
        )
    }

    static func weightKg(
        selection: Binding<Double>,
        range: ClosedRange<Double> = OnboardingPickerDefaults.metricWeightKgRange,
        showsCardChrome: Bool = true
    ) -> some View {
        singleColumn(
            id: "weightKg",
            accessibilityLabel: FormaProductCopy.Onboarding.Validation.currentWeight,
            values: OnboardingPickerValueSequence.decimals(in: range, step: 0.5),
            selection: selection,
            format: { value in
                value.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(value))"
                    : String(format: "%.1f", value)
            },
            suffix: "kg",
            showsCardChrome: showsCardChrome
        )
    }

    private static func singleColumn(
        id: String,
        accessibilityLabel: String,
        values: [Double],
        selection: Binding<Double>,
        format: @escaping (Double) -> String,
        suffix: String,
        showsCardChrome: Bool
    ) -> some View {
        OnboardingInlineWheelPicker(
            columns: [
                OnboardingWheelColumn(
                    id: id,
                    accessibilityLabel: accessibilityLabel,
                    values: values,
                    format: { value in
                        "\(format(value)) \(suffix)"
                    }
                )
            ],
            selections: Binding(
                get: { [id: selection.wrappedValue] },
                set: { newValue in
                    if let updated = newValue[id] {
                        selection.wrappedValue = updated
                    }
                }
            ),
            showsCardChrome: showsCardChrome
        )
    }
}

enum OnboardingImperialWheelPicker {

    static func weightLb(
        selection: Binding<Double>,
        range: ClosedRange<Double> = OnboardingPickerDefaults.imperialWeightLbRange,
        showsCardChrome: Bool = true
    ) -> some View {
        OnboardingInlineWheelPicker(
            columns: [
                OnboardingWheelColumn(
                    id: "weightLb",
                    accessibilityLabel: FormaProductCopy.Onboarding.Validation.currentWeight,
                    values: OnboardingPickerValueSequence.decimals(in: range, step: 1),
                    format: { value in
                        value.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(value)) lb"
                            : String(format: "%.1f lb", value)
                    }
                )
            ],
            selections: Binding(
                get: { ["weightLb": selection.wrappedValue] },
                set: { newValue in
                    if let updated = newValue["weightLb"] {
                        selection.wrappedValue = updated
                    }
                }
            ),
            showsCardChrome: showsCardChrome
        )
    }
}
