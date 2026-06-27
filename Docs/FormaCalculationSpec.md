# Forma Calculation Specification

**Version:** 1.0 (Stage 1 — written spec only)  
**Status:** Canonical target behavior for Forma’s deterministic plan engine  
**Scope:** Daily calorie target, macro targets, water target, weight-loss pace, safety validation, and plan explainability  

This document defines how Forma **should** calculate and explain user targets. It does not describe temporary gaps in the current app implementation. Code changes follow in later stages.

---

## 1. Design principles

1. **Deterministic** — Same inputs always produce the same outputs. No AI in this path.
2. **Pure functions** — All formulas live in calculator modules, not SwiftUI views or feature models.
3. **Explainable** — Every output number must trace back to named inputs and intermediate steps.
4. **Safe by default** — Unrealistic pace or infeasible macros produce warnings; the strongest cases block application until the user adjusts.
5. **Goal-aware** — Cut, maintain, and gain use the same energy model but different surplus/deficit semantics.

---

## 2. Inputs

### 2.1 Required inputs

| Input | Type | Units | Used for |
|-------|------|-------|----------|
| `age` | `Int` | years | BMR |
| `sex` | enum | — | BMR sex offset |
| `heightCm` | `Double` | cm | BMR |
| `weightKg` | `Double` | kg | BMR uses current weight; macros and water use current weight |
| `goalWeightKg` | `Double` | kg | Goal direction (cut / maintain / gain); pace validation context |
| `activityLevel` | enum | — | TDEE multiplier |
| `trainingFrequencyPerWeek` | `Int` | sessions/week | TDEE adjustment |
| `averageSteps` | `Int` | steps/day | TDEE adjustment |

### 2.2 Optional inputs

| Input | Type | Units | Used for |
|-------|------|-------|----------|
| `bodyFatPercent` | `Double?` | % (0–80) | Explainability copy; future lean-mass adjustments (not in v1.0 energy formula) |
| `dietPreference` | `String?` | — | Coach copy and meal suggestions only; **does not** change calorie or macro math in v1.0 |

### 2.3 Pace / strategy inputs

| Input | Type | Description |
|-------|------|-------------|
| `paceMode` | enum | `presetGentle` \| `presetModerate` \| `presetAggressive` \| `advancedWeeklyKg` \| `advancedMonthlyKg` \| `advancedGoalDate` (future) |
| `preset` | enum | Maps to body-weight % per week when `paceMode` is a preset |
| `targetWeeklyLossKg` | `Double?` | Required when `paceMode == advancedWeeklyKg` |
| `targetMonthlyLossKg` | `Double?` | Required when `paceMode == advancedMonthlyKg` |
| `targetGoalDate` | `Date?` | Reserved for future goal-date-driven pace |

### 2.4 Input validation (structural)

Before any calculation:

- `age` > 0
- `heightCm` > 0
- `weightKg` > 0
- `goalWeightKg` > 0
- `trainingFrequencyPerWeek` ≥ 0
- `averageSteps` ≥ 0
- If `bodyFatPercent` is present: `0 ≤ bodyFatPercent ≤ 80`

Structural validation rejects the calculation. Safety validation (Section 5) may warn or block after math runs.

### 2.5 Goal direction

Derived from current vs goal weight:

```
goalDeltaKg = goalWeightKg - weightKg

if goalDeltaKg < -0.5  → cut (fat loss)
if goalDeltaKg > +0.5  → gain (muscle / weight gain)
else                   → maintain
```

The ±0.5 kg buffer avoids flickering strategy labels for trivial differences.

---

## 3. Energy calculation

### 3.1 BMR — Mifflin–St Jeor (metric)

```
BMR = 10 × weightKg + 6.25 × heightCm − 5 × age + sexOffset
```

| `sex` | `sexOffset` |
|-------|-------------|
| male | +5 |
| female | −161 |
| other, preferNotToSay | −78 (midpoint of male/female offsets) |

Result is rounded to the nearest whole kcal: `bmrKcal = round(BMR)`.

**Assumptions**

- Current body weight (`weightKg`) is the BMR weight basis during a cut.
- Mifflin–St Jeor is used for all users in v1.0; Katch–McArdle (lean mass) is deferred until `bodyFatPercent` is incorporated into energy math.

### 3.2 TDEE — activity multiplier + refinements

**Base TDEE**

```
tdeeKcal = bmrKcal × activityMultiplier(activityLevel)
```

| `activityLevel` | Multiplier |
|-----------------|------------|
| sedentary | 1.20 |
| lightlyActive | 1.375 |
| moderatelyActive | 1.55 |
| veryActive | 1.725 |
| athlete | 1.90 |

**Activity refinements** (applied on top of the multiplier; may be revisited in a later version to reduce double-counting):

```
stepBonusKcal    = max(averageSteps − 5000, 0) ÷ 1000 × 30
trainingBonusKcal = trainingFrequencyPerWeek × 20

tdeeKcal = round(tdeeKcal + stepBonusKcal + trainingBonusKcal)
```

**Assumptions**

- PAL multipliers follow standard Mifflin–St Jeor activity factors.
- Step and training bonuses are small nudges for inputs not fully captured by the coarse activity level.
- TDEE represents estimated total daily energy expenditure on a typical day.

### 3.3 From loss rate to daily deficit

Weight change is modeled with a single energy-density constant:

```
kcalPerKgFat = 7700
```

**Weekly loss from daily deficit**

```
weeklyLossKg = (dailyDeficitKcal × 7) ÷ kcalPerKgFat
```

**Daily deficit from weekly loss** (inverse; used for presets and advanced pace)

```
dailyDeficitKcal = (weeklyLossKg × kcalPerKgFat) ÷ 7
```

Result is rounded to the nearest whole kcal for display and target application.

### 3.4 Calorie target

**Cut**

```
requestedDeficitKcal = dailyDeficitFromPace(...)   // Section 4
rawCalorieTarget     = tdeeKcal − requestedDeficitKcal
calorieTarget        = max(rawCalorieTarget, calorieFloor)   // Section 5
appliedDeficitKcal   = tdeeKcal − calorieTarget
```

If the calorie floor binds, `appliedDeficitKcal < requestedDeficitKcal` and the **achievable** weekly loss must be recomputed from `appliedDeficitKcal`.

**Maintain**

```
calorieTarget      = tdeeKcal
appliedDeficitKcal = 0
```

**Gain**

```
surplusKcal        = dailySurplusFromPace(...)   // mirror of deficit; future detail
calorieTarget      = tdeeKcal + surplusKcal
appliedDeficitKcal = −surplusKcal
```

Gain surplus presets are out of scope for v1.0 pace tables; maintain and gain paths are defined here so the model is complete. Implementation may ship cut-only first.

---

## 4. Weight-loss pace

### 4.1 Presets (% of body weight per week)

Presets derive **target weekly loss in kg** from current body weight, then convert to a daily deficit (Section 3.3).

| Preset | Label (product) | `weeklyLossPercent` | `weeklyLossKg` |
|--------|-----------------|---------------------|----------------|
| Gentle | Conservative | 0.25% / week | `weightKg × 0.0025` |
| Moderate | Moderate | 0.50% / week | `weightKg × 0.0050` |
| Aggressive | Aggressive | 0.75% / week | `weightKg × 0.0075` |

```
weeklyLossKg  = weightKg × weeklyLossPercent
dailyDeficitKcal = round((weeklyLossKg × 7700) ÷ 7)
```

**Example** — 80 kg user, Moderate preset:

```
weeklyLossKg     = 80 × 0.005 = 0.40 kg/week
dailyDeficitKcal = round((0.40 × 7700) ÷ 7) = round(440) = 440 kcal/day
```

Presets scale with body size: larger users get larger absolute deficits for the same relative pace.

### 4.2 Advanced pace

| Mode | User provides | Derivation |
|------|---------------|------------|
| `advancedWeeklyKg` | `targetWeeklyLossKg` | `dailyDeficitKcal = round((targetWeeklyLossKg × 7700) ÷ 7)` |
| `advancedMonthlyKg` | `targetMonthlyLossKg` | `weeklyLossKg = targetMonthlyLossKg ÷ (30.4375 / 7)` then same as weekly |
| `advancedGoalDate` | `targetGoalDate` | **Future.** `remainingKg = weightKg − goalWeightKg`, `weeksRemaining = daysUntilGoal ÷ 7`, `weeklyLossKg = remainingKg ÷ weeksRemaining` |

For monthly input, use average month length `30.4375` days unless the product later uses calendar months explicitly.

Advanced mode is only valid when `goalDirection == cut` and `targetWeeklyLossKg > 0` (or equivalent for monthly).

### 4.3 Mapping legacy enum names

Until schema migration, existing `CalorieAggressiveness` values map to presets:

| Stored value | Spec preset |
|--------------|-------------|
| `conservative` | Gentle (0.25% / week) |
| `moderate` | Moderate (0.50% / week) |
| `aggressive` | Aggressive (0.75% / week) |

---

## 5. Safety validation

Safety runs after raw targets are computed. Outputs are structured warnings with severity.

### 5.1 Pace relative to body weight

Let:

```
weeklyLossPercentActual = (weeklyLossKg ÷ weightKg) × 100
```

Use **requested** weekly loss before the calorie floor for warnings; use **applied** weekly loss when reporting achievable pace after the floor binds.

| Condition | Severity | Behavior |
|-----------|----------|----------|
| `weeklyLossPercentActual > 0.75%` and ≤ `1.0%` | **Warn** | Show caution; user may proceed |
| `weeklyLossPercentActual > 1.0%` | **Strong warning** | Prominent warning; recommend reducing pace; block in onboarding until user confirms or adjusts (product choice in UI stage) |
| `appliedDeficitKcal ÷ tdeeKcal > 0.25` | **Warn** | Deficit exceeds 25% of TDEE |
| Calorie floor binds | **Warn** | Actual pace is slower than requested; explain adjusted deficit |

### 5.2 Calorie floor

Minimum calorie targets after deficit application:

| `sex` | Floor (kcal/day) |
|-------|------------------|
| female | 1200 |
| male | 1500 |
| other, preferNotToSay | 1350 (midpoint) |

Additional rule: `calorieTarget` must not fall below `bmrKcal × 1.1` when that value is **higher** than the sex floor (protects very small or very active users).

```
calorieFloor = max(sexFloor, round(bmrKcal × 1.1))
calorieTarget = max(rawCalorieTarget, calorieFloor)
```

### 5.3 Macro feasibility

After protein and fat floors are assigned (Section 6):

```
proteinKcal = proteinG × 4
fatKcal     = fatG × 9
remainingKcal = calorieTarget − proteinKcal − fatKcal
carbG         = max(remainingKcal ÷ 4, 0)
```

| Condition | Severity | Behavior |
|-----------|----------|----------|
| `remainingKcal < 0` | **Error** | Protein + fat exceed calorie budget; reduce protein toward floor or increase calories |
| `carbG < 50` on a cut | **Warn** | Very low carbohydrate allowance; may be hard to sustain |
| `carbG == 0` | **Strong warning** | No carb budget remains; suggest reducing protein toward floor or slowing pace |

### 5.4 Goal consistency

| Condition | Severity |
|-----------|----------|
| `goalDirection == gain` and pace mode is a loss preset | **Warn** — pace ignored or surplus used |
| `goalDirection == maintain` and loss preset selected | **Warn** — suggest maintain mode |
| `goalWeightKg ≥ weightKg` and `targetWeeklyLossKg > 0` | **Error** — incompatible |

### 5.5 Input plausibility (recommended bounds)

Soft warnings only; do not block unless values are structurally invalid.

| Input | Suggested range |
|-------|-----------------|
| `age` | 16–80 |
| `heightCm` | 120–230 |
| `weightKg` | 35–250 |
| `bodyFatPercent` | 5–60 |

---

## 6. Protein calculation

Protein is set **before** fat and carbs. Use current `weightKg`.

### 6.1 Base ranges (g/kg/day)

| Context | Range (g/kg) | Default in range |
|---------|--------------|------------------|
| General / maintain | 1.6 – 2.0 | 1.8 |
| Fat loss + strength training (`trainingFrequencyPerWeek ≥ 2`) | 1.8 – 2.2 | 2.0 |
| Aggressive cut (`weeklyLossPercent ≥ 0.75%`) | 2.0 – 2.4 | 2.2 |

### 6.2 Selection rule

```
if goalDirection == cut && trainingFrequencyPerWeek >= 2:
    if weeklyLossPercent >= 0.0075:
        proteinGPerKg = 2.2    // aggressive cut default
    else:
        proteinGPerKg = 2.0    // fat loss + strength default
else if goalDirection == cut:
    proteinGPerKg = 1.8
else:
    proteinGPerKg = 1.8        // general default

proteinG = round(weightKg × proteinGPerKg)
```

### 6.3 Caps and floors

| Rule | Value |
|------|-------|
| Absolute floor | `1.6 g/kg` (never go below for health messaging) |
| Absolute cap | `2.4 g/kg` or `250 g`, whichever is lower |
| Hard maximum | `min(round(weightKg × 2.4), 250)` |

If protein at the chosen g/kg makes `carbG == 0` (Section 5.3), step down in 0.1 g/kg increments until `carbG ≥ 50` or the floor `1.6 g/kg` is reached, then surface a feasibility warning.

**Assumptions**

- `dietPreference` does not change the protein g/kg selection in v1.0.
- `bodyFatPercent` does not switch to lean-mass protein targets in v1.0.

---

## 7. Fat and carbohydrate calculation

### 7.1 Order of allocation

1. **Protein** — Section 6  
2. **Fat minimum** — hormonal / essential floor  
3. **Carbohydrates** — all remaining calories  

### 7.2 Fat minimum

```
fatGPerKg = 0.8
fatG      = round(weightKg × fatGPerKg)
```

Fat is not reduced below `0.8 g/kg` unless a feasibility error requires stepping down (same pattern as protein), minimum absolute floor `0.6 g/kg`.

### 7.3 Carbohydrates

```
proteinKcal = proteinG × 4
fatKcal     = fatG × 9
carbG       = max(round((calorieTarget − proteinKcal − fatKcal) ÷ 4), 0)
```

**Assumptions**

- Standard Atwater factors: protein 4 kcal/g, carbohydrate 4 kcal/g, fat 9 kcal/g.
- No fiber or alcohol adjustments in v1.0.

---

## 8. Water calculation

### 8.1 Base formula

```
waterMl = round(weightKg × 35)
```

### 8.2 Adjustments

| Condition | Adjustment |
|-----------|------------|
| Workout day | `+ 500 ml` |
| Sedentary + `averageSteps < 4000` | optional `− 200 ml` (product discretion) |

### 8.3 Bounds

| Bound | Value |
|-------|-------|
| Minimum | `2000 ml` |
| Maximum | `5000 ml` |

```
waterTargetMl = clamp(round(weightKg × 35) + adjustments, 2000, 5000)
```

**Assumptions**

- Water target uses current `weightKg`.
- Workout-day bump applies only when the product marks the day as a training day (not in static plan generation).

---

## 9. Explainability

Every generated plan must produce a `PlanCalculationExplanation` (name TBD in code) with machine-readable steps and human-readable strings.

### 9.1 Required explanation fields

| Field | Source |
|-------|--------|
| `bmrKcal` | Section 3.1 — show formula inputs |
| `tdeeKcal` | Section 3.2 — show multiplier, step bonus, training bonus |
| `selectedLossRate` | Preset name or advanced value (e.g. `0.50% body weight/week` or `0.45 kg/week`) |
| `requestedDailyDeficitKcal` | Before floor |
| `appliedDailyDeficitKcal` | After floor |
| `calorieTargetKcal` | Final target |
| `proteinTargetG` | g/kg used and total grams |
| `fatTargetG` | g/kg used and total grams |
| `carbTargetG` | Derived remainder |
| `waterTargetMl` | Base, adjustments, clamps |
| `expectedWeeklyLossKg` | From **applied** deficit |
| `warnings` | All Section 5 items triggered |

### 9.2 Explanation templates (human-readable)

**BMR**

> Your estimated resting burn (BMR) is **{bmrKcal} kcal/day**, based on age {age}, height {heightCm} cm, weight {weightKg} kg, and sex.

**TDEE**

> With **{activityLevel}** activity, about **{averageSteps}** daily steps, and **{trainingFrequency}** training sessions per week, your estimated maintenance (TDEE) is **{tdeeKcal} kcal/day**.

**Loss rate**

> You chose a **{presetName}** pace targeting about **{weeklyLossKg} kg/week** ({weeklyLossPercent}% of body weight).

**Daily deficit**

> That implies a **{requestedDailyDeficitKcal} kcal/day** deficit. After safety limits, your plan uses **{appliedDailyDeficitKcal} kcal/day**.

**Calorie target**

> Daily calorie target: **{calorieTargetKcal} kcal** (= TDEE − applied deficit).

**Protein**

> Protein target: **{proteinTargetG} g** ({proteinGPerKg} g/kg) to support recovery during {goalDirection}.

**Water**

> Water target: **{waterTargetMl} ml** (~35 ml per kg body weight{workoutDaySuffix}).

### 9.3 Persistence

BMR, TDEE, and explanation snapshots may be persisted in a later schema version. v1.0 spec requires them on every **generation** event even if not yet stored long-term.

---

## 10. Constants reference

| Constant | Value | Notes |
|----------|-------|-------|
| `kcalPerKgFat` | 7700 | Energy per kg weight change |
| `kcalPerGProtein` | 4 | |
| `kcalPerGCarb` | 4 | |
| `kcalPerGFat` | 9 | |
| `mlPerKgWater` | 35 | |
| `fatGPerKgMin` | 0.8 | |
| `stepBaseline` | 5000 | Steps below this add no bonus |
| `kcalPer1000Steps` | 30 | |
| `kcalPerTrainingSessionWeek` | 20 | |
| `workoutWaterBonusMl` | 500 | |
| `waterMinMl` | 2000 | |
| `waterMaxMl` | 5000 | |
| `goalDirectionEpsilonKg` | 0.5 | |
| `maxDeficitFractionOfTDEE` | 0.25 | Warning threshold |
| `paceWarnPercent` | 0.75% body weight/week | |
| `paceStrongWarnPercent` | 1.0% body weight/week | |
| `minCarbWarnG` | 50 | On cuts |

---

## 11. Worked example

**Inputs**

- Male, 30 years, 180 cm, 82 kg, goal 75 kg  
- `moderatelyActive`, 3 training sessions/week, 6000 steps  
- Preset: Moderate (0.50% / week)  

**BMR**

```
BMR = 10×82 + 6.25×180 − 5×30 + 5 = 820 + 1125 − 150 + 5 = 1800 kcal
```

**TDEE**

```
Base     = 1800 × 1.55 = 2790
Steps    = (6000−5000)/1000 × 30 = 30
Training = 3 × 20 = 60
TDEE     = 2790 + 30 + 60 = 2880 kcal
```

**Pace**

```
weeklyLossKg     = 82 × 0.005 = 0.41 kg/week
dailyDeficit     = round(0.41 × 7700 / 7) = round(451) = 451 kcal
```

**Calories**

```
rawTarget  = 2880 − 451 = 2429
floor      = max(1500, round(1800×1.1)) = max(1500, 1980) = 1980
target     = 2429 (floor not binding)
appliedDef = 451 kcal
```

**Macros**

```
protein = round(82 × 2.0) = 164 g   (cut + training)
fat     = round(82 × 0.8) = 66 g
carbs   = round((2429 − 164×4 − 66×9) / 4) = round(605/4) = 151 g
```

**Water**

```
water = clamp(round(82 × 35), 2000, 5000) = 2870 ml
```

**Explainability**

- BMR 1800 → TDEE 2880 → Moderate 0.41 kg/week → deficit 451 → target 2429 kcal  
- Protein 164 g, fat 66 g, carbs 151 g, water 2870 ml  

---

## 12. Implementation notes (non-normative)

This section records known gaps between the **current app** and this spec. It is informational only and may be removed once implementation catches up.

| Area | Current behavior | Spec (this document) |
|------|------------------|----------------------|
| Pace presets | Fixed deficits: 300 / 500 / 750 kcal | % body weight: 0.25% / 0.50% / 0.75% per week |
| `goalWeightKg` | Collected, unused in math | Drives goal direction and validation |
| `bodyFatPercent` | Collected, unused in math | Explainability only in v1.0 |
| Calorie floor | 1200 for all | Sex-specific + 110% BMR rule |
| Protein | Fixed 2.0 g/kg | Contextual 1.6–2.4 g/kg |
| Advanced pace | Not implemented | Weekly / monthly / goal date |
| Explainability | Partial UI + template copy | Structured `PlanCalculationExplanation` |
| Calculator tests | None | Required before behavior change |

---

## 13. Change log

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-06-27 | Initial written specification (Stage 1) |
