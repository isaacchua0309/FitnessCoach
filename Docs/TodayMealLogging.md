# Today meal logging

## Primary path

Today routes **new** meal logs through **Coach**:

- Fast log → Log Meal → `CoachLaunchIntent.logMeal`
- Next Best Action meal CTAs → Coach with optional meal type
- Meals preview **Add** → Coach with meal type
- Scan Meal (when available) → Coach photo flow

## Manual meal form (fallback / editing only)

`FoodEntryFormView` and `FoodEntryFormState` remain in the codebase. The manual meal form is **not** the primary logging surface on Today.

| Surface | Mode | User-facing title | When |
|--------|------|-------------------|------|
| `TodayEditFoodEntrySheet` | `editNutrition` | Edit nutrition | User edits a logged Today entry |
| `AIFoodConfirmationSheet` | Coach multi-component form | Edit nutrition | User corrects a Coach estimate before logging |
| `TodayLogMealSheet` | `createCustomFood` | Create custom food | **Not presented from Today UI** — tests, debug, programmatic fallback |

Save paths (`TodayActionCoordinator.saveMeal`, `saveFoodEdit`, `CoachModel.saveFoodEdit`) are intentionally retained.

## Today refresh after Coach meal save

Coach persists meals through `FitnessActionCenter.logFood`, which bumps `AppRefreshCenter.refreshToken`. Today stays in sync through:

1. **`TodayView`** — listens for `refreshToken` changes and reloads the dashboard (calories, protein, meals, next best action).
2. **`MainTabView`** — holds one `TodayActionCoordinator` for the tab lifetime (snackbar/water optimistic UI must not reset on re-render). When the user returns to the Today tab or the app becomes active, calls `TodayModel.refresh()` so a mounted-but-hidden Today surface always reflects the latest log.
3. **Failed saves** — `CoachMutationExecutor.executeLogFood` only calls `logFood` on success; failed confirmations do not bump `refreshToken` or change Today totals.
4. **Duplicate guard** — `CoachModel.confirmPendingFromBar` ignores re-entrant confirms while a save is in flight.

Trace with Console filter `CoachTodaySync` (subsystem `FitPilot`). In DEBUG, set `FITPILOT_COACH_TODAY_SYNC_TRACE=0` to silence.

## Do not add

- Manual Entry (or equivalent) as a visible Today quick action
- Sheet presentation of `TodayLogMealSheet` from `TodayView` for primary logging
