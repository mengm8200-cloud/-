-- Moments: posts that only the author and the author's friends can see,
-- with likes and comments.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- True for the caller's own content and for content of the caller's friends.
-- Unlike are_friends(), this only answers about the caller, so it is safe to
-- expose to signed-in users and to use inside policies.
create function public.can_view_content_of(p_owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and (p_owner_id = auth.uid() or public.are_friends(auth.uid(), p_owner_id));
$$;

create function public.all_paths_in_folder(p_paths text[], p_folder text)
returns boolean
language sql
immutable
as $$
  select coalesce(bool_and(p like p_folder || '/%'), true)
  from unnest(p_paths) as p;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null default '',
  image_paths text[] not null default '{}',
  created_at timestamptz not null default now(),
  constraint posts_body_length check (char_length(body) <= 2000),
  constraint posts_image_count check (cardinality(image_paths) <= 9),
  constraint posts_not_empty check (char_length(btrim(body)) > 0 or cardinality(image_paths) > 0),
  -- Pictures must live in the author's own storage folder.
  constraint posts_image_folder check (public.all_paths_in_folder(image_paths, author_id::text))
);
create index posts_created_idx on public.posts (created_at desc);
create index posts_author_idx on public.posts (author_id, created_at desc);

create table public.post_likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint post_comments_body_length check (char_length(btrim(body)) between 1 and 500)
);
create index post_comments_post_idx on public.post_comments (post_id, created_at);

create function public.can_view_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.posts p
    where p.id = p_post_id
      and public.can_view_content_of(p.author_id)
  );
$$;

create function public.owns_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.posts p where p.id = p_post_id and p.author_id = auth.uid()
  );
$$;

-- Post pictures are stored as "<author uuid>/<file>".
create function public.can_access_post_media(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
begin
  begin
    v_owner_id := split_part(p_name, '/', 1)::uuid;
  exception when others then
    return false;
  end;
  return public.can_view_content_of(v_owner_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;

revoke all on public.posts, public.post_likes, public.post_comments from anon, authenticated;

grant select, delete on public.posts to authenticated;
grant insert (author_id, body, image_paths) on public.posts to authenticated;
grant select, delete on public.post_likes to authenticated;
grant insert (post_id, user_id) on public.post_likes to authenticated;
grant select, delete on public.post_comments to authenticated;
grant insert (post_id, author_id, body) on public.post_comments to authenticated;

create policy "Friends and the author read posts"
  on public.posts for select to authenticated
  using (public.can_view_content_of(author_id));

create policy "Users publish their own posts"
  on public.posts for insert to authenticated
  with check (author_id = auth.uid());

create policy "Authors delete their posts"
  on public.posts for delete to authenticated
  using (author_id = auth.uid());

-- Likes and comments are only shown between people who know each other: a
-- viewer sees those written by themselves or by their own friends.
create policy "Likes visible among friends"
  on public.post_likes for select to authenticated
  using (public.can_view_post(post_id) and public.can_view_content_of(user_id));

create policy "Users like posts they can see"
  on public.post_likes for insert to authenticated
  with check (user_id = auth.uid() and public.can_view_post(post_id));

create policy "Users remove their own likes"
  on public.post_likes for delete to authenticated
  using (user_id = auth.uid());

create policy "Comments visible among friends"
  on public.post_comments for select to authenticated
  using (public.can_view_post(post_id) and public.can_view_content_of(author_id));

create policy "Users comment on posts they can see"
  on public.post_comments for insert to authenticated
  with check (author_id = auth.uid() and public.can_view_post(post_id));

create policy "Comment authors and post owners delete comments"
  on public.post_comments for delete to authenticated
  using (author_id = auth.uid() or public.owns_post(post_id));

-- ---------------------------------------------------------------------------
-- Feed
-- ---------------------------------------------------------------------------

-- Newest first. Pass the id of the last post already shown to get the next page.
create function public.moments_feed(p_before_id uuid default null, p_limit integer default 20)
returns table (
  id uuid,
  author_id uuid,
  author_name text,
  author_avatar_path text,
  body text,
  image_paths text[],
  created_at timestamptz,
  liked_by_me boolean,
  liker_names text[],
  comments jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.author_id,
    a.display_name,
    a.avatar_path,
    p.body,
    p.image_paths,
    p.created_at,
    exists (
      select 1 from public.post_likes l where l.post_id = p.id and l.user_id = auth.uid()
    ),
    coalesce((
      select array_agg(lp.display_name order by l.created_at)
      from public.post_likes l
      join public.profiles lp on lp.id = l.user_id
      where l.post_id = p.id
        and public.can_view_content_of(l.user_id)
    ), '{}'),
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'author_id', c.author_id,
          'author_name', cp.display_name,
          'body', c.body,
          'created_at', c.created_at
        )
        order by c.created_at
      )
      from public.post_comments c
      join public.profiles cp on cp.id = c.author_id
      where c.post_id = p.id
        and public.can_view_content_of(c.author_id)
    ), '[]'::jsonb)
  from public.posts p
  join public.profiles a on a.id = p.author_id
  where public.can_view_content_of(p.author_id)
    and (
      p_before_id is null
      or (p.created_at, p.id) < (
        select b.created_at, b.id from public.posts b where b.id = p_before_id
      )
    )
  order by p.created_at desc, p.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

-- ---------------------------------------------------------------------------
-- Function privileges
-- ---------------------------------------------------------------------------

revoke execute on function
  public.can_view_content_of(uuid),
  public.all_paths_in_folder(text[], text),
  public.can_view_post(uuid),
  public.owns_post(uuid),
  public.can_access_post_media(text),
  public.moments_feed(uuid, integer)
from public, anon, authenticated;

grant execute on function
  public.can_view_content_of(uuid),
  public.all_paths_in_folder(text[], text),
  public.can_view_post(uuid),
  public.owns_post(uuid),
  public.can_access_post_media(text),
  public.moments_feed(uuid, integer)
to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: post pictures, readable by the author and the author's friends
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-media', 'post-media', false, 10485760, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "Friends read post media"
  on storage.objects for select to authenticated
  using (bucket_id = 'post-media' and public.can_access_post_media(name));

create policy "Users upload post media into their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
