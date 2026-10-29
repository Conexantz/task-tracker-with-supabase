-- Actions table (originally open to anyone; access is tightened in 20261029090000_add_profiles_and_auth.sql)
create table public.meeting_actions (
  id uuid primary key default gen_random_uuid(),
  text text not null check (length(trim(text)) > 0 and length(text) <= 500),
  owner text not null check (length(trim(owner)) > 0 and length(owner) <= 100),
  due date not null,
  done boolean not null default false,
  done_at timestamptz,
  example boolean not null default false,
  created_at timestamptz not null default now()
);

create index meeting_actions_owner_idx on public.meeting_actions (lower(owner));
create index meeting_actions_due_idx on public.meeting_actions (due);

alter table public.meeting_actions enable row level security;

create policy "Anyone can read actions" on public.meeting_actions
  for select to anon, authenticated using (true);
create policy "Anyone can add actions" on public.meeting_actions
  for insert to anon, authenticated with check (true);
create policy "Anyone can update actions" on public.meeting_actions
  for update to anon, authenticated using (true) with check (true);
create policy "Anyone can delete actions" on public.meeting_actions
  for delete to anon, authenticated using (true);

grant select, insert, update, delete on public.meeting_actions to anon, authenticated;

alter publication supabase_realtime add table public.meeting_actions;
alter table public.meeting_actions replica identity full;
