-- Chat app schema: profiles, friendships, conversations, messages, media storage.
-- Every table has row-level security; writes that need cross-row checks go
-- through SECURITY DEFINER functions so the rules live in one place.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  display_name text not null,
  avatar_path text,
  bio text not null default '',
  created_at timestamptz not null default now(),
  constraint profiles_username_format check (username ~ '^[a-z0-9_]{3,20}$'),
  constraint profiles_display_name_length check (char_length(btrim(display_name)) between 1 and 30),
  constraint profiles_bio_length check (char_length(bio) <= 200)
);

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint friendships_status check (status in ('pending', 'accepted')),
  constraint friendships_not_self check (requester_id <> addressee_id)
);

-- One row per pair of users, whichever direction the request went.
create unique index friendships_pair_idx
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index friendships_addressee_idx on public.friendships (addressee_id, status);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  is_group boolean not null default false,
  title text,
  -- "<lower uuid>:<higher uuid>" for one-to-one chats, so each pair has one.
  direct_key text unique,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  last_message_preview text
);

create table public.conversation_members (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create index conversation_members_user_idx on public.conversation_members (user_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  -- Monotonic cursor the client polls with.
  seq bigint generated always as identity,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null default 'text',
  body text not null default '',
  media_path text,
  created_at timestamptz not null default now(),
  constraint messages_kind check (kind in ('text', 'image')),
  constraint messages_content check (
    (kind = 'text' and media_path is null and char_length(btrim(body)) between 1 and 4000)
    or (kind = 'image' and media_path is not null)
  ),
  -- Media must live in the folder of the conversation it was sent to.
  constraint messages_media_folder check (
    media_path is null or media_path like conversation_id::text || '/%'
  )
);
create index messages_conversation_seq_idx on public.messages (conversation_id, seq);

-- ---------------------------------------------------------------------------
-- Helper functions used by policies
-- ---------------------------------------------------------------------------

create function public.is_conversation_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = auth.uid()
  );
$$;

create function public.are_friends(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.friendships f
    where f.status = 'accepted'
      and least(f.requester_id, f.addressee_id) = least(p_a, p_b)
      and greatest(f.requester_id, f.addressee_id) = greatest(p_a, p_b)
  );
$$;

-- Chat media paths look like "<conversation uuid>/<file>".
create function public.can_access_chat_media(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_conversation_id uuid;
begin
  begin
    v_conversation_id := split_part(p_name, '/', 1)::uuid;
  exception when others then
    return false;
  end;
  return public.is_conversation_member(v_conversation_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

revoke all on public.profiles, public.friendships, public.conversations,
  public.conversation_members, public.messages from anon, authenticated;

grant select, insert on public.profiles to authenticated;
grant update (display_name, avatar_path, bio) on public.profiles to authenticated;
grant select on public.friendships to authenticated;
grant select on public.conversations to authenticated;
grant select on public.conversation_members to authenticated;
grant select on public.messages to authenticated;
-- Clients may not set id, seq or created_at: the server assigns them.
grant insert (conversation_id, sender_id, kind, body, media_path) on public.messages to authenticated;

create policy "Signed-in users can read profiles"
  on public.profiles for select to authenticated
  using (true);

create policy "Users create their own profile"
  on public.profiles for insert to authenticated
  with check (id = auth.uid());

create policy "Users update their own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "Users see their own friendships"
  on public.friendships for select to authenticated
  using (auth.uid() in (requester_id, addressee_id));

create policy "Members see their conversations"
  on public.conversations for select to authenticated
  using (public.is_conversation_member(id));

create policy "Members see conversation membership"
  on public.conversation_members for select to authenticated
  using (public.is_conversation_member(conversation_id));

create policy "Members read messages"
  on public.messages for select to authenticated
  using (public.is_conversation_member(conversation_id));

create policy "Members send messages as themselves"
  on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_conversation_member(conversation_id));

-- ---------------------------------------------------------------------------
-- Message triggers
-- ---------------------------------------------------------------------------

create function public.handle_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set last_message_at = new.created_at,
      last_message_preview = case when new.kind = 'image' then '[图片]' else left(new.body, 80) end
  where id = new.conversation_id;

  update public.conversation_members
  set last_read_at = new.created_at
  where conversation_id = new.conversation_id
    and user_id = new.sender_id;

  return new;
end;
$$;

create trigger messages_after_insert
  after insert on public.messages
  for each row execute function public.handle_new_message();

-- ---------------------------------------------------------------------------
-- Friends
-- ---------------------------------------------------------------------------

create function public.find_user_by_username(p_username text)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_path text,
  bio text,
  relation text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_path,
    p.bio,
    case
      when p.id = auth.uid() then 'me'
      when f.status = 'accepted' then 'friend'
      when f.status = 'pending' and f.requester_id = auth.uid() then 'outgoing'
      when f.status = 'pending' then 'incoming'
      else 'stranger'
    end
  from public.profiles p
  left join public.friendships f
    on (f.requester_id = auth.uid() and f.addressee_id = p.id)
    or (f.addressee_id = auth.uid() and f.requester_id = p.id)
  where auth.uid() is not null
    and p.username = lower(btrim(p_username));
$$;

create function public.my_friends()
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_path text,
  bio text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar_path, p.bio
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
  where f.status = 'accepted'
    and auth.uid() in (f.requester_id, f.addressee_id)
  order by p.display_name;
$$;

create function public.my_friend_requests()
returns table (
  request_id uuid,
  user_id uuid,
  username text,
  display_name text,
  avatar_path text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select f.id, p.id, p.username, p.display_name, p.avatar_path, f.created_at
  from public.friendships f
  join public.profiles p on p.id = f.requester_id
  where f.addressee_id = auth.uid()
    and f.status = 'pending'
  order by f.created_at desc;
$$;

create function public.send_friend_request(p_target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_existing public.friendships%rowtype;
begin
  if v_me is null then
    raise exception '请先登录';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_me) then
    raise exception '请先完善个人资料';
  end if;
  if p_target_id = v_me then
    raise exception '不能添加自己为好友';
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_target_id) then
    raise exception '用户不存在';
  end if;

  select f.* into v_existing
  from public.friendships f
  where least(f.requester_id, f.addressee_id) = least(v_me, p_target_id)
    and greatest(f.requester_id, f.addressee_id) = greatest(v_me, p_target_id);

  if found then
    if v_existing.status = 'accepted' then
      raise exception '你们已经是好友了';
    elsif v_existing.requester_id = v_me then
      raise exception '已经发送过申请，请等待对方通过';
    else
      -- The other person already asked: accepting is what both sides want.
      update public.friendships
      set status = 'accepted', responded_at = now()
      where friendships.id = v_existing.id;
      return;
    end if;
  end if;

  insert into public.friendships (requester_id, addressee_id)
  values (v_me, p_target_id);
end;
$$;

create function public.accept_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.friendships
  set status = 'accepted', responded_at = now()
  where friendships.id = p_request_id
    and friendships.addressee_id = auth.uid()
    and friendships.status = 'pending';
  if not found then
    raise exception '这条好友申请已经不存在了';
  end if;
end;
$$;

create function public.decline_friend_request(p_request_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.friendships f
  where f.id = p_request_id
    and f.addressee_id = auth.uid()
    and f.status = 'pending';
$$;

create function public.remove_friend(p_other_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.friendships f
  where auth.uid() in (f.requester_id, f.addressee_id)
    and p_other_id in (f.requester_id, f.addressee_id)
    and p_other_id <> auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- Conversations
-- ---------------------------------------------------------------------------

create function public.get_or_create_direct_conversation(p_other_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_key text;
  v_id uuid;
begin
  if v_me is null then
    raise exception '请先登录';
  end if;
  if p_other_id = v_me then
    raise exception '不能和自己聊天';
  end if;
  if not public.are_friends(v_me, p_other_id) then
    raise exception '对方还不是你的好友';
  end if;

  v_key := least(v_me, p_other_id)::text || ':' || greatest(v_me, p_other_id)::text;

  select c.id into v_id from public.conversations c where c.direct_key = v_key;
  if v_id is not null then
    return v_id;
  end if;

  insert into public.conversations (is_group, direct_key, created_by)
  values (false, v_key, v_me)
  on conflict (direct_key) do nothing
  returning conversations.id into v_id;

  if v_id is null then
    -- Lost a race with the other participant; use the row they created.
    select c.id into v_id from public.conversations c where c.direct_key = v_key;
  end if;

  insert into public.conversation_members (conversation_id, user_id)
  values (v_id, v_me), (v_id, p_other_id)
  on conflict do nothing;

  return v_id;
end;
$$;

create function public.create_group_conversation(p_title text, p_member_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_title text := btrim(coalesce(p_title, ''));
  v_members uuid[];
  v_id uuid;
begin
  if v_me is null then
    raise exception '请先登录';
  end if;
  if char_length(v_title) < 1 or char_length(v_title) > 30 then
    raise exception '群名称需要 1 到 30 个字';
  end if;

  select array_agg(distinct m) into v_members
  from unnest(p_member_ids) as m
  where m <> v_me;

  if v_members is null or array_length(v_members, 1) < 2 then
    raise exception '群聊至少需要选择 2 位好友';
  end if;
  if array_length(v_members, 1) > 199 then
    raise exception '群成员不能超过 200 人';
  end if;
  if exists (select 1 from unnest(v_members) as m where not public.are_friends(v_me, m)) then
    raise exception '只能邀请自己的好友进群';
  end if;

  insert into public.conversations (is_group, title, created_by)
  values (true, v_title, v_me)
  returning conversations.id into v_id;

  insert into public.conversation_members (conversation_id, user_id)
  values (v_id, v_me);

  insert into public.conversation_members (conversation_id, user_id)
  select v_id, m from unnest(v_members) as m;

  return v_id;
end;
$$;

create function public.my_conversations()
returns table (
  id uuid,
  is_group boolean,
  title text,
  last_message_at timestamptz,
  last_message_preview text,
  unread_count integer,
  peer_id uuid,
  peer_name text,
  peer_avatar_path text,
  member_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.is_group,
    c.title,
    c.last_message_at,
    c.last_message_preview,
    (
      select count(*)::integer
      from public.messages m
      where m.conversation_id = c.id
        and m.created_at > mine.last_read_at
        and m.sender_id <> auth.uid()
    ),
    peer.id,
    peer.display_name,
    peer.avatar_path,
    (
      select count(*)::integer
      from public.conversation_members cm
      where cm.conversation_id = c.id
    )
  from public.conversation_members mine
  join public.conversations c on c.id = mine.conversation_id
  left join lateral (
    select p.id, p.display_name, p.avatar_path
    from public.conversation_members other
    join public.profiles p on p.id = other.user_id
    where other.conversation_id = c.id
      and other.user_id <> auth.uid()
      and not c.is_group
    limit 1
  ) peer on true
  where mine.user_id = auth.uid()
  order by c.last_message_at desc;
$$;

create function public.conversation_member_profiles(p_conversation_id uuid)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_path text,
  bio text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar_path, p.bio
  from public.conversation_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.conversation_id = p_conversation_id
    and public.is_conversation_member(p_conversation_id)
  order by cm.joined_at;
$$;

create function public.mark_conversation_read(p_conversation_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.conversation_members cm
  set last_read_at = now()
  where cm.conversation_id = p_conversation_id
    and cm.user_id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- Function privileges: signed-in users only
-- ---------------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon, authenticated;

-- is_conversation_member and can_access_chat_media are evaluated inside
-- policies, which run as the calling role.
grant execute on function
  public.is_conversation_member(uuid),
  public.can_access_chat_media(text),
  public.find_user_by_username(text),
  public.my_friends(),
  public.my_friend_requests(),
  public.send_friend_request(uuid),
  public.accept_friend_request(uuid),
  public.decline_friend_request(uuid),
  public.remove_friend(uuid),
  public.get_or_create_direct_conversation(uuid),
  public.create_group_conversation(text, uuid[]),
  public.my_conversations(),
  public.conversation_member_profiles(uuid),
  public.mark_conversation_read(uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: public avatars, private chat media
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png']),
  ('chat-media', 'chat-media', false, 10485760, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "Users upload avatars into their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Members read chat media"
  on storage.objects for select to authenticated
  using (bucket_id = 'chat-media' and public.can_access_chat_media(name));

create policy "Members upload chat media"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-media' and public.can_access_chat_media(name));
