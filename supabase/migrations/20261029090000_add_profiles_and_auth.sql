-- Team profiles linked to Supabase Auth (auth.users), sign-in required for all data.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9._-]{2,32}$'),
  display_name text not null check (length(trim(display_name)) between 1 and 100),
  role text not null default 'member' check (role in ('admin', 'member')),
  must_change_password boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

-- Membership check lives outside the exposed API schema.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- Only accounts with a profile are tracker members. Self sign-ups through the public
-- API get no profile (they can't set app_metadata), so they see nothing.
create function private.is_member() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles where id = (select auth.uid())) $$;
revoke execute on function private.is_member() from public, anon;
grant execute on function private.is_member() to authenticated;

create policy "Members can see the team" on public.profiles
  for select to authenticated using ((select private.is_member()));
-- No insert/update/delete policies: profiles change only through the trigger below,
-- mark_password_changed(), or the manage-users edge function (service role).
grant select on public.profiles to authenticated;
revoke all on public.profiles from anon;

-- Create a profile when an account is created with a username in app_metadata
-- (app_metadata can only be set by the service role / admin API, never by the user).
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.raw_app_meta_data ? 'username' then
    insert into public.profiles (id, username, display_name, role)
    values (
      new.id,
      lower(new.raw_app_meta_data ->> 'username'),
      coalesce(nullif(trim(new.raw_app_meta_data ->> 'display_name'), ''), new.raw_app_meta_data ->> 'username'),
      case when new.raw_app_meta_data ->> 'role' = 'admin' then 'admin' else 'member' end
    )
    on conflict (id) do nothing;
  end if;
  return new;
end $$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Called by the page after a user sets their own password.
create function public.mark_password_changed() returns void
language sql security definer set search_path = ''
as $$ update public.profiles set must_change_password = false where id = (select auth.uid()) $$;
revoke execute on function public.mark_password_changed() from public, anon;
grant execute on function public.mark_password_changed() to authenticated;

-- Link actions to owners and authors.
alter table public.meeting_actions
  add column owner_id uuid references public.profiles (id) on delete set null,
  add column created_by uuid default auth.uid() references public.profiles (id) on delete set null;
create index meeting_actions_owner_id_idx on public.meeting_actions (owner_id);
create index meeting_actions_created_by_idx on public.meeting_actions (created_by);

-- Actions are for signed-in members only.
drop policy "Anyone can read actions" on public.meeting_actions;
drop policy "Anyone can add actions" on public.meeting_actions;
drop policy "Anyone can update actions" on public.meeting_actions;
drop policy "Anyone can delete actions" on public.meeting_actions;
revoke all on public.meeting_actions from anon;

create policy "Members can read actions" on public.meeting_actions
  for select to authenticated using ((select private.is_member()));
create policy "Members can add actions" on public.meeting_actions
  for insert to authenticated with check ((select private.is_member()));
create policy "Members can update actions" on public.meeting_actions
  for update to authenticated using ((select private.is_member())) with check ((select private.is_member()));
create policy "Members can delete actions" on public.meeting_actions
  for delete to authenticated using ((select private.is_member()));
