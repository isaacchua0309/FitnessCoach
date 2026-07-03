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
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                        Text(section.title)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.textPrimary)

                        Text(section.body)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textLegal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .formaScreenBackground()
        .navigationTitle(document.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
    }
}

#Preview {
    NavigationStack {
        SettingsLegalDocumentView(document: .privacyPolicy)
    }
    .formaThemePreview()
}
