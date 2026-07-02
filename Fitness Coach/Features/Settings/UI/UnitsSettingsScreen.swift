//
//  UnitsSettingsScreen.swift
//  Fitness Coach
//
//  FitPilot — Unit preference screen (saves on change).
//

import SwiftUI

struct UnitsSettingsScreen: View {

    @Binding var formState: PlanFormState
    let onSave: (PlanFormState) async -> Void

    @State private var isSaving = false

    var body: some View {
        List {
            Section {
                Picker("Unit system", selection: $formState.unitSystem) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Text(PlanFormatter.unitSystem(system)).tag(system)
                    }
                }
                .disabled(isSaving)
                .tint(FormaTokens.Theme.primary)
                .formaSettingsRowChrome()
            } footer: {
                Text("Values are stored in metric internally. Imperial is a display preference for now.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .formaGroupedList()
        .navigationTitle("Units")
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
}

#Preview {
    NavigationStack {
        UnitsSettingsScreen(
            formState: .constant(PlanPreviewData.formState),
            onSave: { _ in }
        )
    }
}
