# Persistence Cleanup Notes

Stage 13–14 audit of SwiftData entities, updated after **Tier 2 (2026-06-30)** schema v2 migration.

## Active schema (`FormaSchemaV2`)

| Entity | Role |
|--------|------|
| `UserProfileEntity` | Profile and plan targets |
| `DailyLogEntity` | Day-scoped aggregates |
| `FoodEntryEntity`, `WaterEntryEntity`, `WeightEntryEntity` | Logging |
| `WorkoutEntryEntity`, `ExerciseSetEntity` | Legacy manual workout rows on disk (no app reads) |
| `DailyReviewEntity` | Coach daily review persistence |

Training activity (Today streaks, daily review workout summary, Coach context) reads **Apple Health only** via `HealthActivityQueryService`.

---

## Removed in v2 migration (`FormaSchemaV1` → `FormaSchemaV2`)

Lightweight migration via `FormaMigrationPlan` drops these tables on upgrade:

| Entity | Why removed |
|--------|-------------|
| `WeeklyReviewEntity` | Journey **This week** is computed in-memory via `JourneyWeeklyReviewBuilder` + `DailyLog` |
| `ChatMessageEntity` | Coach keeps `ChatMessage` values in memory (`CoachModel.messages`) |
| `DebugRecordEntity` | Pipeline diagnostics use in-memory `FormaPipelineTracer` buffers |

Entity class files remain in the repo **for v1 migration only** (`FormaSchemaV1.models`). Mapping files and `WeeklyReview` domain model were deleted.

---

## Legacy workout tables (still on disk)

| Entity | Status |
|--------|--------|
| `WorkoutEntryEntity` | Historical rows may exist; no production read/write service |
| `ExerciseSetEntity` | Child of legacy manual workouts |

`DailyLogServiceTestSupport.seedWorkoutEntry()` still inserts entities directly for daily-log recalculation tests.

### Option C — Full legacy workout retirement (future)

1. Product sign-off on dropping historical manual workout rows.
2. Custom migration or export for users with legacy data.
3. Remove `WorkoutEntryEntity` / `ExerciseSetEntity` from schema.

---

## Deletion requirements (future entity removal)

Before removing **any** entity from `FormaSchemaV2`:

- [ ] Product decision recorded.
- [ ] Grep confirms zero `insert` / `FetchDescriptor` / relationship usage.
- [ ] Migration plan: model version bump + lightweight or custom migration.
- [ ] QA on upgrade from previous App Store build.
- [ ] Tests updated; no orphaned domain models or mapping files.
- [ ] `Docs/DeadCodeAudit.md` and this file updated.

---

## Tier 2 code cleanup (2026-06-30)

| Change | Rationale |
|--------|-----------|
| `FormaSchemaV2` + `FormaMigrationPlan` | Drops dormant v1 tables |
| Removed `WorkoutLogService` | Training reads from HealthKit only |
| `DailyTrainingActivity` + extended `HealthActivityQueryService` | Shared read-model for Today, reviews, Coach |
| `ReviewService` / `TodayModel` / `CoachModel` wired to `healthActivityQuery` | Retire SwiftData workout reads |
| Deleted dormant mapping files + `WeeklyReview.swift` | No longer referenced after v2 |
| `PipelineTracePersistence` stub retained | DEBUG install hook; disk writes stay disabled |

---

## Open product decisions

1. **Coach chat history** — persist across launches or keep session-only?
2. **Legacy workout rows** — when to migrate/drop `WorkoutEntryEntity` / `ExerciseSetEntity`?
3. **Debug persistence** — reintroduce disk archival for Settings or keep in-memory only?
