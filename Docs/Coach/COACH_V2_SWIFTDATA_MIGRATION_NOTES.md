# Coach Timeline Context v2 — SwiftData Migration Notes

Last updated: 2026-07-04

## Active schema

| Version | Identifier | Coach v2 additions |
|---------|------------|-------------------|
| V5 | `6.0.0` step 4→5 | `CoachTimelineEventEntity` |
| V6 | `6.0.0` step 5→6 | `CoachChatTranscriptMessageEntity` (current) |

Current container: `FormaSchemaV6` via `FormaModelContainer` + `FormaMigrationPlan`.

### Schema registration (verified)

- `CoachTimelineEventEntity` is registered in `FormaSchemaV5` and retained in `FormaSchemaV6`.
- `CoachChatTranscriptMessageEntity` is registered in `FormaSchemaV6` only.
- Legacy `ChatMessageEntity` remains in `FormaSchemaV1` only and is removed at the V1→V2 lightweight stage. It does **not** conflict with `CoachChatTranscriptMessageEntity`.

## Migration strategy

All schema hops use **`MigrationStage.lightweight`** only:

1. V1 → V2 — drops legacy chat, workout, debug tables
2. V2 → V3 — drops workout/exercise set tables
3. V3 → V4 — property-only bump (same model list)
4. V4 → V5 — adds timeline table (empty for existing users)
5. V5 → V6 — adds transcript table (empty for existing users)

Nutrition SSOT entities (`DailyLogEntity`, `FoodEntryEntity`, `WaterEntryEntity`, `WeightEntryEntity`) are unchanged across V4→V6.

## Post-migration hydration (not migration-time)

Timeline and transcript history are **not** copied during SwiftData migration.

| Data | Upgrade behavior |
|------|------------------|
| Food / water / weight logs | Preserved; unchanged |
| Legacy V1 chat rows | Dropped at V1→V2 (historical) |
| Coach timeline | Empty after V5; hydrated by `CoachTimelineBackfillService` |
| Coach transcript | Empty after V6; populated by live Coach usage |

### Backfill

- Runs after migration via:
  - `AppContainer` launch task (non-blocking)
  - `CoachContextPacketV2Builder.makeContext()` (throttled, 60s minimum interval)
- Window: today + previous 7 calendar days
- Sources: food/water/weight logs + HealthKit workouts/steps when available
- Idempotent: deduplicates by `(type, localDate, linkedEntryId)` with 60s timestamp tolerance
- Failures: logged, non-throwing; never blocks Coach UI or AI send flow

## Migration gate (`FormaSwiftDataMigrationGate`)

Maintenance operations are gated until the V6 container opens successfully:

| Operation | Gated? |
|-----------|--------|
| Transcript prune on `loadMessages()` | Yes |
| Timeline `deleteEventsOlderThan()` | Yes |
| Timeline backfill | Yes |

Gate is set in:

- `FormaModelContainer.makeContainer()` after successful open
- `FormaModelContainer.migrateContainer(at:)` after on-disk upgrade

Legacy seed containers (`makeLegacyContainer`) do **not** mark the gate.

## Safe decode rules

Timeline rows use `CoachTimelineEventEntity.toModelSafe()`:

- Unknown `eventTypeRaw` → `.unknown`
- Corrupt / non-JSON `payloadJSON` → `.empty` payload (no throw)
- Future envelope versions are clamped to the current codec version

This prevents malformed persisted payloads from crashing reads during or after migration.

## Coach resilience

| Failure | Behavior |
|---------|----------|
| Transcript load/save error | Returns `[]` / logs; Coach UI continues |
| Timeline read error in context builder | Returns `[]`, increments read failure count |
| Timeline recorder append error | Fire-and-forget; logged; user action not blocked |
| Backfill error | Logged; non-throwing |

## Test coverage

`CoachV2SwiftDataMigrationTests` + `FormaSwiftDataMigrationTestSupport`:

| Scenario | Test |
|----------|------|
| Fresh install current schema | `testFreshInstallCurrentSchemaInitializesEmptyCoachTables` |
| Pre-V4 store → V6 | `testPreV4StoreMigratesToCurrentSchemaAndPreservesNutritionLogs` |
| Store with logs but no timeline | Same (asserts 0 timeline/transcript rows, logs preserved) |
| Malformed timeline payload | `testStoreWithMalformedTimelinePayloadDecodesSafelyAfterMigration` |
| Legacy V1 chat + logs → V6 | `testPreV1StoreWithLegacyChatMigratesWithoutConflict` |
| Repeated backfill | `testRepeatedBackfillAfterMigrationDoesNotDuplicateEvents` |
| Nutrition entities preserved | `testPreV4StoreMigratesToCurrentSchemaAndPreservesNutritionLogs` |
| Empty transcript store | `testTranscriptStoreHandlesEmptyStoreWithoutCrashing` |
| Pruning after migration | `testTranscriptPruningSkippedUntilMigrationComplete`, `testTimelineCompactionSkippedUntilMigrationComplete` |
| Backfill gated pre-migration | `testBackfillDoesNotRunBeforeMigrationComplete` |
| Schema registration | `testCoachV2EntitiesRegisteredInActiveSchema` |

Run locally:

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:Fitness\ CoachTests/CoachV2SwiftDataMigrationTests
```

## Known limitations

1. **No custom migration stages** — future non-additive schema changes require `MigrationStage.custom`.
2. **V1 chat history is not migrated** to the v6 transcript table (removed years ago at V2).
3. **Backfill window is 8 days** — older logs remain in SSOT but are not replayed into timeline.
4. **On-disk migration tests use temporary store URLs** — device upgrade QA should still validate against the last App Store build.

## Files

| File | Purpose |
|------|---------|
| `FormaModelMigration.swift` | Versioned schemas + lightweight plan |
| `FormaModelContainer.swift` | Container factory + legacy/migrate helpers |
| `FormaSwiftDataMigrationGate.swift` | Post-migration maintenance gate |
| `CoachTimelineEventPayloadCodec.swift` | Safe payload envelope codec |
| `CoachTimelineBackfillService.swift` | Idempotent post-migration hydration |
| `CoachV2SwiftDataMigrationTests.swift` | Migration regression tests |
