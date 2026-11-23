-- SEND IT: anonyme Spiel-Statistik. Einmal im Supabase SQL Editor ausführen (unabhängig von den anderen Dateien).
-- Das Spiel schickt beim Öffnen und nach jedem Lauf ein Ereignis mit einer zufälligen Geräte-Kennung (kein Name, keine Konto-ID).
-- Schreiben geht nur über log_event, lesen nur du im Supabase-Dashboard (SQL Editor). Kann mehrfach ausgeführt werden.

create table if not exists public.events (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  device text not null check (device ~ '^[a-z0-9]{8,32}$'),
  kind text not null check (kind in ('open', 'run')),
  mode text,          -- ski, board, bike (Downhill Tricks) oder race (DH Race)
  map text,           -- alps, japan, wiehen
  secs integer,       -- Dauer des Laufs in Sekunden
  score integer,
  dist integer,       -- Meter
  race_ms integer,    -- Race-Zeit in Millisekunden (leer bei Abbruch)
  touch boolean,      -- Handy/Tablet
  logged_in boolean,  -- mit Konto angemeldet
  lang text
);
create index if not exists events_device_time on public.events (device, created_at);
create index if not exists events_time on public.events (created_at);

alter table public.events enable row level security;
revoke all on public.events from anon, authenticated;

-- Zahl aus dem Ereignis: fehlt sie, bleibt das Feld leer; sonst auf 0 bis hi begrenzt
create or replace function public.event_int(v text, hi integer) returns integer
language sql immutable as $$ select case when v is null then null else least(greatest(v::integer, 0), hi) end $$;
revoke all on function public.event_int(text, integer) from public, anon, authenticated;

-- Ereignis eintragen. Ungültige Daten werden still verworfen; höchstens 300 Ereignisse pro Gerät und Tag.
create or replace function public.log_event(p jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p is null or jsonb_typeof(p) <> 'object' or octet_length(p::text) > 1000 then return; end if;
  if (select count(*) from public.events where device = p->>'device' and created_at > now() - interval '1 day') >= 300 then return; end if;
  insert into public.events (device, kind, mode, map, secs, score, dist, race_ms, touch, logged_in, lang)
  values (
    p->>'device', p->>'kind', left(p->>'mode', 10), left(p->>'map', 10),
    public.event_int(p->>'secs', 86400), public.event_int(p->>'score', 100000000),
    public.event_int(p->>'dist', 1000000), public.event_int(p->>'race_ms', 3600000),
    (p->>'touch')::boolean, (p->>'logged_in')::boolean, left(p->>'lang', 5)
  );
exception when others then return;
end $$;
revoke all on function public.log_event(jsonb) from public;
grant execute on function public.log_event(jsonb) to anon, authenticated;

notify pgrst, 'reload schema';

-- ===========================================================================
-- Auswertung: diese Abfragen einzeln im SQL Editor ausführen (Tage nach deutscher Zeit).
-- ===========================================================================

-- Spieler pro Tag (verschiedene Geräte, die das Spiel geöffnet haben) und davon neu
-- select d.tag, count(*) as spieler, count(*) filter (where d.tag = f.erster_tag) as neu
-- from (select distinct device, (created_at at time zone 'Europe/Berlin')::date as tag from public.events) d
-- join (select device, min((created_at at time zone 'Europe/Berlin')::date) as erster_tag from public.events group by device) f using (device)
-- group by d.tag order by d.tag;

-- Wiederkehr am nächsten Tag: von den neuen Spielern eines Tages, wie viele kamen am Tag danach wieder (Ziel: über 25 bis 30 %)
-- with f as (select device, min((created_at at time zone 'Europe/Berlin')::date) as erster_tag from public.events group by device),
--      a as (select distinct device, (created_at at time zone 'Europe/Berlin')::date as tag from public.events)
-- select f.erster_tag, count(*) as neu,
--        count(*) filter (where exists (select 1 from a where a.device = f.device and a.tag = f.erster_tag + 1)) as am_naechsten_tag,
--        round(100.0 * count(*) filter (where exists (select 1 from a where a.device = f.device and a.tag = f.erster_tag + 1)) / count(*), 1) as prozent
-- from f group by f.erster_tag order by f.erster_tag;

-- Läufe pro Modus, Dauer und Läufe pro Spieler (letzte 7 Tage)
-- select mode, count(*) as laeufe, count(distinct device) as spieler, round(avg(secs)) as sek_im_schnitt,
--        round(count(*)::numeric / count(distinct device), 1) as laeufe_pro_spieler
-- from public.events where kind = 'run' and created_at > now() - interval '7 days' group by mode order by laeufe desc;

-- Spielzeit pro Spieler und Tag in Minuten (letzte 7 Tage)
-- select (created_at at time zone 'Europe/Berlin')::date as tag, round(sum(secs) / 60.0 / count(distinct device), 1) as minuten_pro_spieler
-- from public.events where kind = 'run' and created_at > now() - interval '7 days' group by 1 order by 1;

-- Handy oder Computer, angemeldet oder nicht (letzte 7 Tage)
-- select touch, logged_in, count(distinct device) as spieler from public.events where created_at > now() - interval '7 days' group by 1, 2;

-- Neue Konten pro Tag
-- select (created_at at time zone 'Europe/Berlin')::date as tag, count(*) as neue_konten from public.profiles group by 1 order by 1;
