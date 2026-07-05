//
//  MainTabHeroText.swift
//  Fitness Coach
//
//  Forma — Shared large display typography for main tab hero metrics and goals.
//

import SwiftUI

struct MainTabHeroText: View {
    let text: String
    var tier: Tier = .primary
    var color: Color?
    var lineLimit: Int?
    var addsHeaderTrait: Bool = true

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat

    enum Tier {
        /// Dominant tab hero — e.g. Today "2,080 remaining".
        case primary
        /// Strategic goal headline — e.g. Plan "Lose 14.5 kg".
        case goal
        /// In-card metric highlight — e.g. Plan "2080 kcal".
        case metric
        /// Journey transformation hero message.
        case narrative

        var baseSize: CGFloat {
            switch self {
            case .primary: return 48
            case .goal: return 40
            case .metric: return 30
            case .narrative: return 34
            }
        }

        var relativeTo: Font.TextStyle {
            switch self {
            case .primary, .goal, .narrative:
                return .largeTitle
            case .metric:
                return .title
            }
        }

        var defaultLineLimit: Int {
            switch self {
            case .primary: return 1
            case .goal: return 2
            case .metric: return 2
            case .narrative: return 3
            }
        }

        var minimumScaleFactor: CGFloat {
            switch self {
            case .primary: return 0.55
            case .goal: return 0.65
            case .metric: return 0.70
            case .narrative: return 0.72
            }
        }
    }

    init(
        _ text: String,
        tier: Tier = .primary,
        color: Color? = nil,
        lineLimit: Int? = nil,
        addsHeaderTrait: Bool = true
    ) {
        self.text = text
        self.tier = tier
        self.color = color
        self.lineLimit = lineLimit
        self.addsHeaderTrait = addsHeaderTrait
        _fontSize = ScaledMetric(wrappedValue: tier.baseSize, relativeTo: tier.relativeTo)
    }

    var body: some View {
        let _ = themeManager.themeRevision

        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(color ?? theme.primaryText)
            .lineLimit(resolvedLineLimit)
            .minimumScaleFactor(tier.minimumScaleFactor)
            .allowsTightening(true)
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(addsHeaderTrait ? .isHeader : [])
    }

    private var resolvedLineLimit: Int {
        lineLimit ?? tier.defaultLineLimit
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
        MainTabHeroText("2,080 remaining", tier: .primary)
        MainTabHeroText("Lose 14.5 kg", tier: .goal)
        MainTabHeroText("2080 kcal", tier: .metric)
        MainTabHeroText("You're building momentum", tier: .narrative)
    }
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
