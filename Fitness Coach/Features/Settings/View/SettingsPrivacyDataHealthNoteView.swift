//
//  SettingsPrivacyDataHealthNoteView.swift
//  Fitness Coach
//
//  Forma — Health data deletion limits (Privacy & Data).
//

import SwiftUI

struct SettingsPrivacyDataHealthNoteView: View {

    private var presentation: SettingsPrivacyDataHealthNotePresentation {
        SettingsPrivacyDataPresentationBuilder.healthNotePresentation()
    }

    var body: some View {
        formaSettingsDetailScreen {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                ForEach(Array(presentation.bodyParagraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .navigationTitle(presentation.screenTitle)
    }
}
