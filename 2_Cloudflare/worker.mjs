import bundledPayload from "../1_GitHub/2.lua";

const MAX_FORM_BYTES = 1024;
const COMMON_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Cache-Control": "no-store, max-age=0",
  "X-Content-Type-Options": "nosniff",
};

class RequestError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function response(body, status = 200, headers = {}) {
  return new Response(body, {
    status,
    headers: {
      ...COMMON_HEADERS,
      "Content-Type": "text/plain; charset=utf-8",
      ...headers,
    },
  });
}

async function readForm(request) {
  const contentType = (request.headers.get("Content-Type") || "")
    .split(";", 1)[0].trim().toLowerCase();
  if (contentType !== "application/x-www-form-urlencoded") {
    throw new RequestError(400, "Expected form data");
  }
  const contentLength = request.headers.get("Content-Length");
  if (contentLength !== null) {
    if (!/^\d+$/.test(contentLength)) throw new RequestError(400, "Invalid request length");
    if (Number(contentLength) > MAX_FORM_BYTES) throw new RequestError(413, "Request too large");
  }

  let text = "";
  let size = 0;
  if (request.body) {
    const reader = request.body.getReader();
    const decoder = new TextDecoder("utf-8", { fatal: true });
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > MAX_FORM_BYTES) {
          await reader.cancel().catch(() => {});
          throw new RequestError(413, "Request too large");
        }
        text += decoder.decode(value, { stream: true });
      }
      text += decoder.decode();
    } catch (error) {
      if (error instanceof RequestError) throw error;
      throw new RequestError(400, "Invalid request body");
    } finally {
      reader.releaseLock();
    }
  }
  const form = new URLSearchParams(text);
  if (form.getAll("key_path").length !== 1 || [...form.keys()].some(key => key !== "key_path")) {
    throw new RequestError(400, "Expected one key_path");
  }
  return form.get("key_path");
}

export function createHandler(payload = bundledPayload) {
  if (typeof payload !== "string") throw new TypeError("Bundled Lua source must be text");
  return async function fetch(request) {
    try {
      const path = new URL(request.url).pathname;
      if (!["/", "/2.lua", "/health"].includes(path)) return response("Not found", 404);
      const method = request.method.toUpperCase();
      if (method === "OPTIONS") return response(null, 204);
      if (method === "GET" || method === "HEAD") {
        if (path === "/health") {
          return response(method === "HEAD" ? null : JSON.stringify({ ok: true, file: "2.lua" }), 200, {
            "Content-Type": "application/json; charset=utf-8",
          });
        }
        if (path === "/2.lua") return response(method === "HEAD" ? null : payload);
        return response("Not found", 404);
      }
      if (method === "POST" && path === "/") {
        if (await readForm(request) !== "2.lua") return response("Not found", 404);
        return response(payload);
      }
      return response("Method not allowed", 405, {
        Allow: path === "/" ? "POST, OPTIONS" : "GET, HEAD, OPTIONS",
      });
    } catch (error) {
      return error instanceof RequestError
        ? response(error.message, error.status)
        : response("Internal error", 500);
    }
  };
}

export default { fetch: createHandler() };
