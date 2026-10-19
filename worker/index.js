/**
 * @typedef {object} Env
 * @property {string} GITHUB_WEBHOOK_SECRET
 * @property {string} GITHUB_DISPATCH_TOKEN
 */

/**
 * @typedef {object} GitHubCreatePayload
 * @property {"branch" | "tag"} ref_type
 * @property {string} ref
 */

/** @typedef {GitHubCreatePayload | { ref_type?: undefined }} GitHubWebhookPayload */

const dispatchUrl =
  "https://api.github.com/repos/jnooree/abseil-releases/dispatches";
const attemptTimeout = 2000;
const requestTimeout = 8000;
const backoffs = [0, 250, 750];

/** @param {string | null} value */
function retryAfterMilliseconds(value) {
  if (value === null) return 0;
  if (/^\d+$/.test(value)) return Number(value) * 1000;
  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) ? Math.max(0, timestamp - Date.now()) : 0;
}

/**
 * @param {ArrayBuffer} body
 * @param {string | null} signature
 * @param {string} secret
 */
async function verifySignature(body, signature, secret) {
  if (!/^sha256=[0-9a-f]{64}$/.test(signature ?? "")) return false;
  const bytes = Uint8Array.from(signature.slice(7).match(/../g), (hex) =>
    parseInt(hex, 16),
  );
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  return crypto.subtle.verify("HMAC", key, bytes, body);
}

/**
 * @param {string} ref
 * @param {string} token
 * @param {number} deadline
 * @param {AbortSignal} signal
 */
async function dispatchTag(ref, token, deadline, signal) {
  let retryAfter = 0;
  let failure = new Error("GitHub dispatch deadline exceeded");
  for (let attempt = 0; attempt < backoffs.length; attempt++) {
    const delay = Math.max(backoffs[attempt], retryAfter);
    if (delay > 0) await new Promise((resolve) => setTimeout(resolve, delay));
    if (Date.now() + attemptTimeout > deadline) throw failure;

    retryAfter = 0;
    let response;
    try {
      response = await fetch(dispatchUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          "User-Agent": "abseil-release-webhook",
        },
        body: JSON.stringify({
          event_type: "release-tag",
          client_payload: { ref },
        }),
        signal: AbortSignal.any([signal, AbortSignal.timeout(attemptTimeout)]),
        redirect: "follow",
      });
    } catch (error) {
      signal.throwIfAborted();
      console.warn(error);
      failure = error;
      continue;
    }
    console.log(
      JSON.stringify({ attempt: attempt + 1, status: response.status }),
    );
    await response.body?.cancel();
    if (response.status === 204) return;
    failure = new Error(`GitHub dispatch failed with HTTP ${response.status}`);
    if (
      response.status !== 429 &&
      !(response.status >= 500 && response.status < 600)
    ) {
      throw failure;
    }
    retryAfter = retryAfterMilliseconds(response.headers.get("Retry-After"));
  }
  throw failure;
}

/**
 * @param {Request} request
 * @param {Env} env
 * @param {number} deadline
 * @param {AbortSignal} signal
 */
async function handleRequest(request, env, deadline, signal) {
  const body = await request.arrayBuffer();
  if (
    !(await verifySignature(
      body,
      request.headers.get("X-Hub-Signature-256"),
      env.GITHUB_WEBHOOK_SECRET,
    ))
  ) {
    return new Response("Invalid signature", { status: 401 });
  }

  const json = new TextDecoder().decode(body);
  /** @type {GitHubWebhookPayload} */
  const payload = JSON.parse(json);
  const event = request.headers.get("X-GitHub-Event");
  if (event !== "create" || payload.ref_type !== "tag") {
    return new Response(null, { status: 204 });
  }

  console.log(json);
  await dispatchTag(payload.ref, env.GITHUB_DISPATCH_TOKEN, deadline, signal);
  return new Response(null, { status: 204 });
}

export default {
  /**
   * @param {Request} request
   * @param {Env} env
   */
  fetch(request, env) {
    const deadline = Date.now() + requestTimeout;
    const signal = AbortSignal.timeout(requestTimeout);
    const expired = new Promise((_, reject) => {
      signal.addEventListener("abort", () => reject(signal.reason), {
        once: true,
      });
    });
    return Promise.race([
      handleRequest(request, env, deadline, signal),
      expired,
    ]);
  },
};
