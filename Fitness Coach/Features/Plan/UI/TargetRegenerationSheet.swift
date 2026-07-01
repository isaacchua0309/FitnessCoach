//
//  TargetRegenerationSheet.swift
//  Fitness Coach
//
//  FitPilot AI — Preview regenerated targets before applying.
//

import SwiftUI

struct TargetRegenerationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let preview: CalorieTargetResult
    let onApply: () async -> Void
    let onCancel: () -> Void

    @State private var isApplying = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if preview.isAggressive || preview.warning != nil {
                        Label(
                            "These targets may be aggressive. Review before applying.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.warning)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            FormaTokens.Color.warning.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Estimates")
                            .font(.headline)
                        previewRow("BMR", "\(preview.estimatedBMR) kcal")
                        previewRow("TDEE", "\(preview.estimatedTDEE) kcal")
                        previewRow("Daily deficit", "\(preview.estimatedDailyDeficit) kcal")
                    }
                    .padding()
                    .background(
                        FormaTokens.Color.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Generated Targets")
                            .font(.headline)
                        previewRow("Calories", PlanFormatter.kcal(preview.targets.calorieTarget))
                        previewRow("Protein", PlanFormatter.grams(preview.targets.proteinTarget))
                        previewRow("Carbs", PlanFormatter.grams(preview.targets.carbTarget))
                        previewRow("Fat", PlanFormatter.grams(preview.targets.fatTarget))
                        previewRow("Water", PlanFormatter.ml(preview.targets.waterTargetMl))
                        previewRow(
                            "Aggressiveness",
                            PlanFormatter.aggressiveness(preview.targets.aggressiveness)
                        )
                        if let weeklyLoss = PlanFormatter.weeklyLoss(preview.targets.expectedWeeklyWeightLossKg) {
                            previewRow("Expected weekly loss", weeklyLoss)
                        }
                    }
                    .padding()
                    .background(
                        FormaTokens.Color.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .padding()
            }
            .background(FormaTokens.Color.canvas)
            .navigationTitle("Regenerated Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        apply()
                    } label: {
                        if isApplying {
                            SwiftUI.ProgressView()
                        } else {
                            Text("Apply")
                        }
                    }
                    .disabled(isApplying)
                }
            }
        }
    }

    private func previewRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(FormaTokens.Color.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textPrimary)
        }
    }

    private func apply() {
        guard !isApplying else { return }
        isApplying = true
        Task {
            await onApply()
            isApplying = false
            dismiss()
        }
    }
}

#Preview {
    TargetRegenerationSheet(
        preview: PlanPreviewData.generatedPreview,
        onApply: {},
        onCancel: {}
    )
    .formaThemePreview()
}
