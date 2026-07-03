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

## Do not add

- Manual Entry (or equivalent) as a visible Today quick action
- Sheet presentation of `TodayLogMealSheet` from `TodayView` for primary logging
