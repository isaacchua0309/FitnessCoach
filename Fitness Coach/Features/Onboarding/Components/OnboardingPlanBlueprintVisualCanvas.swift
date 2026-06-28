//
//  OnboardingPlanBlueprintVisualCanvas.swift
//  Fitness Coach
//
//  Forma — Composite blueprint visual: route, target, rings, radar, particles.
//

import SwiftUI

struct OnboardingPlanBlueprintVisualProfile: Equatable, Sendable {
    let style: OnboardingPlanBlueprintIllustrationStyle
    let currentWeight: String?
    let targetWeight: String
    let routeProgress: CGFloat
    let radarValues: [CGFloat]
}

struct OnboardingPlanBlueprintVisualCanvas: View {
    let profile: OnboardingPlanBlueprintVisualProfile
    var launchReady: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var routeTrim: CGFloat = 0
    @State private var travelerProgress: CGFloat = 0
    @State private var glowPulse = false
    @State private var launchAccent = false
    @State private var particlePhase: CGFloat = 0

    @ScaledMetric(relativeTo: .title2) private var canvasHeight: CGFloat = 108

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                canvasBackground
                blueprintGrid(in: size)
                softLighting(in: size)
                nutritionRings
                    .position(x: size.width * 0.18, y: size.height * 0.22)
                personalizationRadar
                    .position(x: size.width * 0.84, y: size.height * 0.24)
                routeLayer(in: size)
                particles(in: size)
            }
        }
        .frame(height: canvasHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .stroke(
                    OnboardingTheme.accent.opacity(launchAccent ? 0.34 : 0.16),
                    lineWidth: launchAccent ? 1.5 : 1
                )
        }
        .shadow(
            color: launchAccent ? OnboardingTheme.accent.opacity(0.12) : .clear,
            radius: launchAccent ? 8 : 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(visualAccessibilityLabel)
        .onAppear {
            glowPulse = true
            particlePhase = 1
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
        .onChange(of: launchReady) { _, ready in
            guard ready, !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: OnboardingPlanBlueprintLaunchTiming.pulseDuration)
                    .repeatForever(autoreverses: true)
            ) {
                launchAccent = true
            }
        }
    }

    private var canvasBackground: some View {
        LinearGradient(
            colors: [
                FormaTokens.Color.accentMuted.opacity(0.55),
                FormaTokens.Color.surfaceSubtle.opacity(0.95),
                OnboardingTheme.background.opacity(0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func softLighting(in size: CGSize) -> some View {
        RadialGradient(
            colors: [
                OnboardingTheme.accent.opacity(glowPulse && !reduceMotion ? (launchAccent ? 0.2 : 0.14) : 0.1),
                .clear
            ],
            center: UnitPoint(x: 0.72, y: 0.38),
            startRadius: 0,
            endRadius: size.width * 0.55
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
            value: glowPulse
        )
    }

    private func blueprintGrid(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var grid = Path()
            let spacing: CGFloat = 14
            var y: CGFloat = spacing
            while y < canvasSize.height {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: canvasSize.width, y: y))
                y += spacing
            }
            var x: CGFloat = spacing
            while x < canvasSize.width {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: canvasSize.height))
                x += spacing
            }
            context.stroke(
                grid,
                with: .color(OnboardingTheme.border.opacity(0.18)),
                style: StrokeStyle(lineWidth: 0.5, dash: [2, 5])
            )
        }
    }

    private var nutritionRings: some View {
        HStack(spacing: 4) {
            macroRing(progress: 0.78, color: OnboardingTheme.accent)
            macroRing(progress: 0.62, color: OnboardingTheme.chartPrimary)
            macroRing(progress: 0.54, color: OnboardingTheme.chartSecondary)
        }
        .accessibilityHidden(true)
    }

    private func macroRing(progress: CGFloat, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 2.5)
                .frame(width: 22, height: 22)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(-90))
        }
    }

    private var personalizationRadar: some View {
        ZStack {
            RadarPolygonShape(values: Array(repeating: 1, count: profile.radarValues.count), scale: 1)
                .stroke(OnboardingTheme.border.opacity(0.35), lineWidth: 0.75)
                .frame(width: 44, height: 44)
            RadarPolygonShape(values: profile.radarValues, scale: 1)
                .fill(OnboardingTheme.accent.opacity(0.22))
                .overlay {
                    RadarPolygonShape(values: profile.radarValues, scale: 1)
                        .stroke(OnboardingTheme.accent.opacity(0.55), lineWidth: 1)
                }
                .frame(width: 44, height: 44)
        }
        .accessibilityHidden(true)
    }

    private func routeLayer(in size: CGSize) -> some View {
        let start = CGPoint(x: size.width * 0.14, y: size.height * 0.72)
        let end = routeEnd(in: size)
        let path = routePath(start: start, end: end, style: profile.style)
        let traveler = travelerPoint(
            start: start,
            end: end,
            progress: travelerProgress,
            style: profile.style
        )

        return ZStack {
            path
                .stroke(
                    OnboardingTheme.border.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5])
                )

            path
                .trim(from: 0, to: routeTrim)
                .stroke(
                    LinearGradient(
                        colors: [OnboardingTheme.accent.opacity(0.5), OnboardingTheme.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )

            routeNode(symbol: "figure.stand", label: profile.currentWeight, isOrigin: true)
                .position(start)

            targetNode
                .position(end)

            Circle()
                .fill(OnboardingTheme.accent)
                .frame(width: 7, height: 7)
                .shadow(color: OnboardingTheme.accent.opacity(0.45), radius: 4)
                .position(traveler)
        }
    }

    private func routeEnd(in size: CGSize) -> CGPoint {
        switch profile.style {
        case .loss:
            return CGPoint(x: size.width * 0.86, y: size.height * 0.82)
        case .gain:
            return CGPoint(x: size.width * 0.86, y: size.height * 0.58)
        case .maintain, .fallback:
            return CGPoint(x: size.width * 0.86, y: size.height * 0.7)
        }
    }

    private func routePath(
        start: CGPoint,
        end: CGPoint,
        style: OnboardingPlanBlueprintIllustrationStyle
    ) -> Path {
        Path { path in
            path.move(to: start)
            let control1: CGPoint
            let control2: CGPoint
            switch style {
            case .loss:
                control1 = CGPoint(x: start.x + (end.x - start.x) * 0.35, y: start.y - 18)
                control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y + 8)
            case .gain:
                control1 = CGPoint(x: start.x + (end.x - start.x) * 0.35, y: start.y - 8)
                control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y + 16)
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
        style: OnboardingPlanBlueprintIllustrationStyle
    ) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let control1: CGPoint
        let control2: CGPoint
        switch style {
        case .loss:
            control1 = CGPoint(x: start.x + (end.x - start.x) * 0.35, y: start.y - 18)
            control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y + 8)
        case .gain:
            control1 = CGPoint(x: start.x + (end.x - start.x) * 0.35, y: start.y - 8)
            control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y + 16)
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

    private func routeNode(symbol: String, label: String?, isOrigin: Bool) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isOrigin ? FormaTokens.Color.surfaceSubtle : FormaTokens.Color.accentMuted)
                    .frame(width: 28, height: 28)
                Image(systemName: symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isOrigin ? OnboardingTheme.secondaryText : OnboardingTheme.accent)
            }
            if let label, isOrigin {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
    }

    private var targetNode: some View {
        VStack(spacing: 2) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(OnboardingTheme.accent.opacity(0.22 - Double(index) * 0.05), lineWidth: 1)
                        .frame(width: 34 + CGFloat(index) * 8, height: 34 + CGFloat(index) * 8)
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                OnboardingTheme.accent.opacity(0.35),
                                OnboardingTheme.accent.opacity(0.08)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 18
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "scope")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(OnboardingTheme.accent)
            }
            Text(profile.targetWeight)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func particles(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(OnboardingTheme.accent.opacity(0.25 + Double(index) * 0.04))
                    .frame(width: 3, height: 3)
                    .offset(
                        x: particleOffset(for: index, axis: .horizontal, in: size),
                        y: particleOffset(for: index, axis: .vertical, in: size)
                    )
            }
        }
        .accessibilityHidden(true)
    }

    private enum ParticleAxis { case horizontal, vertical }

    private func particleOffset(for index: Int, axis: ParticleAxis, in size: CGSize) -> CGFloat {
        let base = CGFloat(index + 1) * 0.11
        let drift = reduceMotion ? 0 : sin((particlePhase + CGFloat(index)) * .pi) * 4
        switch axis {
        case .horizontal:
            return size.width * (0.28 + base) + drift - size.width * 0.5
        case .vertical:
            return size.height * (0.12 + base * 0.55) - drift - size.height * 0.5
        }
    }

    private var visualAccessibilityLabel: String {
        let direction: String
        switch profile.style {
        case .loss: direction = "Weight loss route"
        case .gain: direction = "Weight gain route"
        case .maintain: direction = "Maintain route"
        case .fallback: direction = "Personal route"
        }
        return "\(direction) to \(profile.targetWeight). Personalized nutrition rings and profile radar."
    }
}

private struct RadarPolygonShape: Shape {
    let values: [CGFloat]
    let scale: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.42 * scale
        let count = max(values.count, 3)
        var path = Path()

        for index in 0..<count {
            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
            let value = index < values.count ? min(max(values[index], 0.12), 1) : 0.12
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius * value,
                y: center.y + CGFloat(sin(angle)) * radius * value
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintVisualCanvas(
        profile: OnboardingPlanBlueprintBuilder.build(from: OnboardingPreviewData.formState).visualProfile
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
