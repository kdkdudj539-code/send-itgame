-- SEND IT: eigene Rangliste für die Japan-Map. Einmal im Supabase SQL Editor ausführen (nach supabase-setup.sql).
-- Die bisherige Tabelle "scores" bleibt die Alpen-Rangliste (dazu zählt auch der Sommer).
-- Läufe auf der Japan-Map landen in "scores_japan". Lesen darf jeder, eintragen nur der angemeldete Spieler selbst.

create table if not exists public.scores_japan (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  best integer not null default 0 check (best between 0 and 100000000),
  best_dist integer not null default 0 check (best_dist between 0 and 1000000),
  best_trick text,
  updated_at timestamptz not null default now()
);

alter table public.scores_japan enable row level security;
drop policy if exists "scores_japan lesen" on public.scores_japan;
create policy "scores_japan lesen" on public.scores_japan for select using (true);
grant select on public.scores_japan to anon, authenticated;

-- Bestwert auf der Japan-Map eintragen: wie submit_score, nur in die Japan-Tabelle
create or replace function public.submit_score_japan(p_score integer, p_dist integer, p_trick text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if p_score < 0 or p_score > 100000000 or p_dist < 0 or p_dist > 1000000 then raise exception 'ungültiger Wert'; end if;
  insert into public.scores_japan (user_id, best, best_dist, best_trick, updated_at)
  values (auth.uid(), p_score, p_dist, left(p_trick, 40), now())
  on conflict (user_id) do update set
    best_trick = case when excluded.best > scores_japan.best then excluded.best_trick else scores_japan.best_trick end,
    best = greatest(scores_japan.best, excluded.best),
    best_dist = greatest(scores_japan.best_dist, excluded.best_dist),
    updated_at = now();
end $$;
revoke all on function public.submit_score_japan(integer, integer, text) from public, anon;
grant execute on function public.submit_score_japan(integer, integer, text) to authenticated;

-- Supabase sofort Bescheid geben, dass es Tabelle und Funktion gibt
notify pgrst, 'reload schema';
