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
                        .foregroundStyle(.orange)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Estimates")
                            .font(.headline)
                        previewRow("BMR", "\(preview.estimatedBMR) kcal")
                        previewRow("TDEE", "\(preview.estimatedTDEE) kcal")
                        previewRow("Daily deficit", "\(preview.estimatedDailyDeficit) kcal")
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Generated Targets")
                            .font(.headline)
                        previewRow("Calories", ProfileFormatter.kcal(preview.targets.calorieTarget))
                        previewRow("Protein", ProfileFormatter.grams(preview.targets.proteinTarget))
                        previewRow("Carbs", ProfileFormatter.grams(preview.targets.carbTarget))
                        previewRow("Fat", ProfileFormatter.grams(preview.targets.fatTarget))
                        previewRow("Water", ProfileFormatter.ml(preview.targets.waterTargetMl))
                        previewRow(
                            "Aggressiveness",
                            ProfileFormatter.aggressiveness(preview.targets.aggressiveness)
                        )
                        if let weeklyLoss = ProfileFormatter.weeklyLoss(preview.targets.expectedWeeklyWeightLossKg) {
                            previewRow("Expected weekly loss", weeklyLoss)
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding()
            }
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
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
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
        preview: ProfilePreviewData.generatedPreview,
        onApply: {},
        onCancel: {}
    )
}
