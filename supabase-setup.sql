-- SEND IT: Konten und Rangliste. Einmal im Supabase SQL Editor ausführen.
-- Spielername steht im Profil, der Bestwert in "scores". Jeder darf lesen, schreiben geht nur über submit_score.

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null check (char_length(name) between 3 and 16 and name ~ '^[A-Za-z0-9_-]+$'),
  created_at timestamptz not null default now()
);
create unique index if not exists profiles_name_lower on public.profiles (lower(name));

create table if not exists public.scores (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  best integer not null default 0 check (best between 0 and 2000000),
  best_dist integer not null default 0 check (best_dist between 0 and 1000000),
  best_trick text,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.scores enable row level security;
drop policy if exists "profiles lesen" on public.profiles;
create policy "profiles lesen" on public.profiles for select using (true);
drop policy if exists "scores lesen" on public.scores;
create policy "scores lesen" on public.scores for select using (true);
grant select on public.profiles, public.scores to anon, authenticated;

-- Profil automatisch bei der Registrierung anlegen (Name kommt aus den Anmeldedaten)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name) values (new.id, new.raw_user_meta_data->>'name');
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Bestwert eintragen: nur angemeldet, unmögliche Werte werden abgelehnt, es bleibt immer der beste Wert
create or replace function public.submit_score(p_score integer, p_dist integer, p_trick text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if p_score < 0 or p_score > 2000000 or p_dist < 0 or p_dist > 1000000 then raise exception 'ungültiger Wert'; end if;
  insert into public.scores (user_id, best, best_dist, best_trick, updated_at)
  values (auth.uid(), p_score, p_dist, left(p_trick, 40), now())
  on conflict (user_id) do update set
    best_trick = case when excluded.best > scores.best then excluded.best_trick else scores.best_trick end,
    best = greatest(scores.best, excluded.best),
    best_dist = greatest(scores.best_dist, excluded.best_dist),
    updated_at = now();
end $$;
revoke all on function public.submit_score(integer, integer, text) from public, anon;
grant execute on function public.submit_score(integer, integer, text) to authenticated;
