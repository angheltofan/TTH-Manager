// Supabase Edge Function: generate_parent_setup_invite
//
// Admin-only fallback for parent onboarding when email delivery is not
// available (Resend/SMTP unavailable, deliverability problems, etc.).
//
//   POST /generate_parent_setup_invite
//   body: { parent_id }
//
// Flow:
//   1. verify caller JWT
//   2. verify caller is admin via the `is_admin()` server RPC (same
//      check used by create_parent_and_link_child)
//   3. load the parent's email from `auth.users` via the admin client
//   4. look up the parent's first name from `profiles` for the message
//   5. invalidate any prior unconsumed tokens for this parent so older
//      activation codes stop working the moment a new one is generated
//   6. mint a fresh 256-bit raw token, store sha256(token||pepper),
//      24h expiry — exactly the same scheme as create_parent_and_link_child
//   7. return { email, code (raw token), setup_url, message }
//
// The raw token (`code`) is returned ONLY to the calling admin so they
// can hand it to the parent via WhatsApp / Gmail / SMS / paper. The DB
// still stores only the hash, so the security model is unchanged from
// the email path: even a full DB leak yields no usable codes.
//
// This function never sends email. The admin is the courier. To switch
// back to email-only onboarding, simply stop calling this endpoint.

declare const Deno: {
  env: { get(key: string): string | undefined };
  serve(handler: (req: Request) => Response | Promise<Response>): unknown;
};

import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.49.4";

import { generateRawToken, hashToken } from "../_shared/setup_token.ts";

// ── Types ───────────────────────────────────────────────────────────────────

interface Payload {
  parent_id: string;
}

interface SuccessResponse {
  email: string;
  code: string;
  setup_url: string;
  message: string;
  expires_at: string;
}

interface ErrorResponse {
  error: string;
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

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(s: string): boolean {
  return UUID_RE.test(s);
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isEmail(s: string): boolean {
  return EMAIL_RE.test(s) && s.length <= 254;
}

/// Builds the ready-to-paste Romanian onboarding message exactly as the
/// product spec asks. Stays inside the function so the format is the
/// single source of truth — the Flutter dialog just renders what comes
/// back here and the admin can copy it verbatim.
function buildMessage(args: {
  setupUrl: string;
  email: string;
  code: string;
}): string {
  const { setupUrl, email, code } = args;
  return [
    "Bună ziua! Pentru acces în aplicația TTH Manager, vă rugăm să intrați pe:",
    "",
    setupUrl,
    "",
    `Email: ${email}`,
    `Cod activare: ${code}`,
    "",
    "După introducerea codului, vă puteți seta parola și accesa contul de părinte.",
  ].join("\n");
}

// ── Entry point ─────────────────────────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" } as ErrorResponse);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return jsonResponse(401, { error: "Missing Authorization header" });
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const SETUP_TOKEN_PEPPER = Deno.env.get("SETUP_TOKEN_PEPPER");
  const PUBLIC_APP_URL = Deno.env.get("PUBLIC_APP_URL") ??
    "https://tth-manager.vercel.app";

  if (!SUPABASE_URL || !ANON_KEY || !SERVICE_KEY) {
    console.error("Missing env: SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY");
    return jsonResponse(500, { error: "Server misconfigured" });
  }
  if (!SETUP_TOKEN_PEPPER) {
    console.error("Missing env: SETUP_TOKEN_PEPPER");
    return jsonResponse(500, { error: "Token env missing" });
  }

  // 1+2. JWT + admin check. Same RPC the create function uses, run under
  //      the caller's identity (NOT the service key).
  const userClient: SupabaseClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const {
    data: { user: caller },
    error: callerErr,
  } = await userClient.auth.getUser();
  if (callerErr || !caller) {
    return jsonResponse(401, { error: "Invalid JWT" });
  }
  const { data: isAdminResult, error: isAdminErr } = await userClient.rpc(
    "is_admin",
  );
  if (isAdminErr) {
    console.error("is_admin RPC failed", isAdminErr);
    return jsonResponse(500, { error: "Admin check failed" });
  }
  if (isAdminResult !== true) {
    return jsonResponse(403, { error: "Not admin" });
  }

  // 3. Parse body.
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    return jsonResponse(400, { error: "Invalid JSON body" });
  }
  const body = (raw ?? {}) as Partial<Payload>;
  const parentId = String(body.parent_id ?? "").trim();
  if (!isUuid(parentId)) {
    return jsonResponse(400, { error: "Invalid parent_id" });
  }

  const adminClient: SupabaseClient = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 4. Load the parent's email from auth.users + first_name from profiles.
  const { data: authData, error: authErr } = await adminClient.auth.admin
    .getUserById(parentId);
  if (authErr || !authData?.user) {
    console.error("getUserById failed", authErr);
    return jsonResponse(404, {
      error: "Părintele nu a fost găsit.",
    } as ErrorResponse);
  }
  const email = (authData.user.email ?? "").trim().toLowerCase();
  if (!isEmail(email)) {
    return jsonResponse(409, {
      error:
        "Contul de părinte nu are un email valid asociat. " +
        "Contactați administratorul Supabase.",
    } as ErrorResponse);
  }

  const { data: profileRow } = await adminClient
    .from("profiles")
    .select("first_name, role")
    .eq("id", parentId)
    .maybeSingle();
  const profile = profileRow as { first_name: string | null; role: string | null } | null;
  if (profile && profile.role !== "parent") {
    return jsonResponse(409, {
      error:
        "Acest cont nu are rol de părinte. Invitațiile manuale sunt valabile " +
        "doar pentru părinți.",
    } as ErrorResponse);
  }

  // 5. Invalidate any prior unconsumed tokens for this parent. The
  //    raw value of those tokens is gone (only the hash was stored),
  //    so any previously-shared code becomes useless from this moment.
  const { error: invalidateErr } = await adminClient
    .from("parent_setup_tokens")
    .update({ consumed_at: new Date().toISOString() })
    .eq("parent_id", parentId)
    .is("consumed_at", null);
  if (invalidateErr) {
    console.error("invalidate prior tokens failed", invalidateErr);
    return jsonResponse(500, {
      error: "Nu am putut invalida codurile anterioare.",
    } as ErrorResponse);
  }

  // 6. Mint the new token.
  const rawToken = generateRawToken();
  let tokenHash: string;
  try {
    tokenHash = await hashToken(rawToken, SETUP_TOKEN_PEPPER);
  } catch (e) {
    console.error("hashToken threw", e);
    return jsonResponse(500, {
      error: "Eroare server la generarea codului.",
    } as ErrorResponse);
  }
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const { error: insertErr } = await adminClient
    .from("parent_setup_tokens")
    .insert({
      parent_id: parentId,
      email,
      token_hash: tokenHash,
      expires_at: expiresAt,
    });
  if (insertErr) {
    console.error("parent_setup_tokens insert failed", insertErr);
    return jsonResponse(500, {
      error: "Nu am putut emite codul de activare.",
    } as ErrorResponse);
  }

  // 7. Build the setup URL and the copy-paste message.
  const setupUrl = `${PUBLIC_APP_URL.replace(/\/$/, "")}` +
    `/parent-setup?token=${encodeURIComponent(rawToken)}` +
    `&email=${encodeURIComponent(email)}`;
  const message = buildMessage({ setupUrl, email, code: rawToken });

  const success: SuccessResponse = {
    email,
    code: rawToken,
    setup_url: setupUrl,
    message,
    expires_at: expiresAt,
  };
  return jsonResponse(200, success);
});
