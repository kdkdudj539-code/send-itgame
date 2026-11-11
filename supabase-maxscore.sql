-- SEND IT: höchster erlaubter Score 100 Millionen statt 2 Millionen (Alpen und Japan).
-- Einmal im Supabase SQL Editor ausführen (nach supabase-setup.sql und supabase-japan.sql).

-- alte Grenze (2 Millionen) an der Spalte best entfernen und die neue setzen
do $$
declare r record;
begin
  for r in select conrelid::regclass::text as tbl, conname from pg_constraint
           where contype = 'c' and conrelid in ('public.scores'::regclass, 'public.scores_japan'::regclass)
             and pg_get_constraintdef(oid) like '%(best >= 0)%'
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
  end loop;
end $$;
alter table public.scores add constraint scores_best_check check (best between 0 and 100000000);
alter table public.scores_japan add constraint scores_japan_best_check check (best between 0 and 100000000);

-- Eintragen: gleiche Funktionen wie vorher, nur mit der neuen Grenze
create or replace function public.submit_score(p_score integer, p_dist integer, p_trick text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if p_score < 0 or p_score > 100000000 or p_dist < 0 or p_dist > 1000000 then raise exception 'ungültiger Wert'; end if;
  insert into public.scores (user_id, best, best_dist, best_trick, updated_at)
  values (auth.uid(), p_score, p_dist, left(p_trick, 40), now())
  on conflict (user_id) do update set
    best_trick = case when excluded.best > scores.best then excluded.best_trick else scores.best_trick end,
    best = greatest(scores.best, excluded.best),
    best_dist = greatest(scores.best_dist, excluded.best_dist),
    updated_at = now();
end $$;

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

notify pgrst, 'reload schema';
