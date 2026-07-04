//
//  SettingsPrivacyDataAccountStatusView.swift
//  Fitness Coach
//
//  Forma — Account data status detail (Privacy & Data).
//

import SwiftUI

struct SettingsPrivacyDataAccountStatusView: View {

    let status: SettingsPrivacyDataStatusSnapshot

    private var presentation: SettingsPrivacyDataAccountStatusPresentation {
        SettingsPrivacyDataPresentationBuilder.accountStatusPresentation(status: status)
    }

    var body: some View {
        formaSettingsDetailScreen {
            detailCard
        }
        .navigationTitle(presentation.screenTitle)
    }

    private var detailCard: some View {
        FormaPlanCard(compact: true) {
            VStack(spacing: 0) {
                ForEach(Array(presentation.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider()
                            .overlay(FormaTokens.Color.border)
                            .padding(.vertical, FormaTokens.Spacing.xs)
                    }

                    detailRow(row)
                }
            }
        }
    }

    private func detailRow(_ row: SettingsPrivacyDataDetailRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
            Text(row.label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .frame(
                    width: SettingsChromeAccessibility.detailLabelColumnWidth,
                    alignment: .leading
                )
                .fixedSize(horizontal: false, vertical: true)

            Text(row.value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.label), \(row.value)")
    }
}
