-- SEND IT: eigene Rangliste für Downhill (alle Sommer-Läufe mit dem Bike, Alpen und Wiehengebirge).
-- Einmal im Supabase SQL Editor ausführen (nach supabase-setup.sql). Die Ranglisten der Maps bleiben für Ski und Snowboard.
-- Downhill-Läufe landen in "scores_downhill". Lesen darf jeder, eintragen nur der angemeldete Spieler selbst.

create table if not exists public.scores_downhill (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  best integer not null default 0 check (best between 0 and 100000000),
  best_dist integer not null default 0 check (best_dist between 0 and 1000000),
  best_trick text,
  updated_at timestamptz not null default now()
);

alter table public.scores_downhill enable row level security;
drop policy if exists "scores_downhill lesen" on public.scores_downhill;
create policy "scores_downhill lesen" on public.scores_downhill for select using (true);
grant select on public.scores_downhill to anon, authenticated;

-- Downhill-Bestwert eintragen: wie submit_score, nur in die Downhill-Tabelle
create or replace function public.submit_score_downhill(p_score integer, p_dist integer, p_trick text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if p_score < 0 or p_score > 100000000 or p_dist < 0 or p_dist > 1000000 then raise exception 'ungültiger Wert'; end if;
  insert into public.scores_downhill (user_id, best, best_dist, best_trick, updated_at)
  values (auth.uid(), p_score, p_dist, left(p_trick, 40), now())
  on conflict (user_id) do update set
    best_trick = case when excluded.best > scores_downhill.best then excluded.best_trick else scores_downhill.best_trick end,
    best = greatest(scores_downhill.best, excluded.best),
    best_dist = greatest(scores_downhill.best_dist, excluded.best_dist),
    updated_at = now();
end $$;
revoke all on function public.submit_score_downhill(integer, integer, text) from public, anon;
grant execute on function public.submit_score_downhill(integer, integer, text) to authenticated;

-- Supabase sofort Bescheid geben, dass es Tabelle und Funktion gibt
notify pgrst, 'reload schema';
