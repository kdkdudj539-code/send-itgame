-- SEND IT: Spielstand im Konto (Münzen, gekaufte Sachen, Outfit, Bestwerte, Einstellungen).
-- Einmal im Supabase SQL Editor ausführen (nach supabase-setup.sql).
-- Jeder kommt nur an seinen eigenen Spielstand, und nur über load_game / save_game.

create table if not exists public.saves (
  user_id uuid primary key references auth.users on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.saves enable row level security;
-- Keine Policies: direkt auf die Tabelle darf niemand, nur über die beiden Funktionen unten
revoke all on public.saves from anon, authenticated;

-- Eigenen Spielstand laden (null, wenn es noch keinen gibt)
create or replace function public.load_game() returns jsonb
language sql stable security definer set search_path = public as $$
  select data from public.saves where user_id = auth.uid();
$$;

-- Eigenen Spielstand speichern
create or replace function public.save_game(p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'nicht angemeldet'; end if;
  if jsonb_typeof(p_data) <> 'object' or octet_length(p_data::text) > 20000 then raise exception 'ungültiger Spielstand'; end if;
  insert into public.saves (user_id, data, updated_at) values (auth.uid(), p_data, now())
  on conflict (user_id) do update set data = excluded.data, updated_at = now();
end $$;

revoke all on function public.load_game() from public, anon;
revoke all on function public.save_game(jsonb) from public, anon;
grant execute on function public.load_game() to authenticated;
grant execute on function public.save_game(jsonb) to authenticated;
