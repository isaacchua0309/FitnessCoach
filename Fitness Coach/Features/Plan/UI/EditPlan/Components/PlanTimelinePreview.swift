//
//  PlanTimelinePreview.swift
//  Fitness Coach
//
//  Forma — Weight journey progress track for Edit Plan.
//

import SwiftUI

struct PlanTimelinePreview: View {
    let model: PlanTimelinePreviewDisplayModel

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let markerSize: CGFloat = 12
                let trackY = geometry.size.height / 2
                let startX = markerSize / 2
                let endX = width - markerSize / 2
                let fillWidth = max(0, (endX - startX) * model.progressFraction)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FormaPlanTokens.Color.planProgressTrack)
                        .frame(height: 6)
                        .position(x: width / 2, y: trackY)

                    if fillWidth > 0 {
                        Capsule()
                            .fill(FormaPlanTokens.Color.planProgressFill)
                            .frame(width: fillWidth, height: 6)
                            .position(x: startX + fillWidth / 2, y: trackY)
                    }

                    Circle()
                        .fill(FormaPlanTokens.Color.planAccent)
                        .frame(width: markerSize, height: markerSize)
                        .position(x: startX, y: trackY)

                    Circle()
                        .strokeBorder(FormaPlanTokens.Color.planAccent, lineWidth: 2)
                        .background(Circle().fill(FormaPlanTokens.Color.planSurface))
                        .frame(width: markerSize, height: markerSize)
                        .position(x: endX, y: trackY)
                }
            }
            .frame(height: 20)

            HStack {
                Text(model.currentWeight)
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                Spacer()
                Text(model.targetWeight)
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    PlanTimelinePreview(
        model: PlanTimelinePreviewDisplayModel(
            currentWeight: "80 kg",
            targetWeight: "70 kg",
            progressFraction: 0.35
        )
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
