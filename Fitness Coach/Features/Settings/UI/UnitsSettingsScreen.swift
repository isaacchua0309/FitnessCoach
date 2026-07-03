//
//  UnitsSettingsScreen.swift
//  Fitness Coach
//
//  Forma — Unit preference screen (saves on change).
//

import SwiftUI

struct UnitsSettingsScreen: View {

    @Binding var formState: PlanFormState
    let onSave: (PlanFormState) async -> Void

    @State private var isSaving = false

    private var presentation: UnitsSettingsPresentation {
        UnitsSettingsPresentationBuilder.build(
            input: UnitsSettingsPresentationInput(unitSystem: formState.unitSystem)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                unitSystemSection
                examplesSection
                footnotesSection
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, FormaTokens.Spacing.sm)
        }
        .formaScreenBackground()
        .navigationTitle(presentation.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
        .onChange(of: formState.unitSystem) { _, _ in
            guard !isSaving else { return }
            isSaving = true
            Task {
                await onSave(formState)
                isSaving = false
            }
        }
    }

    // MARK: - Unit system

    private var unitSystemSection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            sectionHeader(presentation.unitSystemSectionTitle)

            FormaPlanCard {
                VStack(spacing: 0) {
                    ForEach(Array(presentation.unitSystemOptions.enumerated()), id: \.element) { index, unitSystem in
                        if index > 0 {
                            FormaPlanRowDivider()
                        }

                        UnitsSettingsOptionRow(
                            title: presentation.pickerLabel(for: unitSystem),
                            isSelected: formState.unitSystem == unitSystem,
                            isEnabled: !isSaving,
                            accessibilityLabel: presentation.accessibilityLabel(for: unitSystem),
                            onSelect: { selectUnitSystem(unitSystem) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Examples

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            sectionHeader(presentation.examplesSectionTitle)

            FormaPlanCard {
                VStack(spacing: 0) {
                    ForEach(Array(presentation.exampleRows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            FormaPlanRowDivider()
                        }

                        FormaPlanDisplayRow(label: row.label, value: row.unit)
                    }
                }
            }
        }
    }

    // MARK: - Footnotes

    private var footnotesSection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(presentation.storageFootnote)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let imperialFootnote = presentation.imperialDisplayOnlyFootnote {
                Text(imperialFootnote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .accessibilityAddTraits(.isHeader)
    }

    private func selectUnitSystem(_ unitSystem: UnitSystem) {
        guard formState.unitSystem != unitSystem, !isSaving else { return }
        formState.unitSystem = unitSystem
    }
}

// MARK: - Option row

private struct UnitsSettingsOptionRow: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let accessibilityLabel: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                Text(title)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview("Metric") {
    NavigationStack {
        UnitsSettingsScreen(
            formState: .constant(PlanPreviewData.formState),
            onSave: { _ in }
        )
    }
    .formaThemePreview()
}

#Preview("Imperial") {
    NavigationStack {
        UnitsSettingsScreen(
            formState: .constant({
                var state = PlanPreviewData.formState
                state.unitSystem = .imperial
                return state
            }()),
            onSave: { _ in }
        )
    }
    .formaThemePreview()
}
