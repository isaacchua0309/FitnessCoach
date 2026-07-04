import {coachContextV2Fixtures} from "./coach-context-v2";

/** Backward-compatible alias for minimal v2 context. */
export const minimalCoachContextV2 = coachContextV2Fixtures.minimal;

/** Backward-compatible alias for workout-aware rich context. */
export const workoutAwareCoachContextV2 = coachContextV2Fixtures.rich;

/** Full rich v2 context for validation and sanitization probes. */
export const richCoachContextV2 = coachContextV2Fixtures.rich;

export {coachContextV2Fixtures, COACH_CONTEXT_V2_SCHEMA_VERSION} from "./coach-context-v2";
