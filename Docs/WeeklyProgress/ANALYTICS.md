# Weekly Progress Loop v1 — Analytics

Typed contracts for the weekly progress ritual live in `Fitness Coach/Domain/WeeklyProgress/WeeklyProgressAnalyticsLogging.swift`.

## Sinks

| Build | Logger | Trace flag |
|-------|--------|------------|
| DEBUG | `OSLogWeeklyProgressAnalyticsLogger` | `FormaAbTest.Diagnostics.weeklyProgressAnalyticsTrace` |
| Release | `NoOpWeeklyProgressAnalyticsLogger` | — |

There is no third-party product analytics SDK wired for these events today. Release builds intentionally remain no-op until Firebase Analytics (or another approved sink) is integrated.

**TODO:** When Firebase Analytics is added, implement a production `WeeklyProgressAnalyticsLogging` adapter that forwards the same event names and bucketed parameters only.

## Privacy

Parameters are limited to:

- `confidence_level`, `data_window_days`, `food_logged_days_bucket`, `weight_entry_count_bucket`
- `recommendation_kind`, `has_maintenance_estimate`, `has_weight_spike`
- `entry_point`, `surface`

Never log raw weight, calories, food names, review text, or full UID.

## Tests

`Fitness CoachTests/WeeklyProgressAnalyticsLoggingTests.swift` uses `CapturingWeeklyProgressAnalyticsLogger` to verify coordinator deduplication and bucketed payloads.
