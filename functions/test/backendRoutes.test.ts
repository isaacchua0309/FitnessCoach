import {
  ACCOUNT_DELETION_ROUTE,
  AI_GATEWAY_ROUTES,
  allBackendRoutePaths,
  isKnownAiGatewayPath,
} from "../src/backendRoutes";
import {ACCOUNT_DELETE_DATA_PATH} from "../src/accountDeletion/accountDeletionPaths";
import {MEAL_IMAGE_ANALYSIS_PATH} from "../src/mealImageAnalysis";

describe("backendRoutes", () => {
  it("registers every aiGateway path exactly once", () => {
    const paths = AI_GATEWAY_ROUTES.map((route) => route.path);
    expect(new Set(paths).size).toBe(paths.length);
    expect(paths).toHaveLength(11);
  });

  it("includes meal image analysis and account deletion paths", () => {
    expect(AI_GATEWAY_ROUTES.map((route) => route.path)).toContain(
      MEAL_IMAGE_ANALYSIS_PATH
    );
    expect(ACCOUNT_DELETION_ROUTE.path).toBe(ACCOUNT_DELETE_DATA_PATH);
    expect(ACCOUNT_DELETION_ROUTE.handler).toBe("handleAccountDeletionRequest");
    expect(ACCOUNT_DELETION_ROUTE.owner).toBe("accountDataDeletion");
  });

  it("exposes a stable combined route list for smoke checks", () => {
    const combined = allBackendRoutePaths();
    expect(combined).toHaveLength(12);
    expect(combined).toEqual([
      ...AI_GATEWAY_ROUTES.map((route) => route.path),
      ACCOUNT_DELETE_DATA_PATH,
    ]);
  });

  it("recognizes known aiGateway paths only", () => {
    for (const route of AI_GATEWAY_ROUTES) {
      expect(isKnownAiGatewayPath(route.path)).toBe(true);
    }
    expect(isKnownAiGatewayPath("/v1/account/delete-data")).toBe(false);
    expect(isKnownAiGatewayPath("/v1/ai/unknown")).toBe(false);
  });

  it("assigns aiGateway ownership to all AI routes", () => {
    for (const route of AI_GATEWAY_ROUTES) {
      expect(route.owner).toBe("aiGateway");
      expect(route.handler.length).toBeGreaterThan(0);
      expect(route.modelTier.length).toBeGreaterThan(0);
      expect(route.responseKey.length).toBeGreaterThan(0);
    }
  });
});
