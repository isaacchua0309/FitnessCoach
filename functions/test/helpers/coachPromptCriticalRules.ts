export interface CoachPromptCriticalMarker {
  id: string;
  description: string;
  pattern: RegExp;
}

/** Markers that must appear in full Coach endpoint instruction blocks. */
export const COACH_PROMPT_CRITICAL_MARKERS: CoachPromptCriticalMarker[] = [
  {
    id: "structured-source-of-truth",
    description: "structured context is source of truth",
    pattern: /Structured context is the source of truth/i,
  },
  {
    id: "timeline-overrides-chat",
    description: "confirmed timeline overrides chat",
    pattern: /Timeline confirmed events override chat text/i,
  },
  {
    id: "assistant-conversational-only",
    description: "assistant messages are conversational only",
    pattern: /recentChatMessages and currentUserMessage for conversational continuity only/i,
  },
  {
    id: "pending-rejected-not-logged",
    description: "pending/rejected/failed are not logged",
    pattern: /Pending, rejected, failed, or superseded timeline events must not be treated as logged facts/i,
  },
  {
    id: "missing-data-acknowledged",
    description: "missingData must be acknowledged",
    pattern: /If data is missing or unavailable, say it is missing|context\.missingData|missingData flags/i,
  },
  {
    id: "local-date-timezone-today",
    description: "use localDate/timezone for today",
    pattern: /context\.meta\.localDate and context\.meta\.timezoneIdentifier/i,
  },
  {
    id: "recent-events-ordering",
    description: "use recentEvents for ordering",
    pattern: /context\.timeline\.recentEvents for chronological ordering/i,
  },
  {
    id: "recent-meals-structured",
    description: "use recentMealsStructured for meal references",
    pattern: /context\.recentMealsStructured/i,
  },
  {
    id: "never-mutate-app-state",
    description: "never mutate app state",
    pattern: /never mutate app state|Do not mutate app state/i,
  },
  {
    id: "no-medical-diagnosis",
    description: "never diagnose medical conditions",
    pattern: /Do not diagnose medical conditions/i,
  },
];

export const CLASSIFIER_CRITICAL_MARKERS: CoachPromptCriticalMarker[] = [
  {
    id: "linked-entry-id",
    description: "use linkedEntryId for edit/delete",
    pattern: /linkedEntryId/i,
  },
  {
    id: "no-nutrition-from-chat",
    description: "do not copy nutrition from assistant chat text",
    pattern: /Do not copy nutrition values from context\.recentChatMessages|Never copy nutrition from chat history/i,
  },
  {
    id: "health-intelligence",
    description: "use Health Intelligence when present",
    pattern: /context\.healthIntelligence is present/i,
  },
];

export const EDIT_DELETE_CRITICAL_MARKERS: CoachPromptCriticalMarker[] = [
  {
    id: "linked-entry-id-edit-delete",
    description: "use linkedEntryId for edit/delete",
    pattern: /linkedEntryId/i,
  },
  {
    id: "no-assistant-only-delete",
    description: "never delete based only on assistant chat",
    pattern: /Never delete or edit based only on assistant chat text/i,
  },
];

export function missingMarkers(
  text: string,
  markers: CoachPromptCriticalMarker[]
): CoachPromptCriticalMarker[] {
  return markers.filter((marker) => !marker.pattern.test(text));
}

export function assertCoachPromptMarkers(
  text: string,
  markers: CoachPromptCriticalMarker[],
  label = "prompt"
): void {
  const missing = missingMarkers(text, markers);
  if (missing.length > 0) {
    const details = missing
      .map((marker) => `${marker.id}: ${marker.description}`)
      .join("; ");
    throw new Error(`Missing critical ${label} markers: ${details}`);
  }
}
