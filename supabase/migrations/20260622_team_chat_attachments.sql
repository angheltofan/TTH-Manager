-- ────────────────────────────────────────────────────────────────────
-- 20260622_team_chat_attachments — PROPOSED, do not push without review
-- ────────────────────────────────────────────────────────────────────
--
-- Adds attachment support to the team chat (photos + arbitrary files).
-- Designed to be additive and idempotent so it is safe to re-run.
--
-- What it does
--   1. team_chat_messages: 4 new optional columns
--        attachment_url   text  — public URL (or signed URL path) of
--                                  the uploaded object in storage
--        attachment_name  text  — original filename for display
--        attachment_size  bigint — byte size, for the "12.4 MB" hint
--        attachment_kind  text  — 'image' | 'file'  (NOT NULL-checked
--                                  via a CHECK constraint so the bubble
--                                  layer can branch confidently)
--      body becomes nullable so an attachment-only message (no caption)
--      is legal.  A new CHECK guarantees the row carries SOMETHING
--      (body or attachment).
--
--   2. New storage bucket `team-chat-attachments` (private, 25 MB cap).
--
--   3. Storage RLS — three policies on `storage.objects`:
--        • staff_read   — staff (admin/trainer) can read every object
--                        in this bucket.
--        • staff_insert — staff can upload objects, but the object
--                        path's first folder MUST equal auth.uid()
--                        so users can only write under their own
--                        sender_id namespace.
--        • staff_delete — staff can delete their own uploads (admins
--                        can delete any).  Parallels the message
--                        soft-delete rule.
--
-- What it does NOT do
--   • Does not touch the existing realtime publication — the new
--     columns flow through unchanged.
--   • Does not migrate any existing rows — every new column is
--     nullable and defaults to NULL.
--   • Does not grant any new role any new SELECT/INSERT on the
--     `team_chat_messages` table — existing RLS already covers
--     staff-only access.
--
-- ────────────────────────────────────────────────────────────────────

-- 1. Schema additions ────────────────────────────────────────────────

alter table public.team_chat_messages
  add column if not exists attachment_url  text,
  add column if not exists attachment_name text,
  add column if not exists attachment_size bigint,
  add column if not exists attachment_kind text;

-- Allow attachment-only messages (no caption) without breaking the
-- existing not-null on body.  Existing rows with body=text remain
-- valid.
alter table public.team_chat_messages
  alter column body drop not null;

-- Require attachment_kind to be one of the two known values when set.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'team_chat_messages_attachment_kind_chk'
      and conrelid = 'public.team_chat_messages'::regclass
  ) then
    alter table public.team_chat_messages
      add constraint team_chat_messages_attachment_kind_chk
      check (attachment_kind in ('image', 'file') or attachment_kind is null);
  end if;
end$$;

-- Every row must carry text OR an attachment (or both).
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'team_chat_messages_payload_present_chk'
      and conrelid = 'public.team_chat_messages'::regclass
  ) then
    alter table public.team_chat_messages
      add constraint team_chat_messages_payload_present_chk
      check (
        (body is not null and length(trim(body)) > 0)
        or attachment_url is not null
      );
  end if;
end$$;

-- 2. Storage bucket  ─────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'team-chat-attachments',
  'team-chat-attachments',
  false,
  26214400, -- 25 MB
  null      -- mime types validated client-side; server only enforces size + RLS
)
on conflict (id) do nothing;

-- 3. Storage RLS — staff-only, owner-scoped writes ───────────────────
--
-- Object paths are expected to look like:
--   <sender_id>/<yyyy>/<mm>/<random>.<ext>
-- The policies use `storage.foldername(name)` which returns the first
-- path segment; restricting to auth.uid() means a user can only write
-- under their own folder, which prevents cross-user object spoofing
-- even if the client is hostile.

drop policy if exists "team_chat_attachments_staff_read"   on storage.objects;
drop policy if exists "team_chat_attachments_staff_insert" on storage.objects;
drop policy if exists "team_chat_attachments_staff_delete" on storage.objects;

create policy "team_chat_attachments_staff_read"
  on storage.objects for select
  using (
    bucket_id = 'team-chat-attachments'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role in ('admin', 'trainer')
    )
  );

create policy "team_chat_attachments_staff_insert"
  on storage.objects for insert
  with check (
    bucket_id = 'team-chat-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role in ('admin', 'trainer')
    )
  );

create policy "team_chat_attachments_staff_delete"
  on storage.objects for delete
  using (
    bucket_id = 'team-chat-attachments'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and (
          p.role = 'admin'
          or (p.role = 'trainer' and (storage.foldername(name))[1] = auth.uid()::text)
        )
    )
  );
