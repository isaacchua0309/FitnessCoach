/* eslint-disable require-jsdoc, valid-jsdoc, max-len */

import {ACCOUNT_DELETE_DATA_PATH} from "./accountDeletion/accountDeletionPaths";
import {MEAL_IMAGE_ANALYSIS_PATH} from "./mealImageAnalysis";

export type BackendFunctionOwner = "aiGateway" | "accountDataDeletion";

export interface AiGatewayRouteDefinition {
  path: string;
  handler: string;
  owner: "aiGateway";
  /** How `resolveModel` tier is chosen in `handleAiGatewayRequest`. */
  modelTier: string;
  responseKey: string;
}

export interface AccountDeletionRouteDefinition {
  path: typeof ACCOUNT_DELETE_DATA_PATH;
  handler: "handleAccountDeletionRequest";
  owner: "accountDataDeletion";
}

/** Canonical AI gateway POST paths — keep in sync with `handleAiGatewayRequest`. */
export const AI_GATEWAY_ROUTES: readonly AiGatewayRouteDefinition[] = [
  {
    path: "/v1/ai/classify-coach-intent",
    handler: "classifyCoachIntent",
    owner: "aiGateway",
    modelTier: "cheap (+ optional body.modelName)",
    responseKey: "intentResult",
  },
  {
    path: "/v1/ai/parse-command",
    handler: "parseCommand",
    owner: "aiGateway",
    modelTier: "cheap",
    responseKey: "parsedCommand",
  },
  {
    path: "/v1/ai/estimate-food",
    handler: "estimateFood",
    owner: "aiGateway",
    modelTier: "strong when body.imageJPEGBase64, else cheap",
    responseKey: "foodLogDrafts, foodDrafts, confidence, requiresConfirmation",
  },
  {
    path: MEAL_IMAGE_ANALYSIS_PATH,
    handler: "analyzeMealImage",
    owner: "aiGateway",
    modelTier: "strong",
    responseKey: "summary, items, total, needsUserReview",
  },
  {
    path: "/v1/ai/generate-meal-advice",
    handler: "coachResponse (mealAdvice)",
    owner: "aiGateway",
    modelTier: "body.modelTier ?? strong (+ optional body.modelName)",
    responseKey: "response",
  },
  {
    path: "/v1/ai/generate-nutrition-estimate",
    handler: "nutritionEstimateResponse",
    owner: "aiGateway",
    modelTier: "body.modelTier ?? cheap (+ optional body.modelName)",
    responseKey: "estimate",
  },
  {
    path: "/v1/ai/generate-nutrition-comparison",
    handler: "nutritionComparisonResponse",
    owner: "aiGateway",
    modelTier: "body.modelTier ?? cheap (+ optional body.modelName)",
    responseKey: "comparison",
  },
  {
    path: "/v1/ai/generate-daily-review",
    handler: "coachResponse (dailyReview)",
    owner: "aiGateway",
    modelTier: "cheap (+ optional body.modelName)",
    responseKey: "response",
  },
  {
    path: "/v1/ai/parse-workout",
    handler: "parseWorkout",
    owner: "aiGateway",
    modelTier: "cheap",
    responseKey: "workoutDraft",
  },
  {
    path: "/v1/ai/parse-edit-delete",
    handler: "parseEditDelete",
    owner: "aiGateway",
    modelTier: "cheap",
    responseKey: "parsedCommand",
  },
  {
    path: "/v1/ai/parse-multi-action",
    handler: "parseMultiAction",
    owner: "aiGateway",
    modelTier: "cheap",
    responseKey: "parsedCommand",
  },
] as const;

export const ACCOUNT_DELETION_ROUTE: AccountDeletionRouteDefinition = {
  path: ACCOUNT_DELETE_DATA_PATH,
  handler: "handleAccountDeletionRequest",
  owner: "accountDataDeletion",
};

/** All registered HTTPS paths served by Firebase Functions in this package. */
export function allBackendRoutePaths(): string[] {
  return [
    ...AI_GATEWAY_ROUTES.map((route) => route.path),
    ACCOUNT_DELETION_ROUTE.path,
  ];
}

export function isKnownAiGatewayPath(path: string): boolean {
  return AI_GATEWAY_ROUTES.some((route) => route.path === path);
}
