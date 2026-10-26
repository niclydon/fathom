// fathom-gate: the relying-party backend for the Fathom Club gate.
//
//   GET  /health            -> { ok, rp_id, app_id, enrolled }
//   POST /rp-context        -> { flow } -> a fresh signed rp_context
//   POST /verify            -> { flow, result, expected_session_id? }
//   POST /reset-enrollment  -> clears the enrolled binding (prototype)
//
// All POSTs require Authorization: Bearer <FATHOM_GATE_TOKEN>.
// The signing key comes from the environment (WORLD_FATHOM_SIGNING_KEY,
// materialized from your secrets store) and never leaves this process.
//
// Privacy: the store keeps the verified session_id (an opaque World
// session handle, not an identifier of the human) plus a SHA-256 hash of
// the nullifier. A humanId is never received, stored, or logged here.
//
// Binding model: the app enrolls the chip locally first (Keychain).
// The first verified World ID presence proof after that ("enroll" flow)
// records the session_id + nullifier hash here, which completes the
// chip <-> nullifier binding. Later proofs ("prove" flow) must present
// the same session_id, and each proof's session nullifiers are single
// use (replay is rejected).

import { createServer } from "node:http";
import { createHash, timingSafeEqual } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { signRequest } from "@worldcoin/idkit-core/signing";

const RP_ID = process.env.FATHOM_RP_ID;
const APP_ID = process.env.FATHOM_APP_ID;
const SIGNING_KEY = process.env.WORLD_FATHOM_SIGNING_KEY;
const TOKEN = process.env.FATHOM_GATE_TOKEN;
const PORT = Number(process.env.FATHOM_GATE_PORT || 7902);
const HOST = process.env.FATHOM_GATE_HOST || "127.0.0.1";
const DATA_DIR = process.env.FATHOM_GATE_DATA || new URL("./data", import.meta.url).pathname;
const ENROLL_ACTION = "fathom-enroll";
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36";

if (!RP_ID) { console.error("FATHOM_RP_ID missing"); process.exit(2); }
if (!APP_ID) { console.error("FATHOM_APP_ID missing"); process.exit(2); }
if (!SIGNING_KEY) { console.error("WORLD_FATHOM_SIGNING_KEY missing"); process.exit(2); }
if (!TOKEN) { console.error("FATHOM_GATE_TOKEN missing"); process.exit(2); }

mkdirSync(DATA_DIR, { recursive: true });
const statePath = DATA_DIR + "/state.json";
let state = { enrolled: null, seenSessionNullifiers: [], verifyLog: [] };
try { state = JSON.parse(readFileSync(statePath, "utf8")); } catch { /* fresh */ }
function save() { writeFileSync(statePath, JSON.stringify(state, null, 2), { mode: 0o600 }); }
const sha256 = (s) => createHash("sha256").update(String(s)).digest("hex");

function authed(req) {
  const h = req.headers.authorization || "";
  const given = h.startsWith("Bearer ") ? h.slice(7) : "";
  const a = Buffer.from(given), b = Buffer.from(TOKEN);
  return a.length === b.length && timingSafeEqual(a, b);
}

async function readBody(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  return JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
}

function send(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { "content-type": "application/json" });
  res.end(body);
}

function extractNullifiers(result) {
  const out = [];
  for (const r of result?.responses || []) {
    if (r.nullifier) out.push(r.nullifier);
    if (r.session_nullifier) out.push(r.session_nullifier);
  }
  return out;
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, "http://x");
    if (req.method === "GET" && url.pathname === "/health") {
      return send(res, 200, { ok: true, rp_id: RP_ID, app_id: APP_ID, enrolled: !!state.enrolled });
    }
    if (req.method !== "POST") return send(res, 404, { error: "not_found" });
    if (!authed(req)) return send(res, 401, { error: "unauthorized" });

    if (url.pathname === "/rp-context") {
      const { flow } = await readBody(req);
      // Session create/prove signatures carry no action; the
      // enrollment uniqueness request signs its action.
      const sig = flow === "enroll"
        ? signRequest({ action: ENROLL_ACTION, signingKeyHex: SIGNING_KEY })
        : signRequest({ signingKeyHex: SIGNING_KEY });
      return send(res, 200, {
        rp_id: RP_ID, app_id: APP_ID,
        nonce: sig.nonce, created_at: sig.createdAt, expires_at: sig.expiresAt,
        signature: sig.sig,
      });
    }

    if (url.pathname === "/reset-enrollment") {
      // Prototype reset: the deployment is single-member, so resetting
      // clears the one enrolled binding and the replay store, allowing
      // a fresh chip <-> nullifier enrollment. A production version
      // would key bindings per member and require a stronger reset
      // ceremony; see the About screen copy in the app.
      state.enrolled = null;
      state.seenSessionNullifiers = [];
      state.verifyLog.push({ at: new Date().toISOString(), flow: "reset", ok: true });
      save();
      return send(res, 200, { reset: true });
    }

    if (url.pathname === "/verify") {
      const { flow, result, expected_session_id } = await readBody(req);
      if (!result || typeof result !== "object") return send(res, 400, { verified: false, error: "missing_result" });
      if (result.environment && result.environment !== "production") {
        return send(res, 422, { verified: false, error: "environment_mismatch" });
      }
      const resp = await fetch(`https://developer.world.org/api/v4/verify/${RP_ID}`, {
        method: "POST",
        headers: { "content-type": "application/json", "user-agent": UA },
        body: JSON.stringify(result),
      });
      const verifyBody = await resp.json().catch(() => ({}));
      if (!resp.ok || verifyBody.success === false) {
        state.verifyLog.push({ at: new Date().toISOString(), flow, ok: false, status: resp.status });
        save();
        return send(res, 422, { verified: false, error: "portal_rejected", status: resp.status, detail: verifyBody });
      }

      const nullifiers = extractNullifiers(result).map(sha256);
      if (flow === "enroll") {
        if (result.action && result.action !== ENROLL_ACTION) {
          return send(res, 422, { verified: false, error: "action_mismatch" });
        }
        if (!result.session_id) return send(res, 422, { verified: false, error: "no_session_id" });
        if (nullifiers.length === 0) return send(res, 422, { verified: false, error: "no_nullifier" });
        if (state.enrolled && state.enrolled.nullifier_sha256 !== nullifiers[0]) {
          return send(res, 422, { verified: false, error: "different_human_enrolled" });
        }
        state.enrolled = { session_id: result.session_id, nullifier_sha256: nullifiers[0], at: new Date().toISOString() };
        state.verifyLog.push({ at: new Date().toISOString(), flow, ok: true });
        save();
        return send(res, 200, { verified: true, session_id: result.session_id });
      }

      if (flow === "prove") {
        if (!state.enrolled) return send(res, 422, { verified: false, error: "not_enrolled" });
        if (!result.session_id || result.session_id !== state.enrolled.session_id) {
          return send(res, 422, { verified: false, error: "session_mismatch" });
        }
        if (expected_session_id && expected_session_id !== state.enrolled.session_id) {
          return send(res, 422, { verified: false, error: "expected_mismatch" });
        }
        for (const n of nullifiers) {
          if (state.seenSessionNullifiers.includes(n)) {
            return send(res, 422, { verified: false, error: "nullifier_replayed" });
          }
        }
        state.seenSessionNullifiers.push(...nullifiers);
        state.verifyLog.push({ at: new Date().toISOString(), flow, ok: true });
        save();
        return send(res, 200, { verified: true, session_id: result.session_id });
      }

      return send(res, 400, { verified: false, error: "unknown_flow" });
    }

    return send(res, 404, { error: "not_found" });
  } catch (err) {
    console.error("gate error:", err?.message || err);
    return send(res, 500, { error: "internal" });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`fathom-gate listening on ${HOST}:${PORT} rp=${RP_ID}`);
});
