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
    var wheelHeight: CGFloat = 164

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(columns) { column in
                columnPicker(column)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, FormaTokens.Spacing.sm)
        .onboardingCompactCard()
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

    @State private var month: Int
    @State private var day: Int
    @State private var year: Int

    private let calendar: Calendar

    init(birthDate: Binding<Date?>, calendar: Calendar = .current) {
        _birthDate = birthDate
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
            )
        )
        .onAppear {
            syncBirthDate()
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
        HStack(spacing: FormaTokens.Spacing.sm) {
            labeledColumn(title: FormaProductCopy.Onboarding.Flow.HeightWeight.heightLabel) {
                OnboardingMetricWheelPicker.heightCm(
                    selection: heightCmBinding(formState)
                )
            }

            labeledColumn(title: FormaProductCopy.Onboarding.Flow.HeightWeight.weightLabel) {
                OnboardingMetricWheelPicker.weightKg(
                    selection: weightKgBinding(formState)
                )
            }
        }
    }

    @ViewBuilder
    static func imperial(formState: Binding<OnboardingFormState>) -> some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
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
                    selections: imperialHeightSelectionsBinding(formState)
                )
            }

            labeledColumn(title: FormaProductCopy.Onboarding.Flow.HeightWeight.weightLabel) {
                OnboardingImperialWheelPicker.weightLb(
                    selection: weightLbBinding(formState)
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
    private static func labeledColumn<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
        }
        .frame(maxWidth: .infinity)
    }
}

enum OnboardingMetricWheelPicker {

    static func heightCm(selection: Binding<Double>) -> some View {
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
            suffix: "cm"
        )
    }

    static func weightKg(
        selection: Binding<Double>,
        range: ClosedRange<Double> = OnboardingPickerDefaults.metricWeightKgRange
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
            suffix: "kg"
        )
    }

    private static func singleColumn(
        id: String,
        accessibilityLabel: String,
        values: [Double],
        selection: Binding<Double>,
        format: @escaping (Double) -> String,
        suffix: String
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
            )
        )
    }
}

enum OnboardingImperialWheelPicker {

    static func weightLb(
        selection: Binding<Double>,
        range: ClosedRange<Double> = OnboardingPickerDefaults.imperialWeightLbRange
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
            )
        )
    }
}
