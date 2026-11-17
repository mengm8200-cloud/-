-- Voice messages: a third message kind with a clip stored next to chat pictures.

alter table public.messages add column duration_ms integer;

alter table public.messages drop constraint messages_kind;
alter table public.messages add constraint messages_kind
  check (kind in ('text', 'image', 'voice'));

alter table public.messages drop constraint messages_content;
alter table public.messages add constraint messages_content check (
  (kind = 'text' and media_path is null and duration_ms is null
    and char_length(btrim(body)) between 1 and 4000)
  or (kind = 'image' and media_path is not null and duration_ms is null)
  -- Clips run from half a second to one minute. The explicit null test matters:
  -- a check that evaluates to NULL passes.
  or (kind = 'voice' and media_path is not null
    and duration_ms is not null and duration_ms between 500 and 60000)
);

grant insert (duration_ms) on public.messages to authenticated;

create or replace function public.handle_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set last_message_at = new.created_at,
      last_message_preview = case new.kind
        when 'image' then '[图片]'
        when 'voice' then '[语音]'
        else left(new.body, 80)
      end
  where id = new.conversation_id;

  update public.conversation_members
  set last_read_at = new.created_at
  where conversation_id = new.conversation_id
    and user_id = new.sender_id;

  return new;
end;
$$;

update storage.buckets
set allowed_mime_types = array['image/jpeg', 'image/png', 'audio/mp4']
where id = 'chat-media';
