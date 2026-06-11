-- ============================================================================
-- parent_setup_tokens
--
-- One-time setup tokens for the custom parent onboarding flow. Replaces
-- Supabase invite-OTP + verifyOTP, which is unusable in practice because
-- the OTP is bound to the same single-use credential as the email's
-- magic link — corporate email scanners consume the credential before
-- the parent ever reaches the app.
--
-- Lifecycle:
--   1. Admin calls Edge Function `create_parent_and_link_child`.
--      Function creates the auth user (if new), upserts profile and
--      child_parents, generates a random 32-byte token, stores its
--      sha256(token || pepper) hash here, sends an email containing
--      the raw token in a setup link.
--   2. Parent clicks the link → /parent-setup → enters new password.
--   3. Flutter calls Edge Function `complete_parent_setup` with the
--      raw token + email + password. Function verifies hash, sets
--      password via auth.admin.updateUserById, marks token consumed.
--
-- Security:
--   - Raw token NEVER stored. Only sha256(token || pepper).
--   - One-time: consumed_at set on successful redeem.
--   - 24h TTL via expires_at.
--   - attempt_count per-token; the verify function refuses after 5.
--   - RLS enabled, NO policies → service role only (Edge Functions).
-- ============================================================================

create table public.parent_setup_tokens (
  id             uuid primary key default gen_random_uuid(),
  parent_id      uuid not null
                 references public.profiles(id) on delete cascade,
  email          text not null,
  token_hash     text not null,
  expires_at     timestamptz not null,
  consumed_at    timestamptz,
  attempt_count  int  not null default 0,
  created_at     timestamptz not null default now()
);

-- Lookup paths used by complete_parent_setup:
--   1) by email, latest non-consumed, non-expired token (verify path)
--   2) by parent_id, all unconsumed (invalidation on re-issue)
create index parent_setup_tokens_email_open_idx
  on public.parent_setup_tokens (email, created_at desc)
  where consumed_at is null;

create index parent_setup_tokens_parent_open_idx
  on public.parent_setup_tokens (parent_id)
  where consumed_at is null;

-- Defense in depth: enable RLS with no policies. Only the service-role
-- client (Edge Functions) can read or write. Anon and authenticated
-- clients see zero rows and cannot insert.
alter table public.parent_setup_tokens enable row level security;

comment on table public.parent_setup_tokens is
  'One-time password-setup tokens for parents. Service-role only. '
  'Replaces Supabase invite-OTP which is unreliable behind email scanners.';
comment on column public.parent_setup_tokens.token_hash is
  'sha256(raw_token || SETUP_TOKEN_PEPPER) — raw token never stored.';
comment on column public.parent_setup_tokens.attempt_count is
  'Increments on each verify call that finds this token but fails. '
  'After 5 failed attempts the token is permanently locked.';
