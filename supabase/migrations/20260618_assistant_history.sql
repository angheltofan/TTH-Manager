-- ============================================================================
-- assistant_conversations / assistant_messages — history v2
--
-- Adds favourite-pinning and a `last_message_at` column the conversation
-- list sorts by. Existing RLS policies cover the new columns (UPDATE
-- policy already checks ownership + staff, which is exactly what
-- favourite-toggle and rename need).
-- ============================================================================

alter table public.assistant_conversations
  add column if not exists is_favorite boolean not null default false;

alter table public.assistant_conversations
  add column if not exists last_message_at timestamptz;

-- Backfill `last_message_at` for rows that pre-date this migration.
-- Prefers the actual latest message timestamp; falls back to the
-- conversation's updated_at so empty conversations still sort sanely.
update public.assistant_conversations c
   set last_message_at = coalesce(
         (select max(m.created_at)
            from public.assistant_messages m
           where m.conversation_id = c.id),
         c.updated_at)
 where c.last_message_at is null;

-- Sort path for the conversation list (newest activity first; favourites
-- are sorted client-side to stay on top of the date groups).
create index if not exists assistant_conversations_user_lastmsg_idx
  on public.assistant_conversations (user_id, last_message_at desc nulls last);

-- Extend the bump trigger so `last_message_at` tracks the most recent
-- message insert exactly like `updated_at` did before.
create or replace function public.bump_assistant_conversation_updated_at()
returns trigger
language plpgsql
as $$
begin
  update public.assistant_conversations
     set updated_at      = now(),
         last_message_at = now()
   where id = NEW.conversation_id;
  return NEW;
end;
$$;

comment on column public.assistant_conversations.is_favorite is
  'When true, the conversation is pinned at the top of the user''s list.';
comment on column public.assistant_conversations.last_message_at is
  'Timestamp of the most recent message in this conversation. Kept in '
  'sync by the assistant_messages_bump_parent trigger. NULL until the '
  'first message is inserted.';
