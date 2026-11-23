-- SEND IT: DH-Race-Rangliste und Freunde. Einmal im Supabase SQL Editor ausführen (nach supabase-setup.sql).
-- Kann gefahrlos mehrfach ausgeführt werden.

-- ---------------------------------------------------------------------------
-- 1) Spielernamen eindeutig (Groß-/Kleinschreibung egal). Gibt es schon aus supabase-setup.sql,
--    hier nur zur Sicherheit, falls der Index fehlt.
create unique index if not exists profiles_name_lower on public.profiles (lower(name));

-- ---------------------------------------------------------------------------
-- 2) DH Race: Bestzeit je Spieler und Strecke in Millisekunden, die kleinste zählt.
--    course = Streckenversion ('c1'). Ändert sich die Strecke, bekommt sie eine neue Kennung und eine eigene Rangliste.
create table if not exists public.scores_race (
  user_id uuid not null references public.profiles(id) on delete cascade,
  course text not null default 'c1',
  best_ms integer not null check (best_ms between 40000 and 3600000),
  updated_at timestamptz not null default now(),
  primary key (user_id, course)
);
create index if not exists scores_race_board on public.scores_race (course, best_ms);

alter table public.scores_race enable row level security;
drop policy if exists "scores_race lesen" on public.scores_race;
create policy "scores_race lesen" on public.scores_race for select using (true);
grant select on public.scores_race to anon, authenticated;

-- Zeit eintragen: nur angemeldet, unmögliche Zeiten werden abgelehnt, es bleibt immer die beste Zeit
create or replace function public.submit_race(p_ms integer, p_course text default 'c1') returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if p_ms is null or p_ms < 40000 or p_ms > 3600000 then raise exception 'ungueltige zeit'; end if;
  if p_course is null or p_course !~ '^[a-z0-9]{1,8}$' then raise exception 'ungueltige strecke'; end if;
  insert into public.scores_race (user_id, course, best_ms, updated_at)
  values (auth.uid(), p_course, p_ms, now())
  on conflict (user_id, course) do update set
    updated_at = case when excluded.best_ms < scores_race.best_ms then now() else scores_race.updated_at end,
    best_ms = least(scores_race.best_ms, excluded.best_ms);
end $$;
revoke all on function public.submit_race(integer, text) from public, anon;
grant execute on function public.submit_race(integer, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Freunde: jeder hat seine eigene Freundesliste (Hinzufügen per Spielername, der andere muss nichts bestätigen).
--    Auf die Tabelle selbst darf niemand direkt, nur über die drei Funktionen unten.
create table if not exists public.friends (
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);
alter table public.friends enable row level security;
revoke all on public.friends from anon, authenticated;

-- Freund per Name hinzufügen; gibt den Namen in der richtigen Schreibweise zurück
create or replace function public.add_friend(p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  fid uuid;
  fname text;
begin
  if uid is null then raise exception 'nicht angemeldet'; end if;
  select id, name into fid, fname from public.profiles where lower(name) = lower(trim(p_name));
  if fid is null then raise exception 'nicht gefunden'; end if;
  if fid = uid then raise exception 'du selbst'; end if;
  if (select count(*) from public.friends where user_id = uid) >= 200 then raise exception 'zu viele'; end if;
  insert into public.friends (user_id, friend_id) values (uid, fid) on conflict do nothing;
  return fname;
end $$;

-- Freund entfernen
create or replace function public.remove_friend(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  delete from public.friends where user_id = auth.uid() and friend_id = p_id;
end $$;

-- Eigene Freundesliste (id und Name)
create or replace function public.my_friends() returns table (id uuid, name text)
language sql stable security definer set search_path = public as $$
  select p.id, p.name from public.friends f join public.profiles p on p.id = f.friend_id
  where f.user_id = auth.uid() order by lower(p.name);
$$;

revoke all on function public.add_friend(text) from public, anon;
revoke all on function public.remove_friend(uuid) from public, anon;
revoke all on function public.my_friends() from public, anon;
grant execute on function public.add_friend(text) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
grant execute on function public.my_friends() to authenticated;

-- Supabase sofort Bescheid geben, dass es die neuen Tabellen und Funktionen gibt
notify pgrst, 'reload schema';
