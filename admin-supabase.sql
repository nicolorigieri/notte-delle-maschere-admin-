-- ESEGUI QUESTO FILE UNA VOLTA, DOPO supabase.sql, NEL SQL EDITOR DI SUPABASE
-- Aggiunge il PIN dell'organizzatore e le funzioni per gestire classifica e chiusura
-- dal sito admin separato, senza dare accesso diretto alle tabelle da fuori.

alter table public.contest_settings add column if not exists admin_pin text not null default 'CAMBIAMI';

-- Il PIN NON deve essere leggibile dal sito degli ospiti: tolgo l'accesso diretto
-- alla tabella e lascio solo le colonne che servono per votare.
revoke select on public.contest_settings from anon, authenticated;
drop policy if exists "Anyone can view contest settings" on public.contest_settings;
grant select (voting_closed, closes_at) on public.contest_settings to anon, authenticated;
create policy "Anyone can view voting status"
  on public.contest_settings for select
  to anon, authenticated
  using (true);

-- Cambia qui il PIN dell'organizzatore (5-20 caratteri).
update public.contest_settings set admin_pin = 'Zucca-4817' where id = true;

create or replace function public.admin_check(pin text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.contest_settings where id = true and admin_pin = pin) then
    raise exception 'PIN errato';
  end if;
end;
$$;

create or replace function public.admin_set_closing(pin text, closed boolean, closes_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.admin_check(pin);
  update public.contest_settings set voting_closed = closed, closes_at = closes_at where id = true;
end;
$$;

create or replace function public.admin_delete_contestant(pin text, contestant uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.admin_check(pin);
  delete from public.contestants where id = contestant;
end;
$$;

create or replace function public.admin_reset_vote(pin text, contestant uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.admin_check(pin);
  delete from public.votes where contestant_id = contestant;
  update public.contestants set vote_count = 0 where id = contestant;
end;
$$;

revoke all on function public.admin_check(text) from public;
revoke all on function public.admin_set_closing(text, boolean, timestamptz) from public;
revoke all on function public.admin_delete_contestant(text, uuid) from public;
revoke all on function public.admin_reset_vote(text, uuid) from public;
grant execute on function public.admin_check(text) to anon, authenticated;
grant execute on function public.admin_set_closing(text, boolean, timestamptz) to anon, authenticated;
grant execute on function public.admin_delete_contestant(text, uuid) to anon, authenticated;
grant execute on function public.admin_reset_vote(text, uuid) to anon, authenticated;

-- I costumi sono già leggibili con la chiave anon (stessa policy del sito ospiti),
-- quindi il pannello admin li legge con una normale select, senza bisogno di funzioni apposite.
