import type {Firestore} from "firebase-admin/firestore";

type DocumentStore = Map<string, Record<string, unknown>>;

interface MockDocRef {
  path: string;
  get: () => Promise<{exists: boolean; ref: MockDocRef}>;
  delete: () => Promise<void>;
  collection: (name: string) => MockCollectionRef;
}

interface MockCollectionRef {
  path: string;
  limit: (size: number) => MockCollectionRef;
  get: () => Promise<{empty: boolean; size: number; docs: Array<{ref: MockDocRef}>}>;
}

interface MockBatch {
  delete: (ref: MockDocRef) => MockBatch;
  commit: () => Promise<void>;
}

export interface InMemoryFirestoreHarness {
  db: Firestore;
  seedDocument: (path: string, data?: Record<string, unknown>) => void;
  documentExists: (path: string) => boolean;
  listDirectChildDocumentPaths: (collectionPath: string) => string[];
}

function directChildDocumentPaths(
  store: DocumentStore,
  collectionPath: string
): string[] {
  const prefix = `${collectionPath}/`;
  const childIds = new Set<string>();

  for (const key of store.keys()) {
    if (!key.startsWith(prefix)) {
      continue;
    }
    const remainder = key.slice(prefix.length);
    const slashIndex = remainder.indexOf("/");
    const documentId = slashIndex === -1 ?
      remainder :
      remainder.slice(0, slashIndex);
    if (documentId.length > 0) {
      childIds.add(`${collectionPath}/${documentId}`);
    }
  }

  return [...childIds].sort();
}

export function createInMemoryFirestoreHarness(): InMemoryFirestoreHarness {
  const store: DocumentStore = new Map();

  const makeDocRef = (path: string): MockDocRef => ({
    path,
    async get() {
      return {
        exists: store.has(path),
        ref: makeDocRef(path),
      };
    },
    async delete() {
      store.delete(path);
    },
    collection(name: string) {
      return makeCollectionRef(`${path}/${name}`);
    },
  });

  const makeCollectionRef = (path: string): MockCollectionRef => {
    let pageSize = 400;
    return {
      path,
      limit(size: number) {
        pageSize = size;
        return this;
      },
      async get() {
        const documentPaths = directChildDocumentPaths(store, path).slice(0, pageSize);
        const docs = documentPaths.map((documentPath) => ({ref: makeDocRef(documentPath)}));
        return {
          empty: docs.length === 0,
          size: docs.length,
          docs,
        };
      },
    };
  };

  const db = {
    collection(path: string) {
      return makeCollectionRef(path);
    },
    doc(path: string) {
      return makeDocRef(path);
    },
    batch() {
      const pendingDeletes: string[] = [];
      const batch: MockBatch = {
        delete(ref: MockDocRef) {
          pendingDeletes.push(ref.path);
          return batch;
        },
        async commit() {
          for (const path of pendingDeletes) {
            store.delete(path);
          }
        },
      };
      return batch;
    },
  };

  return {
    db: db as unknown as Firestore,
    seedDocument(path: string, data: Record<string, unknown> = {seeded: true}) {
      store.set(path, data);
    },
    documentExists(path: string) {
      return store.has(path);
    },
    listDirectChildDocumentPaths(collectionPath: string) {
      return directChildDocumentPaths(store, collectionPath);
    },
  };
}
