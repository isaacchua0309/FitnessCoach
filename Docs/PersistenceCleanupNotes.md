# Persistence Cleanup Notes

Stage 13–14 audit of SwiftData entities. **Schema is unchanged** — this document tracks dormant tables, why they remain registered, and what is required before removal.

## Dormant entities

| Entity | Status | Created today? | Read today? | UI |
|--------|--------|----------------|-------------|-----|
| `WeeklyReviewEntity` | Schema-only | No | No | No |
| `ChatMessageEntity` | Schema-only | No | No | No (Coach uses in-memory `ChatMessage`) |
| `DebugRecordEntity` | Schema-only (disk writes disabled) | No | No | No (Settings uses in-memory `FitPilotPipelineTracer`) |
| `ExerciseSetEntity` | Legacy child of manual workouts | Only via deprecated `addWorkout` | No dedicated API callers | No |
| `WorkoutEntryEntity` | Legacy reads active | Rarely (tests; deprecated write path) | Yes — Today streaks, Coach context, daily review | Indirect (streaks / focus only) |

### Active entities (not dormant)

`UserProfileEntity`, `DailyLogEntity`, `FoodEntryEntity`, `WaterEntryEntity`, `WeightEntryEntity`, `DailyReviewEntity` — core product persistence.

---

## Why dormant entities remain in schema

SwiftData requires every on-disk model type to stay listed in `FitPilotModelContainer.schema` until a **versioned migration** removes the table. Dropping an entity without migration causes store open failures for existing installs.

| Entity | Why kept |
|--------|----------|
| `WeeklyReviewEntity` | Orphan schema; Journey **This week** is computed in-memory via `JourneyWeeklyReviewBuilder` + `DailyLog` (see [JourneyArchitecture.md](./JourneyArchitecture.md)). Entity kept until migration removes table. |
| `ChatMessageEntity` | Reserved for Coach conversation persistence across app restarts. |
| `DebugRecordEntity` | Reserved for optional persisted pipeline error logs; in-memory tracing is sufficient today. |
| `WorkoutEntryEntity` / `ExerciseSetEntity` | Historical manual workout rows on user devices; Today streaks and daily-review workout summaries still read SwiftData workouts. |

---

## Future migration options

### Option A — Lightweight migration (remove empty tables)

Suitable when **no user rows** exist or data loss is acceptable:

1. `WeeklyReviewEntity`
2. `ChatMessageEntity`
3. `DebugRecordEntity` (after confirming no DEBUG rows in the wild)

Steps: bump model version, remove types from `FitPilotModelContainer.schema`, ship lightweight migration or document one-time store reset for internal builds.

### Option B — Feature completion (keep table, wire service)

| Entity | Work |
|--------|------|
| `WeeklyReviewEntity` | **Not planned:** remove via Option A migration when product signs off (Journey uses log-derived weekly review, not persisted `WeeklyReviewEntity`). |
| `ChatMessageEntity` | Persist/load Coach thread in `CoachModel`; define retention policy. |
| `DebugRecordEntity` | Re-enable `PipelineTracePersistence` and surface rows in Settings diagnostics. |

### Option C — Legacy workout retirement (highest risk)

1. Product sign-off: Apple Health is the sole training source.
2. Migrate or drop historical `WorkoutEntryEntity` / `ExerciseSetEntity` rows.
3. Rewire Today streaks and `ReviewService` workout summaries to HealthKit only.
4. Remove `WorkoutLogService` write paths and eventually the entities from schema.

---

## Deletion requirements

Before removing **any** entity from `FitPilotModelContainer.schema`:

- [ ] Product decision recorded (weekly review, chat persistence, manual workouts).
- [ ] Grep confirms zero `insert` / `FetchDescriptor` / relationship usage for that type.
- [ ] Migration plan: model version bump + lightweight or custom migration.
- [ ] QA on upgrade from previous App Store build (existing SQLite store).
- [ ] Tests updated; no orphaned domain models or mapping files left without purpose.
- [ ] `Docs/DeadCodeAudit.md` and this file updated.

**Do not** delete user rows in production without explicit migration or export.

---

## Stage 14 code cleanup (no schema change)

| Change | Rationale |
|--------|-----------|
| Entity header docs + `TODO(migration)` on dormant types | Explains schema retention |
| Deprecated `WorkoutLogService.addWorkout` / `deleteWorkout` | Writes retired; reads remain |
| Removed `getWorkoutDetail` / `getExerciseSets` | Unreachable APIs |
| Removed unused `WorkoutLogService.save()` | Dead code |
| Removed `workoutLogService` from `ProgressModel` | Journey uses Apple Health only |
| Disabled `PipelineTracePersistence` disk writes | Write-only orphan data; in-memory tracer unchanged |

---

## Open product decisions

1. **Weekly review entity** — remove `WeeklyReviewEntity` via migration (Journey weekly review is log-derived; no AI recap) or keep dormant indefinitely?
2. **Coach chat history** — persist across launches or keep session-only?
3. **Manual workouts** — when can Today streaks stop reading SwiftData workouts?
4. **Debug persistence** — re-enable disk archival for Settings or remove entity?
