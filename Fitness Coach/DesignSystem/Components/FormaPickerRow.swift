//
//  FormaPickerRow.swift
//  Fitness Coach
//
//  Forma — Labeled picker row for forms.
//

import SwiftUI

struct FormaPickerRow<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker(title, selection: $selection, content: content)
                .labelsHidden()
                .tint(FormaTokens.Theme.primary)
        }
        .padding(.horizontal, FormaTokens.Spacing.sm + 2)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(FormaTokens.Color.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
