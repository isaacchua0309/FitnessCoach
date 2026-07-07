/* eslint-disable max-len, require-jsdoc, @typescript-eslint/no-explicit-any */
import {logger} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import {GatewayError, gatewayErrorCategory} from "../gatewayGuardrails";
import {
  enforceAccountDeletionQuota,
  isDryRunRequest,
  privacySafeUidHash,
  validateDeleteDataRequest,
  verifyAccountDeletionAuth,
} from "./accountDeletionGuardrails";
import {inspectAccountFirestoreData} from "./accountDeletionInspectService";
import {ACCOUNT_DELETE_DATA_PATH} from "./accountDeletionPaths";
import {deleteAccountFirestoreData} from "./accountDeletionService";
import type {
  AccountDeletionDryRunResponse,
  AccountDeletionResponse,
} from "./accountDeletionTypes";

function normalizedPath(path: string): string {
  const withoutQuery = path.split("?")[0] || "/";
  return withoutQuery.startsWith("/") ? withoutQuery : `/${withoutQuery}`;
}

function readRequestBody(request: any): Record<string, unknown> {
  if (request.body && typeof request.body === "object") {
    return request.body as Record<string, unknown>;
  }

  if (typeof request.rawBody?.toString === "function") {
    const raw = request.rawBody.toString("utf8");
    return JSON.parse(raw || "{}") as Record<string, unknown>;
  }

  return {};
}

export async function handleAccountDeletionRequest(
  request: any,
  response: any
): Promise<void> {
  const requestStarted = Date.now();

  try {
    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    if (request.method !== "POST") {
      response.status(405).json({error: "Method not allowed."});
      return;
    }

    const path = normalizedPath(request.path || request.url || "");
    if (path !== ACCOUNT_DELETE_DATA_PATH) {
      response.status(404).json({error: "Not found."});
      return;
    }

    const uid = await verifyAccountDeletionAuth(request);
    const body = readRequestBody(request);
    validateDeleteDataRequest(body);
    const dryRun = isDryRunRequest(body);

    if (!dryRun) {
      enforceAccountDeletionQuota(uid);
    }

    if (dryRun) {
      logger.info("Account deletion dry run started", {
        uidHash: privacySafeUidHash(uid),
        path,
      });

      const {wouldDeleteGroups} = await inspectAccountFirestoreData(uid);
      const payload: AccountDeletionDryRunResponse = {
        ok: true,
        dryRun: true,
        uidScoped: true,
        wouldDeleteGroups,
        serverTime: new Date().toISOString(),
        function: "accountDataDeletion",
      };

      logger.info("Account deletion dry run finished", {
        uidHash: privacySafeUidHash(uid),
        durationMs: Date.now() - requestStarted,
        wouldDeleteGroupCount: wouldDeleteGroups.length,
      });

      response.status(200).json(payload);
      return;
    }

    logger.info("Account deletion started", {
      uidHash: privacySafeUidHash(uid),
      path,
    });

    const {deleted, completed} = await deleteAccountFirestoreData(uid, {
      startedAtMs: requestStarted,
    });

    const durationMs = Date.now() - requestStarted;
    const payload: AccountDeletionResponse = completed ?
      {ok: true, uid, deleted} :
      {
        ok: false,
        uid,
        deleted,
        backendErrorCategory: "timeout",
      };

    logger.info("Account deletion finished", {
      uidHash: privacySafeUidHash(uid),
      durationMs,
      completed,
      deletedCounts: deleted,
      backendErrorCategory: completed ? undefined : "timeout",
    });

    response.status(completed ? 200 : 503).json(payload);
  } catch (error) {
    const status = error instanceof GatewayError ? error.status : 500;
    const message = error instanceof Error ? error.message : "Account deletion failed.";
    const category = gatewayErrorCategory(error);

    logger.error("Account deletion failed", {
      durationMs: Date.now() - requestStarted,
      backendErrorCategory: category,
    });

    response.status(status).json({
      error: message,
      backendErrorCategory: category,
    });
  }
}

export const accountDataDeletion = onRequest(
  {
    timeoutSeconds: 300,
    memory: "512MiB",
    cors: false,
  },
  handleAccountDeletionRequest
);
