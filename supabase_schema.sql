-- SUVLASNIK PRO 1.1 – Supabase schema and baseline security
-- Run in Supabase SQL Editor. Review and test before production.
create extension if not exists pgcrypto;

create table if not exists public.buildings(
 id uuid primary key default gen_random_uuid(), name text not null,
 address text not null, city text not null default 'Split',
 created_at timestamptz not null default now()
);
create table if not exists public.members(
 id uuid primary key references auth.users(id) on delete cascade,
 building_id uuid not null references public.buildings(id) on delete cascade,
 email text, unit_label text not null, display_name text not null,
 share_percent numeric(9,6) not null default 0 check(share_percent>=0 and share_percent<=100),
 role text not null default 'owner' check(role in('admin','owner','manager')),
 active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.announcements(
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id) on delete cascade,
 title text not null, body text not null, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.issues(
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id) on delete cascade,
 created_by uuid not null references auth.users(id), title text not null, description text not null,
 location text, status text not null default 'zaprimljeno' check(status in('zaprimljeno','u obradi','riješeno')),
 photo_path text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.documents(
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id) on delete cascade,
 title text not null, category text not null, description text, storage_path text not null,
 uploaded_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.votes(
 id uuid primary key default gen_random_uuid(), building_id uuid not null references public.buildings(id) on delete cascade,
 title text not null, description text not null,
 vote_type text not null default 'anketa' check(vote_type in('anketa','formalna_odluka')),
 opens_at timestamptz not null default now(), closes_at timestamptz,
 status text not null default 'draft' check(status in('draft','open','closed')),
 created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.vote_options(
 id uuid primary key default gen_random_uuid(), vote_id uuid not null references public.votes(id) on delete cascade,
 label text not null
);
create table if not exists public.ballots(
 id uuid primary key default gen_random_uuid(), vote_id uuid not null references public.votes(id) on delete cascade,
 member_id uuid not null references public.members(id) on delete cascade,
 option_id uuid not null references public.vote_options(id) on delete cascade,
 created_at timestamptz not null default now(), unique(vote_id,member_id)
);
create table if not exists public.audit_log(
 id bigint generated always as identity primary key, building_id uuid not null references public.buildings(id) on delete cascade,
 actor uuid references auth.users(id), action text not null, entity text not null,
 entity_id uuid, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create or replace function public.my_building_id() returns uuid language sql stable security definer set search_path=public as $$
 select building_id from public.members where id=auth.uid() and active=true limit 1
$$;
create or replace function public.is_building_admin(p_building uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.members where id=auth.uid() and building_id=p_building and active=true and role='admin')
$$;
create or replace function public.audit_event(p_action text,p_entity text,p_entity_id uuid,p_details jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path=public as $$
declare b uuid;
begin b:=public.my_building_id(); if b is not null then
 insert into public.audit_log(building_id,actor,action,entity,entity_id,details) values(b,auth.uid(),p_action,p_entity,p_entity_id,coalesce(p_details,'{}'));
end if; end $$;

-- Prevent ordinary clients from directly inserting ballots. Voting is done through RPC.
revoke all on public.ballots from anon, authenticated;
create or replace function public.cast_vote(p_vote_id uuid,p_option_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v public.votes%rowtype; m public.members%rowtype; opt public.vote_options%rowtype;
begin
 select * into m from public.members where id=auth.uid() and active=true;
 if m.id is null then raise exception 'Korisnik nije aktivan suvlasnik'; end if;
 select * into v from public.votes where id=p_vote_id and building_id=m.building_id for update;
 if v.id is null or v.status<>'open' then raise exception 'Glasanje nije otvoreno'; end if;
 if v.closes_at is not null and now()>v.closes_at then raise exception 'Rok glasanja je istekao'; end if;
 select * into opt from public.vote_options where id=p_option_id and vote_id=p_vote_id;
 if opt.id is null then raise exception 'Neispravna opcija'; end if;
 insert into public.ballots(vote_id,member_id,option_id) values(p_vote_id,m.id,opt.id);
 perform public.audit_event('cast_vote','votes',p_vote_id,jsonb_build_object('vote_type',v.vote_type));
end $$;
grant execute on function public.cast_vote(uuid,uuid) to authenticated;

create or replace function public.vote_results(p_vote_id uuid)
returns table(option_id uuid,option_label text,votes_count bigint,share_percent numeric)
language plpgsql stable security definer set search_path=public as $$
declare b uuid;
begin
 b:=public.my_building_id();
 if b is null or not exists(select 1 from public.votes where id=p_vote_id and building_id=b) then raise exception 'Nedozvoljen pristup'; end if;
 return query
 select o.id,o.label,count(ba.id),coalesce(sum(m.share_percent),0)::numeric
 from public.vote_options o left join public.ballots ba on ba.option_id=o.id
 left join public.members m on m.id=ba.member_id
 where o.vote_id=p_vote_id group by o.id,o.label order by o.label;
end $$;
grant execute on function public.vote_results(uuid) to authenticated;

alter table public.buildings enable row level security;
alter table public.members enable row level security;
alter table public.announcements enable row level security;
alter table public.issues enable row level security;
alter table public.documents enable row level security;
alter table public.votes enable row level security;
alter table public.vote_options enable row level security;
alter table public.ballots enable row level security;
alter table public.audit_log enable row level security;

-- Buildings: members can see only their own building; admins manage its metadata.
create policy "building member read" on public.buildings for select to authenticated using(id=public.my_building_id());
create policy "member read own building" on public.members for select to authenticated using(building_id=public.my_building_id());
create policy "admin update members" on public.members for update to authenticated using(public.is_building_admin(building_id)) with check(public.is_building_admin(building_id));
create policy "members read announcements" on public.announcements for select to authenticated using(building_id=public.my_building_id());
create policy "admin manage announcements" on public.announcements for all to authenticated using(public.is_building_admin(building_id)) with check(public.is_building_admin(building_id));
create policy "members read issues" on public.issues for select to authenticated using(building_id=public.my_building_id());
create policy "members create own issue" on public.issues for insert to authenticated with check(building_id=public.my_building_id() and created_by=auth.uid());
create policy "admin update issues" on public.issues for update to authenticated using(public.is_building_admin(building_id)) with check(public.is_building_admin(building_id));
create policy "members read docs" on public.documents for select to authenticated using(building_id=public.my_building_id());
create policy "admin manage docs" on public.documents for all to authenticated using(public.is_building_admin(building_id)) with check(public.is_building_admin(building_id));
create policy "members read votes" on public.votes for select to authenticated using(building_id=public.my_building_id());
create policy "admin manage votes" on public.votes for all to authenticated using(public.is_building_admin(building_id)) with check(public.is_building_admin(building_id));
create policy "members read options" on public.vote_options for select to authenticated using(exists(select 1 from public.votes v where v.id=vote_id and v.building_id=public.my_building_id()));
create policy "admin manage options" on public.vote_options for all to authenticated using(exists(select 1 from public.votes v where v.id=vote_id and public.is_building_admin(v.building_id))) with check(exists(select 1 from public.votes v where v.id=vote_id and public.is_building_admin(v.building_id)));
create policy "admin read audit" on public.audit_log for select to authenticated using(public.is_building_admin(building_id));

-- Storage: create a PRIVATE bucket named building-files in Supabase Storage.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('building-files','building-files',false,20971520,array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=20971520;
create policy "building members upload files" on storage.objects for insert to authenticated
with check(bucket_id='building-files' and (storage.foldername(name))[1]=public.my_building_id()::text);
create policy "building members read files" on storage.objects for select to authenticated
using(bucket_id='building-files' and (storage.foldername(name))[1]=public.my_building_id()::text);
create policy "building admins delete files" on storage.objects for delete to authenticated
using(bucket_id='building-files' and public.is_building_admin(((storage.foldername(name))[1])::uuid));

-- Bootstrap: create the building, then invite the administrator via the Edge Function.
-- Do not insert personal data or ownership shares until verified from authoritative documents.
