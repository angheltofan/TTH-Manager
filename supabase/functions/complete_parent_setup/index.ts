// Supabase Edge Function: complete_parent_setup
//
// Public endpoint (verify_jwt=false in supabase/config.toml). Redeems
// a one-time parent setup token issued by `create_parent_and_link_child`.
//
//   POST /complete_parent_setup
//   body: { email, token, password }
//
// Flow:
//   1. Validate body (email, token shape, password ≥6 chars).
//   2. Hash sha256(token || SETUP_TOKEN_PEPPER).
//   3. Look up the latest unconsumed parent_setup_tokens row by email.
//   4. If the stored token_hash matches AND row is not expired AND
//      attempt_count < 5:
//        a. auth.admin.updateUserById(parent_id, { password })
//        b. mark token consumed (consumed_at = now())
//        c. return 200 { success: true }
//   5. Otherwise:
//        - Increment attempt_count on the candidate row (if any) so
//          brute force is bounded by 5 tries per token, then expiry.
//        - Return a generic-but-helpful error code so the Flutter side
//          can humanize it without leaking which step failed.
//
// Security:
//   - 256-bit token + sha256(pepper); never stored raw.
//   - Per-token attempt counter; 5 strikes locks the token.
//   - 24h expiry on the token row.
//   - Service-role mutations only; RLS denies anon/auth direct access.
//   - Constant-time hash compare via byte loop (token_hash is hex, so
//     length is fixed; std equality is acceptable, but we do it
//     explicitly to make intent obvious).

declare const Deno: {
  env: { get(key: string): string | undefined };
  serve(handler: (req: Request) => Response | Promise<Response>): unknown;
};

import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.49.4";

import { hashToken } from "../_shared/setup_token.ts";

// ── Types ───────────────────────────────────────────────────────────────────

interface Payload {
  email: string;
  token: string;
  password: string;
}

interface SuccessResponse {
  success: true;
}

interface ErrorResponse {
  error: string;
  code:
    | "invalid_body"
    | "invalid_token"
    | "token_expired"
    | "token_locked"
    | "password_update_failed"
    | "server_error";
}

// ── Helpers ─────────────────────────────────────────────────────────────────

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isEmail(s: string): boolean {
  return EMAIL_RE.test(s) && s.length <= 254;
}

function constantTimeEq(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i += 1) {
    r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return r === 0;
}

// ── Entry point ─────────────────────────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, {
      error: "Method not allowed",
      code: "invalid_body",
    } as ErrorResponse);
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const SETUP_TOKEN_PEPPER = Deno.env.get("SETUP_TOKEN_PEPPER");
  if (!SUPABASE_URL || !SERVICE_KEY || !SETUP_TOKEN_PEPPER) {
    console.error("Missing env in complete_parent_setup");
    return jsonResponse(500, {
      error: "Server misconfigured",
      code: "server_error",
    } as ErrorResponse);
  }

  // Parse + validate body.
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    return jsonResponse(400, {
      error: "Invalid JSON body",
      code: "invalid_body",
    } as ErrorResponse);
  }
  const body = (raw ?? {}) as Partial<Payload>;
  const email = String(body.email ?? "").trim().toLowerCase();
  const token = String(body.token ?? "").trim();
  const password = String(body.password ?? "");

  if (!isEmail(email)) {
    return jsonResponse(400, {
      error: "Invalid email",
      code: "invalid_body",
    } as ErrorResponse);
  }
  // Token issued as base64url of 32 random bytes → 43 chars, charset
  // [A-Za-z0-9_-]. Be strict so garbage payloads short-circuit before
  // hashing / DB roundtrip.
  if (!/^[A-Za-z0-9_-]{20,128}$/.test(token)) {
    return jsonResponse(400, {
      error: "Invalid token",
      code: "invalid_body",
    } as ErrorResponse);
  }
  if (password.length < 6 || password.length > 256) {
    return jsonResponse(400, {
      error: "Password must be at least 6 characters",
      code: "invalid_body",
    } as ErrorResponse);
  }

  const adminClient: SupabaseClient = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Look up the latest unconsumed token row for this email. We do NOT
  // filter by token_hash in SQL — we filter by email only, then compare
  // hashes in app code, so the per-token attempt_count update has a
  // stable target even when the supplied token is wrong.
  const { data: row, error: selectErr } = await adminClient
    .from("parent_setup_tokens")
    .select("id, parent_id, token_hash, expires_at, attempt_count")
    .eq("email", email)
    .is("consumed_at", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (selectErr) {
    console.error("parent_setup_tokens select failed", selectErr);
    return jsonResponse(500, {
      error: "Server error",
      code: "server_error",
    } as ErrorResponse);
  }
  if (!row) {
    return jsonResponse(400, {
      error: "Link invalid sau folosit deja.",
      code: "invalid_token",
    } as ErrorResponse);
  }

  const rec = row as {
    id: string;
    parent_id: string;
    token_hash: string;
    expires_at: string;
    attempt_count: number;
  };

  // Hard expiry — drop without incrementing the counter.
  const expiresAt = Date.parse(rec.expires_at);
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    return jsonResponse(400, {
      error: "Linkul a expirat. Cere o invitație nouă.",
      code: "token_expired",
    } as ErrorResponse);
  }

  // Lockout: 5 strikes per token.
  if (rec.attempt_count >= 5) {
    return jsonResponse(429, {
      error:
        "Prea multe încercări pentru acest link. Cere o invitație nouă.",
      code: "token_locked",
    } as ErrorResponse);
  }

  // Hash the supplied token with the pepper and compare.
  let suppliedHash: string;
  try {
    suppliedHash = await hashToken(token, SETUP_TOKEN_PEPPER);
  } catch (e) {
    console.error("hashToken failed", e);
    return jsonResponse(500, {
      error: "Server error",
      code: "server_error",
    } as ErrorResponse);
  }

  if (!constantTimeEq(suppliedHash, rec.token_hash)) {
    // Wrong token for this email — increment the candidate row's
    // counter so an attacker can't repeatedly probe.
    await adminClient
      .from("parent_setup_tokens")
      .update({ attempt_count: rec.attempt_count + 1 })
      .eq("id", rec.id);
    return jsonResponse(400, {
      error: "Link invalid sau folosit deja.",
      code: "invalid_token",
    } as ErrorResponse);
  }

  // Valid token. Set the password.
  const { error: pwErr } = await adminClient.auth.admin.updateUserById(
    rec.parent_id,
    { password },
  );
  if (pwErr) {
    console.error("updateUserById failed", pwErr);
    return jsonResponse(500, {
      error: "Nu am putut seta parola. Încearcă din nou.",
      code: "password_update_failed",
    } as ErrorResponse);
  }

  // Consume the token. If this fails we still return success because
  // the password is set; the token will naturally expire in <24h.
  const { error: consumeErr } = await adminClient
    .from("parent_setup_tokens")
    .update({ consumed_at: new Date().toISOString() })
    .eq("id", rec.id);
  if (consumeErr) {
    console.warn(
      "consume token mark failed (password already set)",
      consumeErr,
    );
  }

  return jsonResponse(200, { success: true } as SuccessResponse);
});
