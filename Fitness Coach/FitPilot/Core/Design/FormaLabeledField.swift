//
//  FormaLabeledField.swift
//  Fitness Coach
//
//  Forma — Labeled text input with persistent title.
//

import SwiftUI

struct FormaLabeledField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var helper: String?
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>?

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)

            field

            if let helper {
                Text(helper)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var field: some View {
        let base = TextField(placeholder, text: $text, axis: axis)
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .font(FormaTokens.Typography.bodyMedium)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .tint(FormaTokens.Color.accent)
            .padding(.horizontal, FormaTokens.Spacing.sm + 2)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .background(fieldBackground)
            .overlay(fieldBorder)

        if let lineLimit {
            base.lineLimit(lineLimit)
        } else {
            base
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
            .fill(FormaTokens.Color.surfaceSubtle)
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
            .stroke(FormaTokens.Color.border, lineWidth: 1)
    }
}

struct FormaLabeledNumberField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var unit: String?
    var helper: String?
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)

            HStack(spacing: FormaTokens.Spacing.xs) {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .font(FormaTokens.Typography.bodyMedium)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .tint(FormaTokens.Color.accent)
                    .multilineTextAlignment(.leading)

                if let unit {
                    Text(unit)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                }
            }
            .padding(.horizontal, FormaTokens.Spacing.sm + 2)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                    .fill(FormaTokens.Color.surfaceSubtle)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                    .stroke(FormaTokens.Color.border, lineWidth: 1)
            }

            if let helper {
                Text(helper)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct FormaInlineNumberField: View {
    let title: String
    @Binding var text: String
    var unit: String?
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)

            HStack(spacing: 4) {
                TextField("0", text: $text)
                    .keyboardType(keyboard)
                    .font(FormaTokens.Typography.bodyMedium)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .tint(FormaTokens.Color.accent)
                    .multilineTextAlignment(.center)

                if let unit {
                    Text(unit)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                }
            }
            .padding(.horizontal, FormaTokens.Spacing.xs)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                    .fill(FormaTokens.Color.surfaceSubtle)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                    .stroke(FormaTokens.Color.border, lineWidth: 1)
            }
        }
    }
}
