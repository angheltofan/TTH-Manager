-- ============================================================================
-- assistant_conversations + assistant_messages
--
-- Persistent chat history for the TTH Assistant. Staff-only (admin and
-- trainer roles); parents have no access. Each conversation belongs to
-- exactly one user; messages are immutable after insert. The Edge
-- Function (tth_assistant) never reads or writes these tables — it
-- remains stateless and receives the recent history from the Flutter
-- client. The tables are RLS-restricted so even with the wrong client
-- credentials, no cross-user reads are possible.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ── Tables ────────────────────────────────────────────────────────────────

create table if not exists public.assistant_conversations (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null
              references public.profiles(id) on delete cascade,
  title       text not null default 'Conversație nouă',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists assistant_conversations_user_updated_idx
  on public.assistant_conversations (user_id, updated_at desc);

create table if not exists public.assistant_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
                  references public.assistant_conversations(id)
                  on delete cascade,
  role            text not null check (role in ('user', 'assistant')),
  content         text not null,
  sources         jsonb not null default '[]'::jsonb,
  created_at      timestamptz not null default now()
);

create index if not exists assistant_messages_conv_created_idx
  on public.assistant_messages (conversation_id, created_at asc);

-- ── Trigger: keep conversations.updated_at fresh on new message ──────────

create or replace function public.bump_assistant_conversation_updated_at()
returns trigger
language plpgsql
as $$
begin
  update public.assistant_conversations
     set updated_at = now()
   where id = NEW.conversation_id;
  return NEW;
end;
$$;

drop trigger if exists assistant_messages_bump_parent
  on public.assistant_messages;
create trigger assistant_messages_bump_parent
  after insert on public.assistant_messages
  for each row execute function public.bump_assistant_conversation_updated_at();

-- ── Row Level Security ───────────────────────────────────────────────────
--
-- Two predicates appear in every policy:
--   1. owner check (user_id = auth.uid())  for conversations
--      OR exists (conversation owned by auth.uid())  for messages
--   2. staff check (role in admin | trainer)
--
-- Both must hold. Parents are blocked by predicate 2 regardless of
-- ownership; service-role bypasses RLS, but the Edge Function does not
-- touch these tables.

alter table public.assistant_conversations enable row level security;
alter table public.assistant_messages      enable row level security;

-- assistant_conversations
create policy assistant_conversations_select_own_staff
  on public.assistant_conversations
  for select
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('admin', 'trainer')
    )
  );

create policy assistant_conversations_insert_own_staff
  on public.assistant_conversations
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('admin', 'trainer')
    )
  );

create policy assistant_conversations_update_own_staff
  on public.assistant_conversations
  for update
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('admin', 'trainer')
    )
  )
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('admin', 'trainer')
    )
  );

create policy assistant_conversations_delete_own_staff
  on public.assistant_conversations
  for delete
  to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('admin', 'trainer')
    )
  );

-- assistant_messages
create policy assistant_messages_select_own_staff
  on public.assistant_messages
  for select
  to authenticated
  using (
    exists (
      select 1 from public.assistant_conversations c
      where c.id = conversation_id and c.user_id = auth.uid()
    )
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('admin', 'trainer')
    )
  );

create policy assistant_messages_insert_own_staff
  on public.assistant_messages
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.assistant_conversations c
      where c.id = conversation_id and c.user_id = auth.uid()
    )
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('admin', 'trainer')
    )
  );

create policy assistant_messages_delete_own_staff
  on public.assistant_messages
  for delete
  to authenticated
  using (
    exists (
      select 1 from public.assistant_conversations c
      where c.id = conversation_id and c.user_id = auth.uid()
    )
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('admin', 'trainer')
    )
  );

comment on table public.assistant_conversations is
  'TTH Assistant chat conversations. Owned by an admin or trainer profile. '
  'RLS-restricted to the owner. Parents have no access.';
comment on table public.assistant_messages is
  'TTH Assistant chat messages. Append-only. RLS gated through the parent '
  'conversation owner + staff role.';
comment on column public.assistant_messages.sources is
  'Array of human-readable data-source labels (e.g. ["Prezențe","Plăți"]) '
  'that the Edge Function derived from the tools used to produce the '
  'reply. Empty array when no tool was called.';
