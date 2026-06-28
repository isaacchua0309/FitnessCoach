# Fitness Coach — Test Suites

Tests are grouped with **Xcode Test Plans** under `TestPlans/`. The default **Fitness Coach** scheme runs the fast suite; CI should use the **Fitness Coach CI** scheme.

## Test plans

| Plan | Purpose | ~Classes | Typical runtime |
|------|---------|----------|-----------------|
| **Fast-Core** | Everyday local development | ~148 selections | ~30–90s |
| **Integration** | Bootstrap, cloud, auth handoff, SwiftData services, HealthKit mocks | ~63 selections | ~30–90s |
| **Full** | Complete regression (CI) | All (~154) | ~2–5 min |

### Fast-Core includes

- Calculation engines (`FormaCalculation*`, `WeightLossPace*`, nutrition builders)
- Onboarding state, copy guardrails, builders, and model navigation (no full `AppContainer` completion flows)
- Auth routing policy (`AuthGateRoutingPolicy`, `AppRouteResolver*`, `PublicEntry*`, shell resolvers)
- Profile mapping (`CloudUserProfileDocument`, ownership mapping)
- Today / Plan / Journey **pure state builders** and formatters
- Food logging builders and manual logging tests
- `CoachRoutingTests` **unit** methods only (routing/decider; no in-memory Coach integration)

### Integration includes

- Profile bootstrap & restore (`ProfileBootstrap*`, `ProfileRestoreRouting`, `CloudProfile*`)
- Cloud conflict & upload failure (`ProfilePlanConflict*`, `AccountProfileMismatch`, persistence safety)
- Onboarding completion & auth save (`OnboardingCompletion*`, `OnboardingAuthFlow`, `WelcomeOnboardingHandoff`)
- SwiftData service integration (`DailyLogServiceTests`, `FitnessActionCenterTests`)
- HealthKit / training integration mocks (`TrainingIntegration*`, `OnboardingAppleHealth*`, `AppleHealthTrainingStrategy*`)
- Full auth handoff (`AuthProfileRouteSafety*`, `SignOutHygiene`, `ExistingUserSignIn*`)
- Coach routing **integration** methods (`CoachRoutingTests/testLocalRegression…`, etc.)
- Manual QA checklist (`JourneyManualQAChecklistTests`)

### UI / snapshot

This target has **no dedicated snapshot framework**. Rendering guardrails (`TodayReadOnlyCompositionTests`, `OnboardingComponentsTests`, `PlanRationaleVisualFlowTests`) live in **Fast-Core** because they are fast state/copy checks.

---

## Xcode

1. Select scheme **Fitness Coach** (default test plan: **Fast-Core**).
2. **⌘U** runs the active test plan.
3. Test navigator → click the plan name at the top to switch between **Fast-Core**, **Integration**, and **Full**.

For CI / pre-merge: select scheme **Fitness Coach CI** (always runs **Full**).

---

## Command line

Simulator (adjust device name as needed):

```bash
DESTINATION='platform=iOS Simulator,name=iPhone 17'

# Fast — default for local dev (same as ⌘U on Fitness Coach scheme)
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core

# Integration only
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Integration

# Full regression — use CI scheme
xcodebuild test -scheme "Fitness Coach CI" -destination "$DESTINATION"

# Or explicit full plan on main scheme
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Full
```

Run a single class (any plan):

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" \
  -only-testing:"Fitness CoachTests/FormaCalculationEngineTests"
```

---

## Regenerating test plans

`TestPlans/*.xctestplan` are generated from filenames and a curated integration list. After adding test files, regenerate:

```bash
python3 Scripts/generate_test_plans.py
```

Then review diffs — add new files to `INTEGRATION_FILES` in that script when they need full harness / SwiftData / cloud wiring.

---

## Coverage

**Full** runs every test in `Fitness CoachTests`. Fast and Integration are **subsets**; together they cover the full suite with no tests removed from the target.

---

## Theme test suite (Fast-Core)

| Class | Covers |
|-------|--------|
| `AppAppearanceModeTests` | Raw values, display copy, settings options |
| `AppThemePaletteTests` | Palette IDs, corrupt fallback, persistence round-trip |
| `FormaPaletteCatalogTests` | All palettes × light/dark token completeness |
| `ThemeStoreTests` | Defaults, persistence, corrupt fallback, logout hygiene, shipping coercion |
| `ThemeResolverTests` | Palette → accent, appearance → resolved scheme, `preferredColorScheme` |
| `FormaThemeEnvironmentTests` | Root environment parity with `ThemeStore` |
| `ThemeSettingsViewTests` | Settings selection state, store wiring, matrix coverage |
| `HardcodedColorGuardTests` | No production `Color(...)` outside approved files |
| `PreferredColorSchemeGuardTests` | No forced `.preferredColorScheme(.dark)` outside root/previews |
| `OnboardingThemeTokenTests` | Onboarding CTA/progress/chart tokens + scoped guards |
| `PublicWelcomeThemeTests` | Public entry local theme, logout keeps palette |
| `MainTabThemeSmokeTests` | Main tab tokens under every palette + scoped guards |

Run the full theme suite:

```bash
xcodebuild test -scheme "Fitness Coach" -testPlan Fast-Core -destination "$DESTINATION" \
  -only-testing:"Fitness CoachTests/AppAppearanceModeTests" \
  -only-testing:"Fitness CoachTests/AppThemePaletteTests" \
  -only-testing:"Fitness CoachTests/FormaPaletteCatalogTests" \
  -only-testing:"Fitness CoachTests/ThemeStoreTests" \
  -only-testing:"Fitness CoachTests/ThemeResolverTests" \
  -only-testing:"Fitness CoachTests/FormaThemeEnvironmentTests" \
  -only-testing:"Fitness CoachTests/ThemeSettingsViewTests" \
  -only-testing:"Fitness CoachTests/HardcodedColorGuardTests" \
  -only-testing:"Fitness CoachTests/PreferredColorSchemeGuardTests" \
  -only-testing:"Fitness CoachTests/OnboardingThemeTokenTests" \
  -only-testing:"Fitness CoachTests/PublicWelcomeThemeTests" \
  -only-testing:"Fitness CoachTests/MainTabThemeSmokeTests"
```

Supplementary (also Fast-Core): `ThemeSettingsCopyGuardrailTests`, `ThemeAnalyticsTests`, `FormaPaletteAccessibilityTests`.

---

## Theme color guardrail

`HardcodedColorGuardTests` scans production Swift under `Fitness Coach/` and **fails CI** if disallowed color literals appear outside approved palette sources.

### Disallowed in production UI

- SwiftUI system colors: `.blue`, `.pink`, `.green`, `.red`, `.orange`, `.yellow`, `.black`, `.white`, `.gray`
- Raw constructors: `Color(red:`, `Color(hue:`, `Color(white:`, `UIColor(red:`, `UIColor.system*`
- Hex helpers: `Color(hex…)`, `Color(#…)`

### Approved raw-color files

- `FormaPaletteCatalog.swift` — palette definitions (sole `Color(red:)` source for themes)
- `FormaBrandColorTokens.swift` — Google Sign-In brand exceptions
- `FormaColorContrast.swift` — WCAG math (`UIColor` bridging only)

`#Preview` blocks in production files are skipped. Test targets are excluded.

### How to add a new color properly

1. **Add a semantic token** on `FormaColorPalette` (and `FormaThemeColors` / `FormaTokens.Color` when needed for static access).
2. **Define the value for every palette and appearance** in `FormaPaletteCatalog` (all `AppThemePalette` × light/dark).
3. **Use the token in UI** via `FormaTokens.Color.<token>` or `@Environment(\.formaColors)`.
4. **Update tests**: `FormaPaletteCatalogTests`, `FormaTokensColorTests`, and run `HardcodedColorGuardTests`.

Run locally:

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" \
  -only-testing:"Fitness CoachTests/HardcodedColorGuardTests"
```

If you must introduce a new approved raw-color file (e.g. another brand partner), add its filename to `HardcodedColorGuard.approvedFileNames` and document the exception in `FormaBrandColorTokens.swift`.

---

## Forced dark appearance guardrail

`PreferredColorSchemeGuardTests` fails when production Swift under `Fitness Coach/` contains `.preferredColorScheme(.dark)` outside the root theme resolver.

### Allowed

- `FormaThemeScreenModifier.swift` — single app-root appearance override from `ThemeStore`
- `FormaThemeEnvironment.swift` — `.formaThemePreview()` helper
- `#Preview` blocks — use `.formaThemePreview()` instead of hard-coded dark when possible
- `*PreviewScreens.swift` DEBUG hosts

### Rules

1. Do **not** force dark (or any scheme) on feature screens, sheets, or tabs.
2. Root wiring lives on `Fitness_CoachApp` → `.formaRootTheme(store:)`.
3. Settings/public/auth/onboarding inherit the active `ThemeStore` appearance and palette.

Run locally:

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" \
  -only-testing:"Fitness CoachTests/PreferredColorSchemeGuardTests"
```

---

## Light and System appearance (pre-release gating)

Light palettes and resolver wiring exist, but **Light** and **System** are hidden from Theme settings until visual QA completes.

| Layer | Status |
|-------|--------|
| Token catalog | All 3 palettes × light/dark in `FormaPaletteCatalog` |
| `preferredColorScheme` | `system` → `nil`, `light` → `.light`, `dark` → `.dark` at app root |
| Settings UI | Palette switching ships on **Dark**; appearance section hidden while `AppThemeShippingPolicy.shipsLightAndSystemAppearance == false` |
| Persisted light/system | Coerced to `.dark` on `ThemeStore` load when not shipped |

### Internal previews (DEBUG)

`FormaThemeAppearanceMatrixPreviews.swift` — six combinations:

- Default / Pink / Cool Blue × Light / Dark

Use Xcode canvas to spot-check Today, Welcome, Google sign-in, and segmented controls before flipping the shipping flag.

### Tests

- `FormaPaletteCatalogTests` — light text, borders, charts
- `ThemeStoreTests` — persistence, corrupt fallback, shipping-policy coercion, logout hygiene
- `ThemeSettingsViewTests` — settings wiring, selection state, appearance matrix coverage
- `PreferredColorSchemeGuardTests` — no forced dark outside root resolver/previews
- `FormaThemeEnvironmentTests` — resolver parity with `ThemeStore`

### Enabling Light/System for users

1. Review matrix previews in Xcode (all six combos).
2. Set `AppThemeShippingPolicy.shipsLightAndSystemAppearance = true`.
3. Appearance section reappears in Theme settings with all three modes.

### Remaining blockers (before flip)

- [ ] Full-screen visual QA across onboarding, coach, plan sheets (matrix covers Today + Welcome only).
- [ ] System appearance spot-check on device with mixed light/dark OS setting.
- [ ] Wheel pickers / rulers in onboarding on light backgrounds (token-backed; not in matrix yet).

Run locally:

```bash
xcodebuild test -scheme "Fitness Coach" -testPlan Fast-Core -destination "$DESTINATION" \
  -only-testing:"Fitness CoachTests/ThemeStoreTests" \
  -only-testing:"Fitness CoachTests/ThemeSettingsViewTests" \
  -only-testing:"Fitness CoachTests/PreferredColorSchemeGuardTests" \
  -only-testing:"Fitness CoachTests/FormaPaletteCatalogTests"
```

---

## Theme accessibility and contrast

Automated WCAG checks run in `FormaPaletteAccessibilityTests` (Fast-Core) via `FormaPaletteContrastAudit`.

### Contrast pairs validated (all palettes × light/dark)

| Pair | Minimum ratio |
|------|----------------|
| textPrimary on canvas | 4.5:1 (AA) |
| textSecondary on canvas | 3.0:1 (AA large text) |
| textPrimary on surface | 4.5:1 |
| textSecondary on surface | 4.5:1 |
| ctaText on ctaBackground | 4.5:1 |
| accent on canvas | 3.0:1 |
| chartPrimary on chart background (`progressTrack` over canvas) | 3.0:1 |
| textPrimary on selected background | 4.5:1 |
| selectedBorder on selected background | 1.5:1 |

Surfaces, selected fills, and chart backgrounds are **alpha-composited over canvas** before measuring.

### Selection accessibility (non-color cues)

Theme settings rows use **checkmark + border + “selected” label + `.isSelected` trait** (`ThemeSettingsSelectionAccessibilityPolicy`).

Onboarding selectors use checkmarks and/or borders; sex pills now show a checkmark when selected.

### System accessibility settings

| Setting | Support |
|---------|---------|
| VoiceOver | Per-screen labels; theme tokens do not block |
| Dynamic Type | `FormaTokens.Typography` where used |
| Reduce Motion | Onboarding defers to `accessibilityReduceMotion` |
| Increased Contrast | **Not yet** — see `ThemeAccessibilityAdaptationPolicy.increasedContrastTODO` |
| Reduce Transparency | **Not yet** — see `ThemeAccessibilityAdaptationPolicy.reduceTransparencyTODO` |

Run locally:

```bash
xcodebuild test -scheme "Fitness Coach" -testPlan Fast-Core -destination "$DESTINATION" \
  -only-testing:"Fitness CoachTests/FormaPaletteAccessibilityTests"
```
