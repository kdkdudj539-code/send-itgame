-- SEND IT: Spielernamen ändern. Einmal im Supabase SQL Editor ausführen (nach supabase-setup.sql).
-- Der Name ist gleichzeitig der Login (intern Name@spieler.sendit-game.de). Deshalb ändert die Funktion
-- Profilname und Login-Adresse zusammen. Jeder kann nur seinen eigenen Namen ändern, vergebene Namen gehen nicht.

create or replace function public.rename_player(p_name text) returns text
language plpgsql security definer set search_path = public, auth as $$
declare
  uid uuid := auth.uid();
  mail text;
begin
  if uid is null then raise exception 'nicht angemeldet'; end if;
  if p_name is null or char_length(p_name) not between 3 and 16 or p_name !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'ungueltiger name';
  end if;
  mail := lower(p_name) || '@spieler.sendit-game.de';
  if exists (select 1 from public.profiles where lower(name) = lower(p_name) and id <> uid)
     or exists (select 1 from auth.users where lower(email) = mail and id <> uid) then
    raise exception 'name vergeben';
  end if;
  update public.profiles set name = p_name where id = uid;
  update auth.users
     set email = mail,
         raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('name', p_name),
         updated_at = now()
   where id = uid;
  update auth.identities
     set identity_data = coalesce(identity_data, '{}'::jsonb) || jsonb_build_object('email', mail),
         updated_at = now()
   where user_id = uid and provider = 'email';
  return p_name;
end $$;

revoke all on function public.rename_player(text) from public, anon;
grant execute on function public.rename_player(text) to authenticated;

-- Supabase sofort Bescheid geben, dass es die neue Funktion gibt
notify pgrst, 'reload schema';
