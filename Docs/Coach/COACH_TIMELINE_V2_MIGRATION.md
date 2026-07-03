# Coach Timeline Context v2 — Migration Notes

## Summary

Legacy compact `AIContext` / `CoachAIContextBuilder` have been removed from the active Coach AI path. All gateway endpoints now accept `CoachContextPacketV2` (`meta.schemaVersion: 2`).

## What changed

| Before | After |
|--------|-------|
| Compact `AIContext` (today-centric, 6 meals, 5 chat turns) | Full `CoachContextPacketV2` with timeline, structured meals, missingData |
| Chat transcript in-memory only | SwiftData `CoachChatTranscriptStore` + timeline events |
| No mutation audit trail for AI | `CoachTimelineStore` records user/assistant/mutation events |
| Photo analysis without structured context | `AIMealImageAnalysisRequest.context` uses v2 packet |

## What did **not** change

- Food/water/weight logging still goes through `FitnessActionCenter` → log services
- User confirmation still required before food is committed
- Firebase gateway remains stateless
- No feature flag — v2 is the only production path when Coach AI is enabled

## Data migration

### Existing users

- **SwiftData logs** — unchanged; backfill hydrates timeline from existing food/water/weight entries on first context build
- **No timeline rows** — safe; empty timeline sets `missingData.noTimelineHistory`
- **Corrupt timeline rows** — decode to `.unknown` + empty payload; never crash
- **Legacy workout calories on daily log** — ignored for workout events; HealthKit workouts used when available

### Backend

- Gateway rejects `context.meta.schemaVersion != 2` with HTTP 400
- Legacy chat field names (`textPreview`, `sentAt`) still accepted during sanitization for older clients during rollout

## Rollout checklist (completed)

- [x] `CoachContextPacketV2Builder` wired in `AppContainer.makeCoachModel()`
- [x] All `AIService` methods pass v2 context
- [x] `CoachContextCorrectnessValidator` on outbound packets
- [x] Gateway validation + prompt rules
- [x] Timeline recorder on send, confirm, reject, photo, errors
- [x] Backfill idempotent from logs
- [x] Comprehensive iOS + Firebase tests

## Operational notes

### Degraded mode

When HealthKit is denied or SwiftData reads fail, context is still sent with `generationMode: "degraded"` and populated `missingData`. Coach remains usable for local commands (water, weight, status).

### Timeline growth

Compaction policy retains confirmed mutations beyond 30 days; collapsible events (steps, system refresh) pruned per `CoachTimelineCompactionPolicy`.

### Monitoring

Log fields: `contextSchemaVersion`, `contextTimelineEvents`, `contextRecentMeals` — no PII payloads.

## Breaking changes for integrators

- Remove any `AIContext` / `legacyCompact` adapters
- Send `CoachContextPacketV2` on all Coach AI endpoints
- Expect 400 if `context` is empty or wrong schema version

## Testing

```bash
# Firebase
cd functions && npm run build && npm test

# iOS (macOS)
xcodebuild test -scheme "Fitness Coach" -testPlan Fast-Core \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Key test suites: `CoachContextPacketV2BuilderTests`, `CoachTimelineHardeningTests`, `CoachTimelineRegressionTests`, `coachContextPacketV2.test.ts`.
