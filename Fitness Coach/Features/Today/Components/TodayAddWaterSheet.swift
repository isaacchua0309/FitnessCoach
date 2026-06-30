//
//  TodayAddWaterSheet.swift
//  Fitness Coach
//
//  Forma — Native quick water logging from Today.
//

import SwiftUI

struct TodayAddWaterSheet: View {
    @Environment(\.dismiss) private var dismiss

    let presetAmountsMl: [Int]
    let errorMessage: String?
    let onAdd: (Int) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                Text(FormaProductCopy.Today.QuickActions.addWaterSheetBody)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: FormaTokens.Spacing.sm),
                        GridItem(.flexible(), spacing: FormaTokens.Spacing.sm)
                    ],
                    spacing: FormaTokens.Spacing.sm
                ) {
                    ForEach(presetAmountsMl, id: \.self) { amountMl in
                        Button {
                            onAdd(amountMl)
                            dismiss()
                        } label: {
                            Text(FormaProductCopy.Today.QuickActions.waterAmountLabel(amountMl))
                                .font(FormaTokens.Typography.bodyMedium)
                                .foregroundStyle(FormaTokens.Color.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, FormaTokens.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                                        .fill(FormaTokens.Color.surface)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                                        .stroke(FormaTokens.Color.border, lineWidth: 0.5)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(FormaProductCopy.Today.QuickActions.waterAmountAccessibilityLabel(amountMl))
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.destructive)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, FormaScreenStyle.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, FormaTokens.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .formaFormScreen()
            .navigationTitle(FormaProductCopy.Today.QuickActions.addWaterSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(FormaProductCopy.Common.cancel) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TodayAddWaterSheet(
        presetAmountsMl: [250, 500, 750, 1_000],
        errorMessage: nil,
        onAdd: { _ in }
    )
    .formaThemePreview()
}
