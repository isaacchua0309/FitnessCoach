import {
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from "firebase/firestore";
import {
  accountPersistencePaths,
  dailyLogPayload,
  dailyReviewPayload,
  foodEntryPayload,
  initializeAccountPersistenceRulesTestEnvironment,
  LOCAL_DATE,
  profilePayload,
  syncMetadataPayload,
  USER_A,
  USER_B,
  waterEntryPayload,
  weightEntryPayload,
} from "./helpers/accountPersistenceRulesFixtures";

describe("account persistence firestore rules", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await initializeAccountPersistenceRulesTestEnvironment();
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  it("1. owner can create own daily log", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const ref = doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A));

    await assertSucceeds(setDoc(ref, dailyLogPayload(USER_A)));
  });

  it("2. other user cannot read daily log", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const other = testEnv.authenticatedContext(USER_B);
    const ownerRef = doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A));

    await assertSucceeds(setDoc(ownerRef, dailyLogPayload(USER_A)));
    await assertFails(
      getDoc(doc(other.firestore(), accountPersistencePaths.dailyLog(USER_A)))
    );
  });

  it("3. owner cannot write mismatched userId", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const ref = doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A));

    await assertFails(
      setDoc(ref, dailyLogPayload(USER_B))
    );
  });

  it("4. unauthenticated user cannot read or write account persistence docs", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const unauth = testEnv.unauthenticatedContext();

    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A)),
        dailyLogPayload(USER_A)
      )
    );

    const protectedPaths = [
      accountPersistencePaths.profile(USER_A),
      accountPersistencePaths.dailyLog(USER_A),
      accountPersistencePaths.foodEntry(USER_A),
      accountPersistencePaths.waterEntry(USER_A),
      accountPersistencePaths.weightEntry(USER_A),
      accountPersistencePaths.dailyReview(USER_A),
      accountPersistencePaths.syncMetadata(USER_A),
    ];

    for (const path of protectedPaths) {
      const readRef = doc(unauth.firestore(), path);
      await assertFails(getDoc(readRef));
      await assertFails(setDoc(readRef, dailyLogPayload(USER_A)));
    }
  });

  it("5. owner can create food entry under own daily log", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const dailyRef = doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A));
    const foodRef = doc(owner.firestore(), accountPersistencePaths.foodEntry(USER_A));

    await assertSucceeds(setDoc(dailyRef, dailyLogPayload(USER_A)));
    await assertSucceeds(setDoc(foodRef, foodEntryPayload(USER_A)));
  });

  it("6. other user cannot create food entry under another user path", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const other = testEnv.authenticatedContext(USER_B);

    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A)),
        dailyLogPayload(USER_A)
      )
    );

    await assertFails(
      setDoc(
        doc(other.firestore(), accountPersistencePaths.foodEntry(USER_A)),
        foodEntryPayload(USER_B)
      )
    );
  });

  it("7. owner can create water entry under own daily log", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const dailyRef = doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A));
    const waterRef = doc(owner.firestore(), accountPersistencePaths.waterEntry(USER_A));

    await assertSucceeds(setDoc(dailyRef, dailyLogPayload(USER_A)));
    await assertSucceeds(setDoc(waterRef, waterEntryPayload(USER_A)));
  });

  it("8. other user cannot create water entry under another user path", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const other = testEnv.authenticatedContext(USER_B);

    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A)),
        dailyLogPayload(USER_A)
      )
    );

    await assertFails(
      setDoc(
        doc(other.firestore(), accountPersistencePaths.waterEntry(USER_A)),
        waterEntryPayload(USER_B)
      )
    );
  });

  it("9. owner can create weight entry under own path", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const weightRef = doc(owner.firestore(), accountPersistencePaths.weightEntry(USER_A));

    await assertSucceeds(setDoc(weightRef, weightEntryPayload(USER_A)));
  });

  it("10. other user cannot read weight entry", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const other = testEnv.authenticatedContext(USER_B);
    const weightRef = doc(owner.firestore(), accountPersistencePaths.weightEntry(USER_A));

    await assertSucceeds(setDoc(weightRef, weightEntryPayload(USER_A)));
    await assertFails(
      getDoc(doc(other.firestore(), accountPersistencePaths.weightEntry(USER_A)))
    );
  });

  it("11. owner can create daily review", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const reviewRef = doc(owner.firestore(), accountPersistencePaths.dailyReview(USER_A));

    await assertSucceeds(setDoc(reviewRef, dailyReviewPayload(USER_A)));
  });

  it("12. owner can update sync metadata current", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const metadataRef = doc(owner.firestore(), accountPersistencePaths.syncMetadata(USER_A));

    await assertSucceeds(setDoc(metadataRef, syncMetadataPayload(USER_A)));
    await assertSucceeds(
      updateDoc(metadataRef, {
        clientVersion: "1.0.1",
        updatedAt: syncMetadataPayload(USER_A).updatedAt,
      })
    );
  });

  it("13. write without schemaVersion is denied", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const ref = doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A));
    const payload = dailyLogPayload(USER_A) as Record<string, unknown>;
    delete payload.schemaVersion;

    await assertFails(setDoc(ref, payload));
  });

  it("14. profile rules allow owner read write and deny cross user access", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const other = testEnv.authenticatedContext(USER_B);
    const profileRef = doc(owner.firestore(), accountPersistencePaths.profile(USER_A));

    await assertSucceeds(setDoc(profileRef, profilePayload()));
    await assertSucceeds(getDoc(profileRef));
    await assertFails(
      getDoc(doc(other.firestore(), accountPersistencePaths.profile(USER_A)))
    );
    await assertFails(
      setDoc(doc(other.firestore(), accountPersistencePaths.profile(USER_A)), profilePayload())
    );
  });

  // Phase 6 account deletion — client rules (backend uses Admin SDK; see accountDeletion.test.ts).
  it("15. other user cannot delete another user's profile", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const other = testEnv.authenticatedContext(USER_B);
    const profileRef = doc(owner.firestore(), accountPersistencePaths.profile(USER_A));

    await assertSucceeds(setDoc(profileRef, profilePayload()));
    await assertFails(deleteDoc(doc(other.firestore(), accountPersistencePaths.profile(USER_A))));
    await assertSucceeds(getDoc(profileRef));
  });

  it("16. other user cannot delete another user's daily log or nested entries", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const other = testEnv.authenticatedContext(USER_B);

    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A)),
        dailyLogPayload(USER_A)
      )
    );
    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.foodEntry(USER_A)),
        foodEntryPayload(USER_A)
      )
    );
    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.waterEntry(USER_A)),
        waterEntryPayload(USER_A)
      )
    );

    await assertFails(
      deleteDoc(doc(other.firestore(), accountPersistencePaths.dailyLog(USER_A)))
    );
    await assertFails(
      deleteDoc(doc(other.firestore(), accountPersistencePaths.foodEntry(USER_A)))
    );
    await assertFails(
      deleteDoc(doc(other.firestore(), accountPersistencePaths.waterEntry(USER_A)))
    );
  });

  it("17. other user cannot delete another user's weight entries daily reviews or sync metadata", async () => {
    const owner = testEnv.authenticatedContext(USER_A);
    const other = testEnv.authenticatedContext(USER_B);

    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.weightEntry(USER_A)),
        weightEntryPayload(USER_A)
      )
    );
    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.dailyReview(USER_A)),
        dailyReviewPayload(USER_A)
      )
    );
    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.syncMetadata(USER_A)),
        syncMetadataPayload(USER_A)
      )
    );

    await assertFails(
      deleteDoc(doc(other.firestore(), accountPersistencePaths.weightEntry(USER_A)))
    );
    await assertFails(
      deleteDoc(doc(other.firestore(), accountPersistencePaths.dailyReview(USER_A)))
    );
    await assertFails(
      deleteDoc(doc(other.firestore(), accountPersistencePaths.syncMetadata(USER_A)))
    );
  });

  it("18. owner can delete own account persistence documents via client SDK", async () => {
    const owner = testEnv.authenticatedContext(USER_A);

    await assertSucceeds(
      setDoc(
        doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A)),
        dailyLogPayload(USER_A)
      )
    );
    await assertSucceeds(
      deleteDoc(doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A)))
    );
    await assertFails(
      getDoc(doc(owner.firestore(), accountPersistencePaths.dailyLog(USER_A)))
    );
  });
});
