// Shared helpers for the custom parent password-setup flow.
//
// Used by:
//   • create_parent_and_link_child  — issues a new token, sends email
//   • complete_parent_setup         — verifies and consumes a token
//
// Security model:
//   - 32 bytes of crypto-strong randomness, base64url-encoded → ~43 chars
//     in the URL. ~256 bits of entropy → infeasible to brute force.
//   - DB stores only sha256(raw_token || SETUP_TOKEN_PEPPER). Even a
//     full DB leak does not yield usable tokens without the app secret.
//   - One-time: consumed_at column flipped on successful redeem.
//   - 24h expiry.
//   - attempt_count per token; verify function refuses after 5 fails.

// ── Token generation ──────────────────────────────────────────────────────

/**
 * Generates a URL-safe random token. 32 bytes (256 bits) of entropy,
 * encoded as base64url without padding. Resulting length: 43 chars.
 */
export function generateRawToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  // Encode bytes → standard base64 → strip to base64url.
  let bin = "";
  for (let i = 0; i < bytes.length; i += 1) bin += String.fromCharCode(bytes[i]);
  return btoa(bin)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

// ── Hashing ───────────────────────────────────────────────────────────────

/**
 * SHA-256 over the concatenation of the raw token and the server-side
 * pepper. Returns lowercase hex. Pepper MUST be set in the function's
 * environment as SETUP_TOKEN_PEPPER — refuse to hash without it so a
 * mis-configured deploy fails loudly instead of silently weakening the
 * scheme.
 */
export async function hashToken(
  rawToken: string,
  pepper: string,
): Promise<string> {
  if (!pepper || pepper.length < 16) {
    throw new Error(
      "SETUP_TOKEN_PEPPER missing or too short (>=16 chars required).",
    );
  }
  const data = new TextEncoder().encode(rawToken + pepper);
  const digest = await crypto.subtle.digest("SHA-256", data);
  const arr = new Uint8Array(digest);
  let hex = "";
  for (let i = 0; i < arr.length; i += 1) {
    hex += arr[i].toString(16).padStart(2, "0");
  }
  return hex;
}

// ── Email sending (Resend) ────────────────────────────────────────────────

/**
 * Sends the parent setup email through Resend. Returns the Resend
 * message id on success; throws on any non-2xx response so the caller
 * can decide whether to roll back or surface a 502.
 *
 * Required env:
 *   RESEND_API_KEY  — Resend API key (https://resend.com/api-keys)
 *   EMAIL_FROM      — From address. Domain must be verified in Resend.
 *                     Example: 'TTH Manager <noreply@yourdomain.com>'
 *
 * To swap to Brevo / SendGrid / Postmark: replace ONLY this function.
 * Inputs and behavior contract stay the same.
 */
export async function sendSetupEmail(args: {
  apiKey: string;
  from: string;
  to: string;
  setupUrl: string;
  parentFirstName: string;
}): Promise<string> {
  const { apiKey, from, to, setupUrl, parentFirstName } = args;

  const subject = "Setează-ți parola — TTH Manager";
  const greeting = parentFirstName.trim().length > 0
    ? `Bună, ${parentFirstName.trim()},`
    : "Bună,";

  const html = `
<!DOCTYPE html>
<html lang="ro">
<body style="margin:0;padding:0;font-family:Arial,sans-serif;background:#f8fafc;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="520" cellpadding="0" cellspacing="0"
             style="background:#ffffff;border-radius:12px;
                    padding:32px;max-width:520px;">
        <tr><td>
          <h2 style="margin:0 0 16px 0;color:#111827;">Bun venit la TTH Manager</h2>
          <p style="margin:0 0 16px 0;color:#374151;font-size:14px;line-height:1.5;">
            ${greeting}
          </p>
          <p style="margin:0 0 24px 0;color:#374151;font-size:14px;line-height:1.5;">
            Ai fost invitat să accesezi contul de părinte. Apasă pe butonul
            de mai jos pentru a-ți seta parola:
          </p>
          <p style="text-align:center;margin:0 0 24px 0;">
            <a href="${setupUrl}"
               style="background:#2563eb;color:#ffffff;padding:12px 28px;
                      text-decoration:none;border-radius:8px;font-weight:600;
                      display:inline-block;">
              Setează parola
            </a>
          </p>
          <p style="margin:0 0 8px 0;color:#6b7280;font-size:13px;line-height:1.5;">
            Dacă butonul nu funcționează, copiază adresa de mai jos în browser:
          </p>
          <p style="margin:0 0 24px 0;
                    color:#2563eb;font-size:12px;word-break:break-all;">
            ${setupUrl}
          </p>
          <p style="margin:0;color:#9ca3af;font-size:12px;line-height:1.5;">
            Linkul expiră în 24 de ore. Dacă nu ai cerut acest mesaj, îl poți ignora.
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`.trim();

  const text = [
    greeting,
    "",
    "Ai fost invitat la TTH Manager. Folosește linkul de mai jos pentru a-ți seta parola:",
    "",
    setupUrl,
    "",
    "Linkul expiră în 24 de ore. Dacă nu ai cerut acest mesaj, îl poți ignora.",
  ].join("\n");

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from, to, subject, html, text }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(
      `Resend send failed: status=${res.status} body=${body.slice(0, 500)}`,
    );
  }
  const json = (await res.json().catch(() => ({}))) as { id?: string };
  return json.id ?? "";
}
