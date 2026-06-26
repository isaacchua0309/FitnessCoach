export function isTraceEnabled() {
  return process.env.FITPILOT_AI_BACKEND_TRACE !== "0";
}

export function isVerbose() {
  return process.env.FITPILOT_AI_BACKEND_TRACE_VERBOSE === "1";
}

export function logTrace({ traceId, stage, level = "info", message, fields = {} }) {
  if (!isTraceEnabled()) return;

  const payload = {
    ts: new Date().toISOString(),
    traceId: traceId ?? "none",
    stage,
    level,
    message,
    ...fields
  };

  console.log(JSON.stringify(payload));
}

export function sanitizeSnippet(value, limit = 2048) {
  if (!isVerbose() || value == null) return undefined;
  const text = typeof value === "string" ? value : JSON.stringify(value);
  const redacted = text
    .replace(/Bearer\s+\S+/g, "Bearer <redacted>")
    .replace(/"Authorization"\s*:\s*"[^"]*"/g, '"Authorization":"<redacted>"');
  if (redacted.length <= limit) return redacted;
  return `${redacted.slice(0, limit)}…(truncated)`;
}

export function readTraceId(request) {
  return request.headers["x-fitpilot-trace-id"] ?? request.headers["X-FitPilot-Trace-Id"] ?? null;
}
