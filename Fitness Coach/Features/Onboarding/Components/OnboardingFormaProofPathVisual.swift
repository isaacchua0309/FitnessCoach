//
//  OnboardingFormaProofPathVisual.swift
//  Fitness Coach
//
//  Forma — Goal-aware progress path visual for forma proof onboarding.
//

import SwiftUI

struct OnboardingFormaProofPathVisual: View {
    let style: OnboardingFormaProofPathStyle
    var animatePlannedPath: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plannedProgress: CGFloat = 0

    private let height: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            HStack(spacing: FormaTokens.Spacing.lg) {
                legend(label: "Without structure", dashed: true, color: OnboardingTheme.chartSecondary)
                legend(label: "With Forma", dashed: false, color: OnboardingTheme.chartPrimary)
            }

            ZStack {
                pathCanvas
            }
            .frame(height: height)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, FormaTokens.Spacing.cardPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(OnboardingTheme.surfaceSubtle.opacity(0.55))
        )
        .onAppear {
            guard animatePlannedPath, !reduceMotion else {
                plannedProgress = 1
                return
            }
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) {
                plannedProgress = 1
            }
        }
    }

    private var pathCanvas: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let midY = proxy.size.height * 0.5

            unstructuredPath(width: width, midY: midY)
                .stroke(
                    OnboardingTheme.chartSecondary,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
                )

            plannedPath(width: width, midY: midY)
                .trim(from: 0, to: plannedProgress)
                .stroke(
                    OnboardingTheme.chartPrimary,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )

            if style == .maintain {
                Rectangle()
                    .fill(OnboardingTheme.chartPrimary.opacity(0.12))
                    .frame(height: proxy.size.height * 0.28)
                    .position(x: width * 0.5, y: midY)
            }
        }
    }

    private func unstructuredPath(width: CGFloat, midY: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: midY))
            switch style {
            case .loss, .fallback:
                path.addCurve(
                    to: CGPoint(x: width, y: midY + 10),
                    control1: CGPoint(x: width * 0.3, y: midY - 14),
                    control2: CGPoint(x: width * 0.7, y: midY + 18)
                )
            case .gain:
                path.addCurve(
                    to: CGPoint(x: width, y: midY - 8),
                    control1: CGPoint(x: width * 0.3, y: midY + 16),
                    control2: CGPoint(x: width * 0.7, y: midY - 18)
                )
            case .maintain:
                path.addCurve(
                    to: CGPoint(x: width, y: midY + 12),
                    control1: CGPoint(x: width * 0.35, y: midY - 10),
                    control2: CGPoint(x: width * 0.65, y: midY + 14)
                )
            }
        }
    }

    private func plannedPath(width: CGFloat, midY: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: midY))
            switch style {
            case .loss, .fallback:
                path.addCurve(
                    to: CGPoint(x: width, y: midY + 18),
                    control1: CGPoint(x: width * 0.35, y: midY + 2),
                    control2: CGPoint(x: width * 0.7, y: midY + 12)
                )
            case .gain:
                path.addCurve(
                    to: CGPoint(x: width, y: midY - 18),
                    control1: CGPoint(x: width * 0.35, y: midY - 2),
                    control2: CGPoint(x: width * 0.7, y: midY - 12)
                )
            case .maintain:
                path.addLine(to: CGPoint(x: width, y: midY))
            }
        }
    }

    private func legend(label: String, dashed: Bool, color: Color) -> some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            Group {
                if dashed {
                    HStack(spacing: 3) {
                        Capsule().fill(color).frame(width: 8, height: 2.5)
                        Capsule().fill(color).frame(width: 5, height: 2.5)
                    }
                } else {
                    Capsule().fill(color).frame(width: 16, height: 2.5)
                }
            }
            .accessibilityHidden(true)

            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("Loss path") {
    OnboardingFormaProofPathVisual(style: .loss, animatePlannedPath: true)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
