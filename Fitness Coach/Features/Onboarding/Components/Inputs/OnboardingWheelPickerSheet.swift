//
//  OnboardingWheelPickerSheet.swift
//  Fitness Coach
//
//  Forma — Wheel picker sheet and inline value picker for onboarding metrics.
//

import SwiftUI

// MARK: - Value sequence helpers

enum OnboardingPickerValueSequence {
    static func integers(in range: ClosedRange<Int>, step: Int = 1) -> [Int] {
        guard step > 0 else { return [range.lowerBound] }
        return stride(from: range.lowerBound, through: range.upperBound, by: step).map { $0 }
    }

    static func decimals(
        in range: ClosedRange<Double>,
        step: Double
    ) -> [Double] {
        guard step > 0 else { return [range.lowerBound] }
        var values: [Double] = []
        var current = range.lowerBound
        let epsilon = step / 10
        while current <= range.upperBound + epsilon {
            values.append((current * 100).rounded() / 100)
            current += step
        }
        return values
    }
}

// MARK: - Wheel sheet

struct OnboardingWheelPickerSheet<Value: Hashable>: View {
    let title: String
    let values: [Value]
    @Binding var selection: Value
    let format: (Value) -> String
    @Binding var isPresented: Bool
    var confirmTitle: String = FormaProductCopy.Common.continueAction

    @State private var draftSelection: Value

    init(
        title: String,
        values: [Value],
        selection: Binding<Value>,
        format: @escaping (Value) -> String,
        isPresented: Binding<Bool>,
        confirmTitle: String = FormaProductCopy.Common.continueAction
    ) {
        self.title = title
        self.values = values
        _selection = selection
        self.format = format
        _isPresented = isPresented
        self.confirmTitle = confirmTitle
        _draftSelection = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if values.isEmpty {
                    Text(FormaProductCopy.Error.checkInputs)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .padding()
                } else {
                    Picker(title, selection: $draftSelection) {
                        ForEach(values, id: \.self) { value in
                            Text(format(value))
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxHeight: 220)
                    .accessibilityLabel(title)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, OnboardingTheme.pagePadding)
            .background(OnboardingTheme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(FormaProductCopy.Common.back) {
                        isPresented = false
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        selection = draftSelection
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .accessibilityLabel(confirmTitle)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onAppear {
            if values.contains(selection) {
                draftSelection = selection
            } else if let first = values.first {
                draftSelection = first
            }
        }
    }
}

// MARK: - Value picker (summary row + sheet)

struct OnboardingValuePicker<Value: Hashable>: View {
    let label: String
    let values: [Value]
    @Binding var selection: Value
    let format: (Value) -> String
    var unit: String?
    var sheetTitle: String?

    @State private var isSheetPresented = false

    var body: some View {
        OnboardingFieldSummary(
            label: label,
            value: format(selection),
            unit: unit,
            action: { isSheetPresented = true }
        )
        .sheet(isPresented: $isSheetPresented) {
            OnboardingWheelPickerSheet(
                title: sheetTitle ?? label,
                values: values,
                selection: $selection,
                format: format,
                isPresented: $isSheetPresented
            )
        }
    }
}

// MARK: - Preset metric pickers

enum OnboardingMetricValuePicker {

    static func age(
        label: String = "Age",
        selection: Binding<Int>
    ) -> some View {
        OnboardingValuePicker(
            label: label,
            values: OnboardingPickerValueSequence.integers(
                in: OnboardingV3PickerDefaults.ageRange
            ),
            selection: selection,
            format: { "\($0)" },
            unit: "years",
            sheetTitle: label
        )
    }

    static func heightMetric(
        label: String = "Height",
        selection: Binding<Double>
    ) -> some View {
        let values = OnboardingPickerValueSequence.decimals(
            in: OnboardingV3PickerDefaults.metricHeightCmRange,
            step: 1
        )
        return OnboardingValuePicker(
            label: label,
            values: values,
            selection: selection,
            format: { value in
                value.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(value))"
                    : String(format: "%.1f", value)
            },
            unit: "cm",
            sheetTitle: label
        )
    }

    static func weightMetric(
        label: String,
        selection: Binding<Double>,
        range: ClosedRange<Double> = OnboardingV3PickerDefaults.metricWeightKgRange,
        step: Double = 0.5
    ) -> some View {
        let values = OnboardingPickerValueSequence.decimals(in: range, step: step)
        return OnboardingValuePicker(
            label: label,
            values: values,
            selection: selection,
            format: { value in
                value.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(value))"
                    : String(format: "%.1f", value)
            },
            unit: "kg",
            sheetTitle: label
        )
    }

    static func heightImperial(
        label: String = "Height",
        selection: Binding<Double>
    ) -> some View {
        let values = OnboardingPickerValueSequence.decimals(
            in: OnboardingV3PickerDefaults.imperialHeightInchesRange,
            step: 1
        )
        return OnboardingValuePicker(
            label: label,
            values: values,
            selection: selection,
            format: { inches in
                let total = Int(inches.rounded())
                let feet = total / 12
                let remainder = total % 12
                return "\(feet)′ \(remainder)″"
            },
            unit: nil,
            sheetTitle: label
        )
    }

    static func weightImperial(
        label: String,
        selection: Binding<Double>
    ) -> some View {
        let values = OnboardingPickerValueSequence.decimals(
            in: OnboardingV3PickerDefaults.imperialWeightLbRange,
            step: 1
        )
        return OnboardingValuePicker(
            label: label,
            values: values,
            selection: selection,
            format: { value in
                value.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(value))"
                    : String(format: "%.1f", value)
            },
            unit: "lb",
            sheetTitle: label
        )
    }
}

#Preview("Age picker") {
    struct Demo: View {
        @State private var age = OnboardingV3PickerDefaults.defaultAge
        var body: some View {
            OnboardingMetricValuePicker.age(selection: $age)
                .padding()
                .background(OnboardingTheme.background)
        }
    }
    return Demo()
        .preferredColorScheme(.dark)
}

#Preview("Height picker") {
    struct Demo: View {
        @State private var height = OnboardingV3PickerDefaults.defaultHeightCm
        var body: some View {
            OnboardingMetricValuePicker.heightMetric(selection: $height)
                .padding()
                .background(OnboardingTheme.background)
        }
    }
    return Demo()
        .preferredColorScheme(.dark)
}

#Preview("Wheel sheet") {
    struct Demo: View {
        @State private var value = 28
        @State private var isPresented = true
        var body: some View {
            Color.clear
                .sheet(isPresented: $isPresented) {
                    OnboardingWheelPickerSheet(
                        title: "Age",
                        values: Array(16...90),
                        selection: $value,
                        format: { "\($0)" },
                        isPresented: $isPresented
                    )
                }
        }
    }
    return Demo()
        .preferredColorScheme(.dark)
}
