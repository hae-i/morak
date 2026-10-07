-- Add address-search places without changing existing records or RLS.
begin;

create or replace function public.morak_valid_meetup_place(p_place jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
begin
  if p_place is null or p_place = 'null'::jsonb then return true; end if;
  if jsonb_typeof(p_place) <> 'object' then return false; end if;
  if exists (select 1 from jsonb_object_keys(p_place) as k(key)
    where key not in ('name','address','latitude','longitude','source')) then return false; end if;
  if jsonb_typeof(p_place->'name') is distinct from 'string'
    or length(btrim(p_place->>'name')) not between 1 and 200
    or length(p_place->>'name') > 200
    or jsonb_typeof(p_place->'address') is distinct from 'string'
    or length(p_place->>'address') > 500
    or jsonb_typeof(p_place->'latitude') is distinct from 'number'
    or jsonb_typeof(p_place->'longitude') is distinct from 'number'
    or jsonb_typeof(p_place->'source') is distinct from 'string'
    or (p_place->>'source') not in ('naver_search','naver_geocode','manual_pin') then return false; end if;
  return (p_place->>'latitude')::numeric between -90 and 90
    and (p_place->>'longitude')::numeric between -180 and 180;
end;
$$;

revoke all on function public.morak_valid_meetup_place(jsonb) from public, anon;
grant execute on function public.morak_valid_meetup_place(jsonb) to authenticated;


commit;
