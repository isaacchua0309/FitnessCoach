# Coach Keyboard + Pending Food Card Layout

Fix for transcript overlap when the pending calorie estimate card and keyboard are both visible.

## Root cause

The pending confirmation bar and composer lived outside the transcript `ScrollView` safe-area inset. When the keyboard opened, the scroll region did not shrink reliably and the expanded pending card could cover messages.

## Layout contract

```
CoachView
└── VStack + themed background
    └── CoachConversationView
        ├── ScrollView (coach.chat.scroll)
        │   └── LazyVStack + anchor id: coach-transcript-bottom
        └── safeAreaInset(edge: .bottom):
            └── VStack
                ├── CoachErrorView (when present)
                └── CoachBottomAccessoryStack
                    ├── CoachConfirmationBar (expanded | compact)
                    └── CoachComposer (coach.input.textfield)
```

**Rules**

1. Bottom chrome (pending card + composer) is always injected through `safeAreaInset` on the transcript `ScrollView` — never bottom overlays or manual keyboard padding.
2. Pending food card presentation:
   - Keyboard closed → **expanded** (full summary + Edit / Discard / Log).
   - Composer focused → **compact** (title + calorie line + actions). Edit hides at accessibility Dynamic Type; Discard and Log stay tappable.
3. Auto-scroll follows `CoachConversationScrollCoordinator`: always on user send and pending-card appear; otherwise only when the user is within 96pt of the bottom. Focus/blur waits 50–100ms for layout to settle.
4. Colors resolve from `CoachDesignTokens` / `FormaThemeAccess` on each read so theme changes apply without relaunch.

## Changed files

| File | Role |
|------|------|
| `CoachView.swift` | Wires bottom accessory; edit-tap behavior in compact vs expanded mode |
| `CoachConversationView.swift` | `safeAreaInset`, scroll coordination, dismiss-keyboard tap |
| `CoachBottomAccessoryStack.swift` | Unified pending card + composer chrome |
| `CoachConfirmationBar.swift` | Expanded/compact layouts, accessibility IDs |
| `CoachComposer.swift` | Input bar (background owned by stack) |
| `CoachPendingFoodCardPresentation.swift` | Presentation resolver |
| `CoachPendingConfirmation.swift` | Compact copy helpers |
| `CoachConversationScrollCoordinator.swift` | Near-bottom scroll policy |
| `CoachAccessibilityIdentifiers.swift` | Stable IDs for UI tests |
| `CoachLayoutPreviewFixtures.swift` | Seeded transcript + pending card |
| `CoachLayoutPreviewScreens.swift` | DEBUG layout previews |
| `CoachLayoutGuard.swift` + tests | Blocks layout regressions |
| `CoachPendingFoodCardLayoutRegressionTests.swift` | Presentation + discard/log/edit flows |
| `CoachConversationScrollCoordinatorTests.swift` | Scroll policy unit tests |
| `CoachPendingConfirmationFormattingTests.swift` | Compact copy tests |

## Manual QA checklist

1. **Basic chat** — input stays above keyboard; send keeps latest message visible.
2. **Pending card, keyboard closed** — card above composer; transcript not under card; Log / Edit / Discard work.
3. **Pending card, keyboard open** — compact card; transcript readable; Log + Discard tappable; dismiss keyboard restores expanded card.
4. **Long response** — scroll naturally; no text hidden behind card.
5. **Small screen** (e.g. iPhone SE) — no overlap; compact card fits.
6. **Large Dynamic Type** — compact lines scale/truncate; Discard + Log remain usable.
7. **Theme change** — pending card and composer update immediately.
8. **Tab switch** — pending state preserved; layout still correct on return.

## Verification (macOS)

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:Fitness\ CoachTests/CoachLayoutGuardTests \
  -only-testing:Fitness\ CoachTests/CoachPendingFoodCardPresentationTests \
  -only-testing:Fitness\ CoachTests/CoachPendingFoodCardLayoutRegressionTests \
  -only-testing:Fitness\ CoachTests/CoachConversationScrollCoordinatorTests \
  -only-testing:Fitness\ CoachTests/CoachPendingConfirmationFormattingTests
```

In Xcode: open `CoachLayoutPreviewScreens` previews (Expanded, Compact, Compact Accessibility Type).
