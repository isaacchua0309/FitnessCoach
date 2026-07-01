//
//  TodayLogWeightSheet.swift
//  Fitness Coach
//
//  Forma — Native Today sheet for logging daily weight.
//

import SwiftUI

struct TodayLogWeightSheet: View {
    @Environment(\.dismiss) private var dismiss

    let errorMessage: String?
    let onSave: (Double) -> Void

    @State private var weightText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sectionSpacing) {
                    FormaFormCard(title: FormaProductCopy.Today.NextAction.sheetLogWeightSection) {
                        FormaLabeledNumberField(
                            title: FormaProductCopy.Today.NextAction.sheetWeightField,
                            placeholder: FormaProductCopy.Today.NextAction.sheetWeightPlaceholder,
                            text: $weightText,
                            keyboard: .decimalPad
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(FormaTokens.Spacing.md)
                            .background {
                                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                                    .fill(FormaTokens.Color.destructive.opacity(0.12))
                            }
                    }
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.top, FormaTokens.Spacing.md)
                .padding(.bottom, FormaTokens.Spacing.lg)
            }
            .formaFormScreen()
            .navigationTitle(FormaProductCopy.Today.NextAction.sheetLogWeightTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(FormaProductCopy.Common.cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(FormaProductCopy.Today.NextAction.sheetSave) {
                        guard let weightKg = Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines)),
                              weightKg > 0 else {
                            return
                        }
                        onSave(weightKg)
                    }
                }
            }
        }
    }
}
