# Coach Timeline Context v2 — Architecture

**Status:** Production (2026-07-03)  
**Schema version:** `CoachContextPacketV2.meta.schemaVersion == 2`

## Purpose

Coach Timeline Context v2 gives the AI gateway structured, authoritative context for routing, estimates, and coaching — without changing where nutrition truth lives.

## Source of truth boundaries

| Layer | Owns | Does not own |
|-------|------|----------------|
| **SwiftData log services** | Food, water, weight entries; daily aggregates | Chat prose, AI estimates |
| **Coach timeline store** | Audit/context events (messages, estimates, confirmations, health signals) | Committed nutrition totals |
| **CoachContextPacketV2** | Read-only snapshot for AI | Any mutable app state |
| **Firebase aiGateway** | Stateless inference | User data persistence |

Coach mutations always flow:

```
CoachModel → CoachMutationExecutor → FitnessActionCenter → Food/Water/WeightLogService → SwiftData
```

Timeline recording is **best-effort** and **non-blocking**. A timeline write failure must never prevent logging or chat.

## Context assembly

`CoachContextPacketV2Builder` reads authoritative state and assembles:

- `today` — from `DailyLogService` + log services (not from chat or timeline)
- `recentMealsStructured` / `commonFoods` — from `FoodLogService` history
- `timeline.recentEvents` — selected confirmed mutations, pending confirmations, photo pipeline, workouts/steps
- `recentChatMessages` — tone/continuity only; never nutrition truth
- `missingData` — explicit gaps (steps unavailable ≠ zero steps; no workout ≠ permission denied)

`CoachContextCorrectnessValidator` runs outbound and corrects aggregate drift (e.g. calories must match confirmed food only).

## Timeline event lifecycle

| Status | Counts as logged? | In AI context? |
|--------|-------------------|----------------|
| `confirmed` | Yes (if mutation type) | Yes (mutations, workouts, steps) |
| `pending` | No | Only `pendingConfirmationCreated` |
| `rejected` | No | No |
| `failed` | No | No |
| `superseded` | No (replaced) | No |

Edit/delete call `CoachTimelineStore.supersedeEvent` so prior `foodLogged` rows are marked `superseded`.

## Performance limits

| Limit | Value |
|-------|-------|
| Timeline events in context | 20 (builder), 40 (transport clamp), 24 KB JSON ceiling |
| Store query cap | 250 events per day/range/recent fetch |
| Backfill lookback | 7 days; throttled to once per 60s during context builds |
| Chat messages in context | 12 |

Backfill runs on context build only — **not** on app launch.

## Health semantics

- `training.workoutsToday == 0` — HealthKit available, confirmed no workouts today
- `training.workoutsToday == nil` — permission denied or Health unavailable (unknown)
- `missingData.stepsMissing` — no step value; distinct from zero steps

## Privacy

- No raw images in timeline payloads (`PhotoPayload` metadata only)
- No secrets in `coachContextLogFields` or `redactedDebugDescription`
- Gateway strips unknown top-level keys before prompt embedding

## Feature flags

There is **no AB gate** for timeline v2. Production path is always `CoachContextPacketV2` when Coach AI is enabled (`aiCommandParsingEnabled` + wired `contextPacketBuilder`).

`generationMode` values:

- `live` — full reads succeeded
- `degraded` — partial read/permission failures; packet still sent with `missingData`
- `preview` / `backfill` — tests and tooling only

## Key files

| Component | Path |
|-----------|------|
| Context builder | `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` |
| Validator | `Fitness Coach/Application/StateBuilders/Coach/CoachContextCorrectnessValidator.swift` |
| Timeline recorder | `Fitness Coach/Application/UseCases/CoachTimeline/CoachTimelineRecorder.swift` |
| Timeline store | `Fitness Coach/Application/Services/CoachTimelineStore.swift` |
| Backfill | `Fitness Coach/Application/Services/CoachTimelineBackfillService.swift` |
| Gateway validation | `functions/src/coachContextPacketV2.ts` |
| Prompt rules | `functions/src/coachContextPromptRules.ts` |

## Related docs

- [COACH_CONTEXT_PACKET_V2.md](./COACH_CONTEXT_PACKET_V2.md) — field reference
- [COACH_TIMELINE_V2_MIGRATION.md](./COACH_TIMELINE_V2_MIGRATION.md) — migration notes
- [COACH_TIMELINE_V2_PRE_IMPLEMENTATION_AUDIT.md](./COACH_TIMELINE_V2_PRE_IMPLEMENTATION_AUDIT.md) — historical audit
