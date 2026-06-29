//
//  PremiumWeightRulerScrollView.swift
//  Fitness Coach
//
//  Forma — Custom horizontal weight ruler with tiered ticks and proximity styling.
//

import SwiftHorizontalRuler
import SwiftUI
import UIKit

/// Local math mirror of `HorizontalRulerConfig` internals (package keeps helpers module-private).
enum PremiumWeightRulerMath {
    static func tickCount(config: HorizontalRulerConfig) -> Int {
        Int((config.maxValue - config.minValue) / config.minorIncrement) + 1
    }

    static func minorTicksPerMajor(config: HorizontalRulerConfig) -> Int {
        max(1, Int(config.majorIncrement / config.minorIncrement))
    }

    static func contentX(for value: Double, config: HorizontalRulerConfig) -> CGFloat {
        CGFloat((value - config.minValue) / config.minorIncrement) * config.tickSpacing
    }

    static func value(atContentX x: CGFloat, config: HorizontalRulerConfig) -> Double {
        clampAndRound(
            config.minValue + Double(x / config.tickSpacing) * config.minorIncrement,
            config: config
        )
    }

    static func clampAndRound(_ value: Double, config: HorizontalRulerConfig) -> Double {
        let clamped = min(max(value, config.minValue), config.maxValue)
        return (clamped / config.minorIncrement).rounded() * config.minorIncrement
    }
}

/// UIKit ruler with tiered ticks, proximity styling, and tick snapping.
final class PremiumWeightRulerScrollView: UIView {

    // MARK: - Public API

    var onValueChanged: ((Double) -> Void)?

    var isDragging: Bool { scrollView.isDragging }
    var isDecelerating: Bool { scrollView.isDecelerating }

    var currentValue: Double {
        guard bounds.width > 0 else { return config.minValue }
        let centerContentX = scrollView.contentOffset.x + bounds.width / 2
        return PremiumWeightRulerMath.value(atContentX: centerContentX, config: config)
    }

    func setValue(_ value: Double, animated: Bool) {
        let snapped = PremiumWeightRulerMath.clampAndRound(value, config: config)
        lastReportedValue = snapped
        guard bounds.width > 0 else {
            pendingInitialValue = snapped
            return
        }
        let offset = PremiumWeightRulerMath.contentX(for: snapped, config: config) - bounds.width / 2
        scrollView.setContentOffset(CGPoint(x: offset, y: 0), animated: animated)
    }

    // MARK: - Private state

    fileprivate enum TickTier {
        case minor
        case medium
        case major
    }

    private struct TickItem {
        let index: Int
        let value: Double
        let tier: TickTier
        let x: CGFloat
        let lineLayer: CAShapeLayer
        let labelLayer: CATextLayer?
    }

    private let config: HorizontalRulerConfig
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let centerIndicatorView = PremiumWeightRulerCenterIndicatorView()
    private var tickItems: [TickItem] = []
    private var pendingInitialValue: Double?
    private var hasBuiltContent = false
    private var lastCenterTickIndex = -1
    private var lastReportedValue: Double?

    // MARK: - Init

    init(config: HorizontalRulerConfig) {
        self.config = config
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        setupScrollView()
        setupAccessibility()
        registerForTraitChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        let centerX = bounds.width / 2
        let contentWidth = CGFloat(PremiumWeightRulerMath.tickCount(config: config)) * config.tickSpacing

        scrollView.frame = bounds
        scrollView.contentSize = CGSize(width: contentWidth, height: bounds.height)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: centerX, bottom: 0, right: centerX)
        contentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: bounds.height)
        centerIndicatorView.frame = bounds
        centerIndicatorView.setNeedsLayout()

        if !hasBuiltContent {
            hasBuiltContent = true
            buildTicks()
        }

        if let value = pendingInitialValue {
            pendingInitialValue = nil
            let snapped = PremiumWeightRulerMath.clampAndRound(value, config: config)
            lastReportedValue = snapped
            let offset = PremiumWeightRulerMath.contentX(for: snapped, config: config) - centerX
            scrollView.contentOffset = CGPoint(x: offset, y: 0)
        }

        refreshTickAppearance()
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.decelerationRate = .fast
        scrollView.backgroundColor = .clear
        scrollView.isOpaque = false
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.backgroundColor = .clear
        addSubview(centerIndicatorView)
        centerIndicatorView.isUserInteractionEnabled = false
        centerIndicatorView.applyTheme()
    }

    private func setupAccessibility() {
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
    }

    private func registerForTraitChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: PremiumWeightRulerScrollView, _: UITraitCollection) in
            view.centerIndicatorView.applyTheme()
            view.refreshTickAppearance(forceFullPass: true)
        }
    }

    // MARK: - Tick construction

    private func buildTicks() {
        tickItems.removeAll()
        contentView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let stepsPerMajor = max(1, PremiumWeightRulerMath.minorTicksPerMajor(config: config))
        let mediumStep = stepsPerMajor / 2
        let baselineY = OnboardingLayout.premiumRulerTickBaselineY
        let labelBaselineY = baselineY + OnboardingLayout.premiumRulerLabelTopMargin

        for index in 0..<PremiumWeightRulerMath.tickCount(config: config) {
            let value = config.minValue + Double(index) * config.minorIncrement
            let x = CGFloat(index) * config.tickSpacing
            let tier = tickTier(forIndex: index, stepsPerMajor: stepsPerMajor, mediumStep: mediumStep)
            let height = tickHeight(for: tier, isCenter: false)

            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: baselineY))
            path.addLine(to: CGPoint(x: x, y: baselineY - height))

            let lineLayer = CAShapeLayer()
            lineLayer.path = path.cgPath
            lineLayer.fillColor = nil
            lineLayer.lineCap = .round
            lineLayer.lineWidth = tickLineWidth(for: tier)
            lineLayer.contentsScale = traitCollection.displayScale
            contentView.layer.addSublayer(lineLayer)

            var labelLayer: CATextLayer?
            if tier == .major {
                let label = makeLabelLayer(text: config.labelFormatter(value))
                let labelSize = label.rulerLabelFrameSize()
                label.frame = CGRect(
                    x: x - labelSize.width / 2,
                    y: labelBaselineY,
                    width: labelSize.width,
                    height: labelSize.height
                )
                contentView.layer.addSublayer(label)
                labelLayer = label
            }

            tickItems.append(
                TickItem(
                    index: index,
                    value: value,
                    tier: tier,
                    x: x,
                    lineLayer: lineLayer,
                    labelLayer: labelLayer
                )
            )
        }
    }

    private func tickTier(forIndex index: Int, stepsPerMajor: Int, mediumStep: Int) -> TickTier {
        let position = index % stepsPerMajor
        if position == 0 {
            return .major
        }
        if mediumStep > 0, position == mediumStep {
            return .medium
        }
        return .minor
    }

    private func tickHeight(for tier: TickTier, isCenter: Bool) -> CGFloat {
        if isCenter {
            return OnboardingLayout.premiumRulerCenterTickHeight
        }
        switch tier {
        case .minor:
            return OnboardingLayout.premiumRulerMinorTickHeight
        case .medium:
            return OnboardingLayout.premiumRulerMediumTickHeight
        case .major:
            return OnboardingLayout.premiumRulerMajorTickHeight
        }
    }

    private func tickLineWidth(for tier: TickTier, isCenter: Bool = false) -> CGFloat {
        if isCenter {
            return OnboardingLayout.premiumRulerCenterTickLineWidth
        }
        switch tier {
        case .minor:
            return 1
        case .medium:
            return 1.25
        case .major:
            return 1.5
        }
    }

    private func makeLabelLayer(text: String) -> CATextLayer {
        let font = UIFont.systemFont(
            ofSize: OnboardingLayout.premiumRulerLabelFontSize,
            weight: .medium
        )
        let label = CATextLayer()
        label.string = text
        label.font = font
        label.fontSize = OnboardingLayout.premiumRulerLabelFontSize
        label.alignmentMode = .center
        label.contentsScale = traitCollection.displayScale
        return label
    }

    // MARK: - Appearance

    private func refreshTickAppearance(forceFullPass: Bool = false) {
        guard bounds.width > 0, !tickItems.isEmpty else { return }

        let centerContentX = scrollView.contentOffset.x + bounds.width / 2
        let centerIndex = centerContentX / config.tickSpacing
        let centerTickIndex = Int(centerIndex.rounded())
        let centerChanged = centerTickIndex != lastCenterTickIndex

        let palette = PremiumWeightRulerTickPalette.current
        let baselineY = OnboardingLayout.premiumRulerTickBaselineY
        let proximityWindow = Int(ceil(OnboardingLayout.premiumRulerProximityFalloffTicks)) + 2
        let lower = max(0, centerTickIndex - proximityWindow)
        let upper = min(tickItems.count - 1, centerTickIndex + proximityWindow)

        if forceFullPass {
            for item in tickItems {
                applyTickAppearance(
                    to: item,
                    centerIndex: centerIndex,
                    centerTickIndex: centerTickIndex,
                    baselineY: baselineY,
                    palette: palette,
                    centerChanged: true
                )
            }
        } else {
            if centerChanged, lastCenterTickIndex >= 0, lastCenterTickIndex < tickItems.count {
                let previousIndex = lastCenterTickIndex
                if previousIndex < lower || previousIndex > upper {
                    applyTickAppearance(
                        to: tickItems[previousIndex],
                        centerIndex: centerIndex,
                        centerTickIndex: centerTickIndex,
                        baselineY: baselineY,
                        palette: palette,
                        centerChanged: true
                    )
                }
            }

            for index in lower...upper {
                applyTickAppearance(
                    to: tickItems[index],
                    centerIndex: centerIndex,
                    centerTickIndex: centerTickIndex,
                    baselineY: baselineY,
                    palette: palette,
                    centerChanged: centerChanged
                )
            }
        }

        if centerChanged {
            centerIndicatorView.playSelectionPulse()
            lastCenterTickIndex = centerTickIndex
        }
    }

    private func applyTickAppearance(
        to item: TickItem,
        centerIndex: CGFloat,
        centerTickIndex: Int,
        baselineY: CGFloat,
        palette: PremiumWeightRulerTickPalette.Colors,
        centerChanged: Bool
    ) {
        let distance = abs(CGFloat(item.index) - centerIndex)
        let isCenter = item.index == centerTickIndex
        let proximity = proximityMultiplier(forDistance: distance)

        if isCenter {
            if centerChanged {
                updateTickPath(
                    for: item,
                    baselineY: baselineY,
                    height: tickHeight(for: item.tier, isCenter: true)
                )
            }
            item.lineLayer.strokeColor = palette.centerTick.cgColor
            item.lineLayer.lineWidth = tickLineWidth(for: item.tier, isCenter: true)
            item.lineLayer.opacity = 1
        } else {
            if centerChanged, item.index == lastCenterTickIndex {
                updateTickPath(
                    for: item,
                    baselineY: baselineY,
                    height: tickHeight(for: item.tier, isCenter: false)
                )
            }
            let base = palette.color(for: item.tier)
            item.lineLayer.strokeColor = base.withMultipliedAlpha(proximity).cgColor
            item.lineLayer.lineWidth = tickLineWidth(for: item.tier)
            item.lineLayer.opacity = 1
        }

        if let labelLayer = item.labelLayer {
            let labelProximity = proximityMultiplier(forDistance: distance)
            let labelAlpha = palette.majorLabelAlpha * labelProximity
            labelLayer.foregroundColor = palette.majorLabel
                .withAlphaComponent(labelAlpha)
                .cgColor
        }
    }

    private func updateTickPath(for item: TickItem, baselineY: CGFloat, height: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: item.x, y: baselineY))
        path.addLine(to: CGPoint(x: item.x, y: baselineY - height))
        item.lineLayer.path = path.cgPath
    }

    /// Brighter near the center indicator, dimmer toward the edges.
    private func proximityMultiplier(forDistance distance: CGFloat) -> CGFloat {
        let falloff = OnboardingLayout.premiumRulerProximityFalloffTicks
        let normalized = min(distance / falloff, 1)
        let minimum = OnboardingLayout.premiumRulerFarTickOpacity
        return minimum + (1 - minimum) * (1 - normalized)
    }

    // MARK: - Accessibility

    override var accessibilityValue: String? {
        get { config.labelFormatter(currentValue) }
        set {}
    }

    override func accessibilityIncrement() {
        let newValue = min(currentValue + config.minorIncrement, config.maxValue)
        setValue(newValue, animated: true)
        onValueChanged?(PremiumWeightRulerMath.clampAndRound(newValue, config: config))
    }

    override func accessibilityDecrement() {
        let newValue = max(currentValue - config.minorIncrement, config.minValue)
        setValue(newValue, animated: true)
        onValueChanged?(PremiumWeightRulerMath.clampAndRound(newValue, config: config))
    }
}

// MARK: - UIScrollViewDelegate

extension PremiumWeightRulerScrollView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard bounds.width > 0 else { return }
        refreshTickAppearance()
        reportValueIfChanged()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        reportValueIfChanged(force: true)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        reportValueIfChanged(force: true)
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let centerX = bounds.width / 2
        let targetContentX = targetContentOffset.pointee.x + centerX
        let snappedX = (targetContentX / config.tickSpacing).rounded() * config.tickSpacing
        targetContentOffset.pointee.x = snappedX - centerX
    }

    /// Emits only when the snapped tick value changes — avoids SwiftUI churn on every scroll frame.
    private func reportValueIfChanged(force: Bool = false) {
        let value = currentValue
        if !force, value == lastReportedValue { return }
        lastReportedValue = value
        onValueChanged?(value)
    }
}

// MARK: - Palette

private enum PremiumWeightRulerTickPalette {
    struct Colors {
        let accent: UIColor
        let centerTick: UIColor
        let minor: UIColor
        let medium: UIColor
        let major: UIColor
        let majorLabel: UIColor
        let majorLabelAlpha: CGFloat

        func color(for tier: PremiumWeightRulerScrollView.TickTier) -> UIColor {
            switch tier {
            case .minor: minor
            case .medium: medium
            case .major: major
            }
        }
    }

    @MainActor
    static var current: Colors {
        Colors(
            accent: uiColor(OnboardingTheme.progress),
            centerTick: uiColor(OnboardingTheme.secondaryText).withAlphaComponent(0.88),
            minor: uiColor(OnboardingTheme.border).withAlphaComponent(0.30),
            medium: uiColor(OnboardingTheme.secondaryText).withAlphaComponent(0.50),
            major: uiColor(OnboardingTheme.secondaryText).withAlphaComponent(0.78),
            majorLabel: uiColor(OnboardingTheme.tertiaryText),
            majorLabelAlpha: 0.95
        )
    }

    @MainActor
    private static func uiColor(_ color: Color) -> UIColor {
        UIColor(color)
    }
}

private extension CATextLayer {
    func rulerLabelFrameSize() -> CGSize {
        guard let text = string as? String else {
            return .zero
        }
        let font = UIFont.systemFont(
            ofSize: OnboardingLayout.premiumRulerLabelFontSize,
            weight: .medium
        )
        return (text as NSString).size(withAttributes: [.font: font])
    }
}

private extension UIColor {
    func withMultipliedAlpha(_ factor: CGFloat) -> UIColor {
        var alpha: CGFloat = 0
        if getWhite(nil, alpha: &alpha) {
            return withAlphaComponent(alpha * factor)
        }
        getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return withAlphaComponent(alpha * factor)
    }
}

// MARK: - Fixed center indicator

/// Static overlay pinned to the ruler center — does not scroll with ticks.
private final class PremiumWeightRulerCenterIndicatorView: UIView {
    private let glowLayer = CAGradientLayer()
    private let lineLayer = CALayer()
    private let markerLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        layer.addSublayer(glowLayer)
        layer.addSublayer(lineLayer)
        layer.addSublayer(markerLayer)
        glowLayer.startPoint = CGPoint(x: 0, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 0.5)
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        let centerX = bounds.midX
        let markerHeight = OnboardingLayout.premiumRulerMarkerHeight
        let lineTop = markerHeight
        let lineBottom = OnboardingLayout.premiumRulerTickBaselineY
        let lineHeight = max(0, lineBottom - lineTop)
        let glowWidth = OnboardingLayout.premiumRulerCenterGlowWidth
        let lineWidth = OnboardingLayout.premiumRulerCenterIndicatorLineWidth

        glowLayer.frame = CGRect(
            x: centerX - glowWidth / 2,
            y: lineTop,
            width: glowWidth,
            height: lineHeight
        )

        lineLayer.frame = CGRect(
            x: centerX - lineWidth / 2,
            y: lineTop,
            width: lineWidth,
            height: lineHeight
        )

        let markerPath = UIBezierPath()
        markerPath.move(to: CGPoint(x: centerX, y: markerHeight))
        markerPath.addLine(to: CGPoint(x: centerX - 7, y: 0))
        markerPath.addLine(to: CGPoint(x: centerX + 7, y: 0))
        markerPath.close()
        markerLayer.path = markerPath.cgPath
        markerLayer.frame = bounds
    }

    @MainActor
    func applyTheme() {
        let accent = UIColor(OnboardingTheme.progress)
        let peak = OnboardingLayout.premiumRulerCenterGlowPeakOpacity
        glowLayer.colors = [
            accent.withAlphaComponent(0).cgColor,
            accent.withAlphaComponent(peak).cgColor,
            accent.withAlphaComponent(0).cgColor
        ]
        glowLayer.locations = [0, 0.5, 1]
        lineLayer.backgroundColor = accent.cgColor
        markerLayer.fillColor = accent.cgColor
    }

    /// Brief glow emphasis when the snapped tick index changes — no timers, no SwiftUI invalidation.
    func playSelectionPulse() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.85
        animation.toValue = 1
        animation.duration = 0.16
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        glowLayer.add(animation, forKey: "selectionPulse")
    }
}
