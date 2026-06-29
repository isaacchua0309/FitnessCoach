//
//  OnboardingPlanBlueprintVisualCanvas.swift
//  Fitness Coach
//
//  Forma — Route-only journey strip for loss/gain blueprint goals.
//

import SwiftUI

struct OnboardingPlanBlueprintVisualProfile: Equatable, Sendable {
    let style: OnboardingPlanBlueprintIllustrationStyle
    let currentWeight: String?
    let targetWeight: String
    let routeProgress: CGFloat
}

struct OnboardingPlanBlueprintJourneyStrip: View {
    let profile: OnboardingPlanBlueprintVisualProfile

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var routeTrim: CGFloat = 0
    @State private var travelerProgress: CGFloat = 0

    @ScaledMetric(relativeTo: .caption2) private var stripHeight: CGFloat = 72
    @ScaledMetric(relativeTo: .caption2) private var endpointSize: CGFloat = 28

    private var showsJourney: Bool {
        switch profile.style {
        case .loss, .gain:
            return true
        case .maintain, .fallback:
            return false
        }
    }

    var body: some View {
        Group {
            if showsJourney {
                GeometryReader { proxy in
                    routeLayer(in: proxy.size)
                }
                .frame(height: stripHeight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(journeyAccessibilityLabel)
                .onAppear {
                    travelerProgress = profile.routeProgress
                    guard !reduceMotion else {
                        routeTrim = 1
                        return
                    }
                    routeTrim = 0
                    withAnimation(.easeOut(duration: 1.0)) {
                        routeTrim = 1
                    }
                    withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                        travelerProgress = min(profile.routeProgress + 0.1, 0.95)
                    }
                }
            }
        }
    }

    private func routeLayer(in size: CGSize) -> some View {
        let start = CGPoint(x: size.width * 0.12, y: size.height * 0.68)
        let end = routeEnd(in: size)
        let path = routePath(start: start, end: end, style: profile.style, height: size.height)
        let traveler = travelerPoint(
            start: start,
            end: end,
            progress: travelerProgress,
            style: profile.style,
            height: size.height
        )

        return ZStack {
            path
                .stroke(
                    OnboardingTheme.border.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5])
                )

            path
                .trim(from: 0, to: routeTrim)
                .stroke(
                    LinearGradient(
                        colors: [
                            OnboardingTheme.chartPrimary.opacity(0.55),
                            OnboardingTheme.chartSecondary.opacity(0.9)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )

            endpointNode(label: profile.currentWeight, symbol: "figure.stand")
                .position(start)

            endpointNode(label: profile.targetWeight, symbol: "scope", emphasized: true)
                .position(end)

            Circle()
                .fill(OnboardingTheme.accent)
                .frame(width: 7, height: 7)
                .shadow(color: OnboardingTheme.accent.opacity(0.35), radius: 3)
                .position(traveler)
        }
    }

    private func routeEnd(in size: CGSize) -> CGPoint {
        switch profile.style {
        case .loss:
            return CGPoint(x: size.width * 0.88, y: size.height * 0.78)
        case .gain:
            return CGPoint(x: size.width * 0.88, y: size.height * 0.52)
        case .maintain, .fallback:
            return CGPoint(x: size.width * 0.88, y: size.height * 0.65)
        }
    }

    private func routePath(
        start: CGPoint,
        end: CGPoint,
        style: OnboardingPlanBlueprintIllustrationStyle,
        height: CGFloat
    ) -> Path {
        let lift = height * 0.28
        let dip = height * 0.12
        return Path { path in
            path.move(to: start)
            let control1: CGPoint
            let control2: CGPoint
            switch style {
            case .loss:
                control1 = CGPoint(x: start.x + (end.x - start.x) * 0.35, y: start.y - lift)
                control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y + dip)
            case .gain:
                control1 = CGPoint(x: start.x + (end.x - start.x) * 0.35, y: start.y - dip)
                control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y + lift)
            case .maintain, .fallback:
                control1 = CGPoint(x: start.x + (end.x - start.x) * 0.33, y: start.y)
                control2 = CGPoint(x: start.x + (end.x - start.x) * 0.66, y: end.y)
            }
            path.addCurve(to: end, control1: control1, control2: control2)
        }
    }

    private func travelerPoint(
        start: CGPoint,
        end: CGPoint,
        progress: CGFloat,
        style: OnboardingPlanBlueprintIllustrationStyle,
        height: CGFloat
    ) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let lift = height * 0.28
        let dip = height * 0.12
        let control1: CGPoint
        let control2: CGPoint
        switch style {
        case .loss:
            control1 = CGPoint(x: start.x + (end.x - start.x) * 0.35, y: start.y - lift)
            control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y + dip)
        case .gain:
            control1 = CGPoint(x: start.x + (end.x - start.x) * 0.35, y: start.y - dip)
            control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y + lift)
        case .maintain, .fallback:
            control1 = CGPoint(x: start.x + (end.x - start.x) * 0.33, y: start.y)
            control2 = CGPoint(x: start.x + (end.x - start.x) * 0.66, y: end.y)
        }
        return cubicBezierPoint(t: t, p0: start, p1: control1, p2: control2, p3: end)
    }

    private func cubicBezierPoint(
        t: CGFloat,
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint
    ) -> CGPoint {
        let u = 1 - t
        let x = u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x
        let y = u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y
        return CGPoint(x: x, y: y)
    }

    private func endpointNode(label: String?, symbol: String, emphasized: Bool = false) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(emphasized ? OnboardingTheme.chartPrimary.opacity(0.12) : OnboardingTheme.surfaceSubtle)
                    .frame(width: endpointSize, height: endpointSize)
                Image(systemName: symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(emphasized ? OnboardingTheme.chartPrimary : OnboardingTheme.secondaryText)
            }
            if let label {
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(emphasized ? OnboardingTheme.primaryText : OnboardingTheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var journeyAccessibilityLabel: String {
        let direction: String
        switch profile.style {
        case .loss: direction = "Weight loss route"
        case .gain: direction = "Weight gain route"
        case .maintain: direction = "Maintain route"
        case .fallback: direction = "Personal route"
        }
        let origin = profile.currentWeight ?? "start"
        return "\(direction) from \(origin) to \(profile.targetWeight)."
    }
}

#if DEBUG
#Preview("Loss") {
    OnboardingPlanBlueprintJourneyStrip(
        profile: OnboardingPlanBlueprintBuilder.build(
            from: {
                var state = OnboardingPreviewData.formState
                OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &state)
                return state
            }()
        ).visualProfile
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
