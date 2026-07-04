# CoachContextPacketV2 — Field Reference

**Schema version:** `2`  
**Transport:** JSON body field `context` on all `/v1/ai/*` Coach gateway endpoints

## Top-level sections

```json
{
  "meta": { "schemaVersion": 2, "localDate": "2026-07-03", "timezoneIdentifier": "America/Los_Angeles" },
  "profile": { },
  "today": { },
  "training": { },
  "healthIntelligence": { },
  "timeline": { "recentEvents": [] },
  "recentChatMessages": [],
  "currentUserMessage": "optional",
  "recentMealsStructured": [],
  "commonFoods": [],
  "missingData": { },
  "assumptions": [],
  "generationMode": "live",
  "sourceAttribution": { }
}
```

## Authoritative vs conversational

| Section | Use for facts? | Notes |
|---------|----------------|-------|
| `today` | **Yes** | Sourced from SwiftData daily log |
| `recentMealsStructured` | **Yes** | Confirmed food entries only |
| `timeline.recentEvents` (confirmed mutations) | **Yes** | Overrides conflicting chat |
| `recentChatMessages` | **No** | Continuity and tone only |
| `currentUserMessage` | **No** (intent only) | Primary user intent signal |
| Assistant text in chat or timeline | **No** | Never nutrition truth |

## Timeline events

Each event includes: `id`, `type`, `status`, `source`, `summary`, `timestamp`, optional `linkedEntryId`.

**Included in context:**

- Confirmed `foodLogged`, `waterLogged`, `weightLogged`
- Pending `pendingConfirmationCreated`
- Photo pipeline events (`photoAttached`, `photoAnalysis*`, `clarification*`)
- `workoutDetected`, `stepsUpdated`

**Excluded from context:**

- `rejected`, `failed`, `superseded` statuses
- `foodRejected`, `foodEstimateCreated`, `backendError`, `authError`, `unknown`

## missingData flags

| Flag | Meaning |
|------|---------|
| `stepsMissing` | No step count in packet |
| `stepsUnavailable` | HealthKit steps read failed |
| `workoutPermissionDeniedOrUnavailable` | Cannot confirm workouts |
| `healthKitDenied` | User denied Health access |
| `noRecentMeals` | No structured meals in lookback |
| `noTimelineHistory` | No eligible timeline events |

## Size limits (enforced client + gateway)

| Field | Max |
|-------|-----|
| Encoded JSON | 24 KB |
| `timeline.recentEvents` | 20 (gateway sanitize), 40 (iOS transport clamp) |
| `recentChatMessages` | 12 |
| `recentMealsStructured` | 10 |
| `commonFoods` | 10 |
| Event `summary` | 180 chars |

## Gateway behavior

1. `validateCoachContextPacketV2` — rejects missing/invalid `meta.schemaVersion`
2. `parseCoachContextForPrompt` — strips unknown keys, clamps arrays/strings
3. Prompt rules in `coachContextPromptRules.ts` — instruct model to prefer structured data

**Trust metadata (v1):** Calorie ranges, assumptions, and uncertainty live on **AI estimate responses** (`FoodLogDraft`, `MealImageAnalysisResponse`, `NutritionEstimateResponse`), not on the context packet. See [COACH_ACCURACY_TRUST_HARDENING_V1_FINAL_REPORT.md](./COACH_ACCURACY_TRUST_HARDENING_V1_FINAL_REPORT.md).

Malformed context returns HTTP 400 with a safe error string (no stack traces to client).

## iOS debug

Use `CoachContextPacketV2.redactedDebugDescription` — never logs raw health values or meal names in release tracing.
