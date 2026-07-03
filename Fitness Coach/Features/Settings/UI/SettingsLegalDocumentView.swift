//
//  SettingsLegalDocumentView.swift
//  Fitness Coach
//
//  Forma — In-app Terms and Privacy Policy reader.
//

import SwiftUI

struct SettingsLegalDocumentView: View {

    let document: FormaLegalDocument

    var body: some View {
        formaSettingsDetailScreen {
            VStack(alignment: .leading, spacing: SettingsChromeAccessibility.detailSectionSpacing) {
                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                        Text(section.title)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .accessibilityAddTraits(.isHeader)

                        Text(section.body)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textLegal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle(document.navigationTitle)
    }
}

#Preview {
    NavigationStack {
        SettingsLegalDocumentView(document: .privacyPolicy)
    }
    .formaThemePreview()
}
