create extension if not exists "pgcrypto";

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text,
    full_name text,
    avatar_url text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.reels (
    id uuid primary key default gen_random_uuid(),
    user_id text not null default 'default-user',
    url text not null,
    title text not null default 'Untitled',
    summary text not null default '',
    transcript text not null default '',
    category text not null default 'Other',
    subcategory text not null default 'Other',
    secondary_categories jsonb not null default '[]'::jsonb,
    key_facts jsonb not null default '[]'::jsonb,
    locations jsonb not null default '[]'::jsonb,
    people_mentioned jsonb not null default '[]'::jsonb,
    actionable_items jsonb not null default '[]'::jsonb,
    pinecone_id text,
    created_at timestamptz not null default timezone('utc', now())
);

alter table public.reels
    add column if not exists subcategory text not null default 'Other',
    add column if not exists secondary_categories jsonb not null default '[]'::jsonb,
    add column if not exists key_facts jsonb not null default '[]'::jsonb,
    add column if not exists locations jsonb not null default '[]'::jsonb,
    add column if not exists people_mentioned jsonb not null default '[]'::jsonb,
    add column if not exists actionable_items jsonb not null default '[]'::jsonb,
    add column if not exists pinecone_id text,
    add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table public.reels
    alter column id set default gen_random_uuid(),
    alter column user_id set default 'default-user',
    alter column title set default 'Untitled',
    alter column summary set default '',
    alter column transcript set default '',
    alter column category set default 'Other',
    alter column subcategory set default 'Other',
    alter column secondary_categories set default '[]'::jsonb,
    alter column key_facts set default '[]'::jsonb,
    alter column locations set default '[]'::jsonb,
    alter column people_mentioned set default '[]'::jsonb,
    alter column actionable_items set default '[]'::jsonb,
    alter column created_at set default timezone('utc', now());

update public.reels
set
    title = coalesce(nullif(trim(title), ''), 'Untitled'),
    summary = coalesce(summary, ''),
    transcript = coalesce(transcript, ''),
    category = coalesce(nullif(trim(category), ''), 'Other'),
    subcategory = coalesce(nullif(trim(subcategory), ''), 'Other'),
    secondary_categories = coalesce(secondary_categories, '[]'::jsonb),
    key_facts = coalesce(key_facts, '[]'::jsonb),
    locations = coalesce(locations, '[]'::jsonb),
    people_mentioned = coalesce(people_mentioned, '[]'::jsonb),
    actionable_items = coalesce(actionable_items, '[]'::jsonb),
    created_at = coalesce(created_at, timezone('utc', now()))
where
    title is null
    or trim(title) = ''
    or summary is null
    or transcript is null
    or category is null
    or trim(category) = ''
    or subcategory is null
    or trim(subcategory) = ''
    or secondary_categories is null
    or key_facts is null
    or locations is null
    or people_mentioned is null
    or actionable_items is null
    or created_at is null;

create index if not exists idx_reels_user_id on public.reels(user_id);
create index if not exists idx_reels_category on public.reels(category);
create index if not exists idx_reels_subcategory on public.reels(subcategory);
create index if not exists idx_reels_created_at on public.reels(created_at desc);

insert into public.profiles (id, email, full_name, avatar_url)
select
    users.id,
    users.email,
    coalesce(
        users.raw_user_meta_data ->> 'full_name',
        users.raw_user_meta_data ->> 'name'
    ) as full_name,
    coalesce(
        users.raw_user_meta_data ->> 'avatar_url',
        users.raw_user_meta_data ->> 'picture'
    ) as avatar_url
from auth.users as users
on conflict (id) do update
set
    email = excluded.email,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    updated_at = timezone('utc', now());

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, email, full_name, avatar_url)
    values (
        new.id,
        new.email,
        coalesce(
            new.raw_user_meta_data ->> 'full_name',
            new.raw_user_meta_data ->> 'name'
        ),
        coalesce(
            new.raw_user_meta_data ->> 'avatar_url',
            new.raw_user_meta_data ->> 'picture'
        )
    )
    on conflict (id) do update
    set
        email = excluded.email,
        full_name = coalesce(excluded.full_name, public.profiles.full_name),
        avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
        updated_at = timezone('utc', now());

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.reels enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "reels_select_own" on public.reels;
create policy "reels_select_own"
on public.reels
for select
using (auth.uid()::text = user_id);

drop policy if exists "reels_insert_own" on public.reels;
create policy "reels_insert_own"
on public.reels
for insert
with check (auth.uid()::text = user_id);

drop policy if exists "reels_update_own" on public.reels;
create policy "reels_update_own"
on public.reels
for update
using (auth.uid()::text = user_id)
with check (auth.uid()::text = user_id);

drop policy if exists "reels_delete_own" on public.reels;
create policy "reels_delete_own"
on public.reels
for delete
using (auth.uid()::text = user_id);
