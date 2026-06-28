//
//  UnitsSettingsScreen.swift
//  Fitness Coach
//
//  FitPilot — Unit preference screen (saves on change).
//

import SwiftUI

struct UnitsSettingsScreen: View {

    @Binding var formState: ProfileFormState
    let onSave: (ProfileFormState) async -> Void

    @State private var isSaving = false

    var body: some View {
        List {
            Section {
                Picker("Unit system", selection: $formState.unitSystem) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Text(ProfileFormatter.unitSystem(system)).tag(system)
                    }
                }
                .disabled(isSaving)
                .fitPilotSettingsRowChrome()
            } footer: {
                Text("Values are stored in metric internally. Imperial is a display preference for now.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .fitPilotGroupedList()
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
        .fitPilotScrollBottomInset()
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
            formState: .constant(ProfilePreviewData.formState),
            onSave: { _ in }
        )
    }
}
