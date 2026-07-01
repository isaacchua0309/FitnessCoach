# Persistence Cleanup Notes

Stage 13–14 audit of SwiftData entities, updated after **Tier 4 (2026-06-30)** schema v3 migration.

## Active schema (`FormaSchemaV3`)

| Entity | Role |
|--------|------|
| `UserProfileEntity` | Profile and plan targets |
| `DailyLogEntity` | Day-scoped aggregates (no legacy workout child rows) |
| `FoodEntryEntity`, `WaterEntryEntity`, `WeightEntryEntity` | Logging |
| `DailyReviewEntity` | Coach daily review persistence |

Training activity reads **Apple Health only** via `HealthActivityQueryService`. `DailyLog.workoutCaloriesBurned` remains a summary field but is no longer derived from SwiftData workout rows.

---

## Removed in v3 migration (`FormaSchemaV2` → `FormaSchemaV3`)

| Entity / relationship | Why removed |
|---------------------|-------------|
| `WorkoutEntryEntity` | Manual workout logging retired; HealthKit is sole training source |
| `ExerciseSetEntity` | Child of legacy manual workouts |
| `DailyLogEntity.workoutEntries` | No legacy workout aggregation in `DailyLogService` |

Entity class files remain for **v2 migration only** (`FormaSchemaV2.models`).

---

## Removed in v2 migration (`FormaSchemaV1` → `FormaSchemaV2`)

| Entity | Why removed |
|--------|-------------|
| `WeeklyReviewEntity` | Journey weekly review is log-derived |
| `ChatMessageEntity` | Coach chat stays in memory |
| `DebugRecordEntity` | In-memory pipeline tracing only |

---

## Open product decisions

1. **Coach chat history** — persist across launches or keep session-only?
2. **Debug persistence** — reintroduce disk archival for Settings or keep in-memory only?

---

## Tier history

| Tier | Change |
|------|--------|
| Tier 4 | `FormaSchemaV3`; Plan dashboard dead fields removed; workout domain dead code removed |
| Tier 3 | Read-protocol adoption across feature models |
| Tier 2 | `FormaSchemaV2`; `WorkoutLogService` removed; HealthKit-only training reads |
| Tier 1 | Repository protocols; Onboarding decomposition; Coach nutrition SSOT |
