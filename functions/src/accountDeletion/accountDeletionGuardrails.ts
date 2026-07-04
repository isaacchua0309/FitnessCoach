/* eslint-disable max-len, require-jsdoc, valid-jsdoc, @typescript-eslint/no-explicit-any */
import {createHash} from "node:crypto";
import {GatewayError} from "../gatewayGuardrails";
import {ACCOUNT_DELETION_CONFIRMATION_PHRASE} from "./accountDeletionPaths";

const DEFAULT_BURST_PER_MINUTE = 2;
const DEFAULT_DAILY_PER_USER = 5;

const burstHits = new Map<string, number[]>();
const dailyCounts = new Map<string, {day: string; count: number}>();

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/** Privacy-safe uid field for logs — never log raw uid or document contents. */
export function privacySafeUidHash(uid: string): string {
  return createHash("sha256").update(uid).digest("hex").slice(0, 12);
}

export function validateDeleteDataRequest(body: Record<string, unknown>): void {
  const confirmation = body.confirmation;
  if (typeof confirmation !== "string" || confirmation !== ACCOUNT_DELETION_CONFIRMATION_PHRASE) {
    throw new GatewayError(
      400,
      `Confirmation phrase must be exactly "${ACCOUNT_DELETION_CONFIRMATION_PHRASE}".`,
      "validation"
    );
  }

  if (body.uid !== undefined || body.userId !== undefined) {
    throw new GatewayError(
      400,
      "Client-supplied uid is not accepted.",
      "validation"
    );
  }
}

export function enforceAccountDeletionQuota(uid: string): void {
  const burstLimit = intEnv(
    "FORMA_ACCOUNT_DELETE_BURST_PER_MINUTE",
    DEFAULT_BURST_PER_MINUTE
  );
  const dailyLimit = intEnv(
    "FORMA_ACCOUNT_DELETE_DAILY_LIMIT",
    DEFAULT_DAILY_PER_USER
  );

  if (burstLimit > 0) {
    const now = Date.now();
    const windowMs = 60_000;
    const hits = (burstHits.get(uid) || []).filter((t) => now - t < windowMs);
    if (hits.length >= burstLimit) {
      throw new GatewayError(
        429,
        "Too many account deletion attempts. Please wait and try again.",
        "rate_limited"
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
        "Daily account deletion limit reached. Try again tomorrow.",
        "rate_limited"
      );
    }
    entry.count += 1;
  }
}

export async function verifyAccountDeletionAuth(request: any): Promise<string> {
  const header = request.header?.("Authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    throw new GatewayError(401, "Missing Firebase ID token.", "authentication");
  }

  const {getAuth} = await import("firebase-admin/auth");
  try {
    const decoded = await getAuth().verifyIdToken(match[1]);
    if (!decoded.uid) {
      throw new GatewayError(401, "Invalid Firebase ID token.", "authentication");
    }
    return decoded.uid;
  } catch (error) {
    if (error instanceof GatewayError) {
      throw error;
    }
    throw new GatewayError(401, "Invalid Firebase ID token.", "authentication");
  }
}

/** Test-only reset for in-memory quota counters. */
export function resetAccountDeletionGuardrailsForTests(): void {
  burstHits.clear();
  dailyCounts.clear();
}
