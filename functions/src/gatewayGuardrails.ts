/* eslint-disable @typescript-eslint/no-explicit-any, require-jsdoc, max-len, valid-jsdoc */

export class GatewayError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

const DEFAULT_MAX_BODY_BYTES = 512 * 1024;
const DEFAULT_MAX_BODY_BYTES_WITH_IMAGE = 2 * 1024 * 1024;
const DEFAULT_MAX_TEXT_CHARS = 4_000;
const DEFAULT_MAX_QUESTION_CHARS = 4_000;
const DEFAULT_MAX_IMAGE_B64_CHARS = 1_500_000;
const DEFAULT_BURST_PER_MINUTE = 30;
const DEFAULT_DAILY_PER_USER = 400;

const ZERO_WIDTH_PATTERN = /[\u200B-\u200D\uFEFF]/g;

const burstHits = new Map<string, number[]>();
const dailyCounts = new Map<string, {day: string; count: number}>();

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function maxBodyBytes(requestBody: Record<string, any>): number {
  if (typeof requestBody.imageJPEGBase64 === "string" &&
    requestBody.imageJPEGBase64.length > 0) {
    return intEnv("FORMA_AI_MAX_BODY_BYTES_WITH_IMAGE", DEFAULT_MAX_BODY_BYTES_WITH_IMAGE);
  }
  return intEnv("FORMA_AI_MAX_BODY_BYTES", DEFAULT_MAX_BODY_BYTES);
}

export function requestBodyByteLength(request: any): number {
  if (typeof request.rawBody?.length === "number") {
    return request.rawBody.length;
  }
  if (request.body && typeof request.body === "object") {
    return Buffer.byteLength(JSON.stringify(request.body), "utf8");
  }
  return 0;
}

export function assertBodySizeWithinLimit(
  request: any,
  body: Record<string, any>
): number {
  const bodyBytes = requestBodyByteLength(request);
  const limit = maxBodyBytes(body);
  if (bodyBytes > limit) {
    throw new GatewayError(
      413,
      `Request body too large (${bodyBytes} bytes; limit ${limit}).`
    );
  }
  return bodyBytes;
}

function requireString(
  value: unknown,
  field: string,
  maxChars: number
): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new GatewayError(400, `Missing or invalid ${field}.`);
  }
  const normalized = normalizeGatewayText(value);
  if (normalized.length === 0) {
    throw new GatewayError(400, `Missing or invalid ${field}.`);
  }
  if (normalized.length > maxChars) {
    throw new GatewayError(400, `${field} exceeds maximum length.`);
  }
  return normalized;
}

function requireObject(value: unknown, field: string): Record<string, any> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new GatewayError(400, `Missing or invalid ${field}.`);
  }
  return value as Record<string, any>;
}

export function validatePayload(path: string, body: Record<string, any>): void {
  const maxText = intEnv("FORMA_AI_MAX_TEXT_CHARS", DEFAULT_MAX_TEXT_CHARS);
  const maxQuestion = intEnv("FORMA_AI_MAX_QUESTION_CHARS", DEFAULT_MAX_QUESTION_CHARS);
  const maxImage = intEnv("FORMA_AI_MAX_IMAGE_B64_CHARS", DEFAULT_MAX_IMAGE_B64_CHARS);

  switch (path) {
  case "/v1/ai/generate-meal-advice":
    body.question = requireString(body.question, "question", maxQuestion);
    if (body.context !== undefined) requireObject(body.context, "context");
    return;
  case "/v1/ai/generate-daily-review":
    requireObject(body.input, "input");
    if (body.context !== undefined) requireObject(body.context, "context");
    return;
  case "/v1/ai/estimate-food":
    if (typeof body.imageJPEGBase64 === "string" &&
      body.imageJPEGBase64.length > 0) {
      requireString(body.imageJPEGBase64, "imageJPEGBase64", maxImage);
      if (body.text !== undefined && typeof body.text !== "string") {
        throw new GatewayError(400, "Invalid text.");
      }
      if (typeof body.text === "string") {
        body.text = requireString(body.text, "text", maxText);
      }
    } else {
      body.text = requireString(body.text, "text", maxText);
    }
    if (body.context !== undefined) requireObject(body.context, "context");
    return;
  default:
    body.text = requireString(body.text, "text", maxText);
    if (body.context !== undefined) requireObject(body.context, "context");
  }
}

export function enforceRequestQuota(uid: string | null): void {
  if (!uid) return;

  const burstLimit = intEnv("FORMA_AI_BURST_PER_MINUTE", DEFAULT_BURST_PER_MINUTE);
  const dailyLimit = intEnv("FORMA_AI_DAILY_REQUEST_LIMIT", DEFAULT_DAILY_PER_USER);

  if (burstLimit > 0) {
    const now = Date.now();
    const windowMs = 60_000;
    const hits = (burstHits.get(uid) || []).filter((t) => now - t < windowMs);
    if (hits.length >= burstLimit) {
      throw new GatewayError(
        429,
        "Too many AI requests. Please wait a moment and try again."
      );
    }
    hits.push(now);
    burstHits.set(uid, hits);
  }

  if (dailyLimit > 0) {
    const day = new Date().toISOString().slice(0, 10);
    const entry = dailyCounts.get(uid);
    if (!entry || entry.day !== day) {
      dailyCounts.set(uid, {day, count: 1});
      return;
    }
    if (entry.count >= dailyLimit) {
      throw new GatewayError(
        429,
        "Daily AI request limit reached. Try again tomorrow."
      );
    }
    entry.count += 1;
  }
}

/** Normalizes gateway text for safe length checks and model input. */
export function normalizeGatewayText(value: string): string {
  const withoutZeroWidth = value.replace(ZERO_WIDTH_PATTERN, "");
  const normalizedScalars = Array.from(withoutZeroWidth).map((char) => {
    const code = char.codePointAt(0);
    if (code === undefined) return char;
    if (code >= 0xFF10 && code <= 0xFF19) {
      return String.fromCodePoint(code - 0xFF10 + 0x30);
    }
    if (code >= 0xFF21 && code <= 0xFF3A) {
      return String.fromCodePoint(code - 0xFF21 + 0x41);
    }
    if (code >= 0xFF41 && code <= 0xFF5A) {
      return String.fromCodePoint(code - 0xFF41 + 0x61);
    }
    return char;
  });
  return normalizedScalars.join("").trim();
}

export function normalizeGatewayPayloadText(body: Record<string, any>): void {
  if (typeof body.text === "string") {
    body.text = normalizeGatewayText(body.text);
  }
  if (typeof body.question === "string") {
    body.question = normalizeGatewayText(body.question);
  }
}

/** Test-only reset for in-memory quota counters. */
export function resetGatewayGuardrailsForTests(): void {
  burstHits.clear();
  dailyCounts.clear();
}
