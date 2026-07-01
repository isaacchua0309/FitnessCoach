type HeaderMap = Record<string, string>;

export interface MockResponseState {
  statusCode: number;
  headers: HeaderMap;
  body: unknown;
}

export function createMockResponse(): MockResponseState & {
  status: (code: number) => MockResponseState & {
    json: (payload: unknown) => void;
    send: (payload: string) => void;
  };
  setHeader: (name: string, value: string) => void;
  json: (payload: unknown) => void;
  send: (payload: string) => void;
} {
  const state: MockResponseState = {
    statusCode: 200,
    headers: {},
    body: undefined,
  };

  const response = {
    get statusCode() {
      return state.statusCode;
    },
    get headers() {
      return state.headers;
    },
    get body() {
      return state.body;
    },
    status(code: number) {
      state.statusCode = code;
      return response;
    },
    setHeader(name: string, value: string) {
      state.headers[name] = value;
      return response;
    },
    json(payload: unknown) {
      state.body = payload;
      return response;
    },
    send(payload: string) {
      state.body = payload;
      return response;
    },
  };

  return response;
}

export interface MockRequestOptions {
  method?: string;
  path?: string;
  headers?: HeaderMap;
  body?: Record<string, unknown>;
  rawBody?: Buffer;
}

export function createMockRequest(options: MockRequestOptions = {}) {
  const headers: HeaderMap = {};
  for (const [key, value] of Object.entries(options.headers ?? {})) {
    headers[key.toLowerCase()] = value;
  }

  const body = options.body ?? {text: "hello", context: {}};
  const rawBody = options.rawBody ?? Buffer.from(JSON.stringify(body), "utf8");

  return {
    method: options.method ?? "POST",
    path: options.path,
    url: options.path,
    header(name: string) {
      return headers[name.toLowerCase()];
    },
    body,
    rawBody,
  };
}
