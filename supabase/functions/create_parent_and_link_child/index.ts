// Supabase Edge Function: create_parent_and_link_child
//
// Admin-only flow that onboards a parent.
//
//   1. verify caller JWT
//   2. verify caller is admin (server-side `is_admin()` RPC, run as the
//      caller's JWT — same check the Flutter client uses for guarding)
//   3. validate the request body
//   4. look up auth.users by email
//        • if found AND profile.role ∈ {admin, trainer} → 409 (single-role guard)
//        • if found AND profile.role == 'parent' (or no profile yet) → reuse
//        • if not found → create with admin.createUser, email_confirm=true, NO password
//   5. upsert public.profiles with role='parent' (via the
//      `upsert_parent_profile` RPC — pins the role server-side as
//      defense-in-depth)
//   6. upsert public.child_parents link, returning the link id
//   7. if a brand-new auth user was created → issue a fresh custom
//      setup token: invalidate prior unconsumed tokens for this parent,
//      insert sha256(token||pepper) in parent_setup_tokens, send the
//      setup email through Resend with /parent-setup?token=…&email=…
//   8. respond with { parent_id, link_id, invite_sent }
//
// Response shape unchanged for the Flutter caller; `invite_sent` now
// means "custom setup email dispatched" rather than "Supabase invite
// email dispatched". Same semantics from the UI's perspective.
//
// Never accepts a role from the client. Service role key is only ever
// read from environment, never returned in any response. The function
// runs with `verify_jwt = true` (Supabase default) so the platform
// rejects unsigned requests before our code runs.

declare const Deno: {
  env: { get(key: string): string | undefined };
  serve(handler: (req: Request) => Response | Promise<Response>): unknown;
};

import {
  createClient,
  SupabaseClient,
  User,
} from "https://esm.sh/@supabase/supabase-js@2.49.4";

import {
  generateRawToken,
  hashToken,
  sendSetupEmail,
} from "../_shared/setup_token.ts";

// ── Types ───────────────────────────────────────────────────────────────────

interface Payload {
  child_id: string;
  first_name: string;
  last_name: string;
  email: string;
  relationship?: string | null;
  is_primary?: boolean;
}

interface SuccessResponse {
  parent_id: string;
  link_id: string;
  invite_sent: boolean;
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
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isUuid(s: string): boolean {
  return UUID_RE.test(s);
}

function isEmail(s: string): boolean {
  return EMAIL_RE.test(s) && s.length <= 254;
}

// Paginated lookup of an auth user by email. The supabase-js admin API
// does not expose a direct email filter, so we page through and match
// client-side. perPage=1000, capped at 5 pages → handles installations
// up to ~5k users. Log a warning above that threshold.
async function findAuthUserByEmail(
  admin: SupabaseClient,
  email: string,
): Promise<User | null> {
  const needle = email.toLowerCase();
  for (let page = 1; page <= 5; page += 1) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw error;
    const users = data.users ?? [];
    const found = users.find((u) => (u.email ?? "").toLowerCase() === needle);
    if (found) return found;
    if (users.length < 1000) return null; // no more pages
  }
  console.warn(
    "[create_parent_and_link_child] listUsers paged past 5000; email lookup may miss",
  );
  return null;
}

// Tries to extract a Resend-style "to a verified domain" failure so we
// can surface a clearer 502 to the admin. Resend free tier rejects
// sends to arbitrary recipients unless the sending domain is verified;
// this used to be the #1 deploy-day footgun.
function isUnverifiedDomainError(msg: string): boolean {
  const m = msg.toLowerCase();
  return m.includes("verified domain") ||
    m.includes("domain not verified") ||
    m.includes("validation_error");
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
  const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
  const EMAIL_FROM = Deno.env.get("EMAIL_FROM");
  const SETUP_TOKEN_PEPPER = Deno.env.get("SETUP_TOKEN_PEPPER");
  const PUBLIC_APP_URL = Deno.env.get("PUBLIC_APP_URL") ??
    "https://tth-manager.vercel.app";

  if (!SUPABASE_URL || !ANON_KEY || !SERVICE_KEY) {
    console.error("Missing env: SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY");
    return jsonResponse(500, { error: "Server misconfigured" });
  }
  if (!RESEND_API_KEY || !EMAIL_FROM || !SETUP_TOKEN_PEPPER) {
    console.error(
      "Missing env: RESEND_API_KEY / EMAIL_FROM / SETUP_TOKEN_PEPPER",
    );
    return jsonResponse(500, { error: "Email/token env missing" });
  }

  // Client bound to the caller's JWT — used to verify identity + admin role.
  const userClient: SupabaseClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1+2. JWT + admin check.
  const {
    data: { user: caller },
    error: callerErr,
  } = await userClient.auth.getUser();
  if (callerErr || !caller) {
    return jsonResponse(401, { error: "Invalid JWT" });
  }
  const { data: isAdminResult, error: isAdminErr } =
    await userClient.rpc("is_admin");
  if (isAdminErr) {
    console.error("is_admin RPC failed", isAdminErr);
    return jsonResponse(500, { error: "Admin check failed" });
  }
  if (isAdminResult !== true) {
    return jsonResponse(403, { error: "Not admin" });
  }

  // 3. Parse + validate body.
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    return jsonResponse(400, { error: "Invalid JSON body" });
  }
  const body = (raw ?? {}) as Partial<Payload>;

  const childId = String(body.child_id ?? "").trim();
  const firstName = String(body.first_name ?? "").trim();
  const lastName = String(body.last_name ?? "").trim();
  const email = String(body.email ?? "").trim().toLowerCase();
  const relationshipRaw =
    body.relationship === undefined || body.relationship === null
      ? null
      : String(body.relationship).trim();
  const relationship =
    relationshipRaw && relationshipRaw.length > 0 ? relationshipRaw : null;
  const isPrimary = body.is_primary === true;

  if (!isUuid(childId)) {
    return jsonResponse(400, { error: "Invalid child_id" });
  }
  if (firstName.length === 0 || firstName.length > 100) {
    return jsonResponse(400, { error: "Invalid first_name" });
  }
  if (lastName.length === 0 || lastName.length > 100) {
    return jsonResponse(400, { error: "Invalid last_name" });
  }
  if (!isEmail(email)) {
    return jsonResponse(400, { error: "Invalid email" });
  }
  if (relationship !== null && relationship.length > 50) {
    return jsonResponse(400, { error: "Invalid relationship" });
  }

  // 4. Admin client — service role, bypasses RLS. Used for the rest of the
  //    flow. Never returned to the caller.
  const adminClient: SupabaseClient = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 5. Look up existing auth user, otherwise create one (NO password).
  //    For existing users, enforce the single-role-per-email rule.
  let parentId: string;
  let isBrandNewUser = false;
  try {
    const existing = await findAuthUserByEmail(adminClient, email);
    if (existing) {
      const { data: existingProfile, error: profileErr } = await adminClient
        .from("profiles")
        .select("role")
        .eq("id", existing.id)
        .maybeSingle();
      if (profileErr) {
        console.error("existing profile lookup failed", profileErr);
        return jsonResponse(500, { error: "Profile lookup failed" });
      }
      if (existingProfile !== null) {
        const role = (existingProfile as { role: string | null }).role;
        if (role === "admin" || role === "trainer") {
          return jsonResponse(409, {
            error:
              "Acest email aparține deja unui cont de staff. Folosește alt email pentru părinte.",
          });
        }
        if (role !== "parent") {
          return jsonResponse(409, {
            error:
              "Acest email aparține unui cont cu rol nerecunoscut. Contactați administratorul.",
          });
        }
      }
      // existingProfile === null  → no profile row, will be created with role='parent'.
      // existingProfile.role === 'parent' → reuse and re-link. No new setup email.
      parentId = existing.id;
    } else {
      // Brand-new parent: create auth user with email confirmed, no
      // password. They will set the password through the custom setup
      // link we send below.
      const { data: created, error: createErr } =
        await adminClient.auth.admin.createUser({
          email,
          email_confirm: true,
        });
      if (createErr || !created?.user) {
        console.error("admin.createUser failed", createErr);
        return jsonResponse(502, { error: "User creation failed" });
      }
      parentId = created.user.id;
      isBrandNewUser = true;
    }
  } catch (e) {
    console.error("auth lookup/create failed", e);
    return jsonResponse(500, { error: "Auth lookup failed" });
  }

  // 6. Upsert profile with role pinned server-side.
  {
    const { error: upsertErr } = await adminClient.rpc(
      "upsert_parent_profile",
      {
        p_id: parentId,
        p_first_name: firstName,
        p_last_name: lastName,
      },
    );
    if (upsertErr) {
      console.error("upsert_parent_profile failed", upsertErr);
      return jsonResponse(500, { error: "Profile upsert failed" });
    }
  }

  // 7. Upsert link in child_parents and return its id.
  let linkId: string;
  try {
    const { data: linkRow, error: linkErr } = await adminClient
      .from("child_parents")
      .upsert(
        {
          child_id: childId,
          parent_id: parentId,
          relationship,
          is_primary: isPrimary,
          created_by: caller.id,
        },
        { onConflict: "child_id,parent_id" },
      )
      .select("id")
      .single();
    if (linkErr || !linkRow?.id) {
      console.error("child_parents upsert failed", linkErr);
      return jsonResponse(500, { error: "Link creation failed" });
    }
    linkId = linkRow.id as string;
  } catch (e) {
    console.error("child_parents upsert threw", e);
    return jsonResponse(500, { error: "Link creation failed" });
  }

  // 8. If this is a brand-new parent, issue a setup token and send the
  //    email. For reused parents (existing 'parent' profile), skip —
  //    they already have a password from their first onboarding.
  let setupEmailSent = false;
  if (isBrandNewUser) {
    try {
      // 8a. Invalidate any prior unconsumed tokens for this parent so
      //     stale links from earlier re-invite attempts stop working.
      await adminClient
        .from("parent_setup_tokens")
        .update({ consumed_at: new Date().toISOString() })
        .eq("parent_id", parentId)
        .is("consumed_at", null);

      // 8b. Mint a fresh raw token, store its hash, hand the raw value
      //     to the email layer. Raw token never leaves this scope.
      const rawToken = generateRawToken();
      const tokenHash = await hashToken(rawToken, SETUP_TOKEN_PEPPER);
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000)
        .toISOString();

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
        return jsonResponse(500, { error: "Token issue failed" });
      }

      // 8c. Build the setup URL and send.
      const setupUrl = `${PUBLIC_APP_URL.replace(/\/$/, "")}` +
        `/parent-setup?token=${encodeURIComponent(rawToken)}` +
        `&email=${encodeURIComponent(email)}`;

      await sendSetupEmail({
        apiKey: RESEND_API_KEY,
        from: EMAIL_FROM,
        to: email,
        setupUrl,
        parentFirstName: firstName,
      });
      setupEmailSent = true;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error("setup email/token failed", msg);
      // Distinguish Resend's domain-verification error so the admin
      // sees something actionable; everything else collapses to 502.
      if (isUnverifiedDomainError(msg)) {
        return jsonResponse(502, {
          error:
            "Email-ul nu a putut fi trimis: domeniul expeditorului nu este verificat în Resend.",
        });
      }
      return jsonResponse(502, {
        error: "Email-ul de setare parolă nu a putut fi trimis.",
      });
    }
  }

  const success: SuccessResponse = {
    parent_id: parentId,
    link_id: linkId,
    invite_sent: setupEmailSent,
  };
  return jsonResponse(200, success);
});
