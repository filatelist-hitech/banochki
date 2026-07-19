-- R3 server truth. All mutable family data is scoped by an active membership.
create extension if not exists pgcrypto;

create type public.family_role as enum ('owner', 'admin', 'member', 'viewer');
create type public.membership_state as enum ('active', 'removed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.families (
  id uuid primary key, name text not null check (char_length(trim(name)) between 1 and 80),
  created_at timestamptz not null default now(), archived_at timestamptz
);
create table public.family_members (
  id uuid primary key, family_id uuid not null references public.families(id) on delete restrict,
  account_id uuid references auth.users(id) on delete set null,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  role public.family_role not null default 'member', state public.membership_state not null default 'active',
  created_at timestamptz not null default now(), removed_at timestamptz,
  unique (family_id, account_id), check ((state = 'active' and removed_at is null) or state = 'removed')
);
create table public.devices (
  id uuid primary key, account_id uuid not null references auth.users(id) on delete cascade,
  label text, created_at timestamptz not null default now(), revoked_at timestamptz
);
create table public.storage_locations (
  id uuid primary key, family_id uuid not null references public.families(id) on delete restrict,
  parent_id uuid references public.storage_locations(id) on delete restrict, name text not null,
  description text, sort_order integer not null default 0, version integer not null default 1,
  updated_at_server timestamptz not null default now(), updated_by_device uuid references public.devices(id), archived_at timestamptz
);
create table public.batches (
  id uuid primary key, family_id uuid not null references public.families(id) on delete restrict,
  name text not null, category text not null, quantity_unit text not null, initial_quantity integer not null check (initial_quantity > 0),
  storage_location_id uuid references public.storage_locations(id) on delete restrict, metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1, updated_at_server timestamptz not null default now(),
  updated_by_device uuid references public.devices(id), archived_at timestamptz
);
create table public.qr_codes (
  id uuid primary key, family_id uuid not null references public.families(id) on delete restrict,
  public_token text not null unique, short_code text not null, target_type text not null check(target_type in ('batch','storage_location','unlinked')),
  target_id uuid, state text not null check(state in ('unlinked','active','revoked','replaced')),
  device_id uuid references public.devices(id), created_at timestamptz not null default now(), revoked_at timestamptz,
  unique(family_id, short_code)
);
create table public.inventory_events (
  id uuid primary key, family_id uuid not null references public.families(id) on delete restrict,
  batch_id uuid not null references public.batches(id) on delete restrict, actor_member_id uuid not null references public.family_members(id) on delete restrict,
  event_type text not null, quantity_delta integer not null, payload jsonb not null default '{}'::jsonb,
  client_created_at timestamptz not null, device_id uuid not null references public.devices(id) on delete restrict,
  idempotency_key uuid not null, created_at timestamptz not null default now(), unique(family_id, device_id, idempotency_key)
);
create table public.batch_photos (
  id uuid primary key, family_id uuid not null references public.families(id) on delete restrict,
  batch_id uuid not null references public.batches(id) on delete restrict, object_path text not null unique,
  checksum text not null, mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp')),
  bytes integer not null check(bytes > 0 and bytes <= 10485760), state text not null default 'pending',
  created_at timestamptz not null default now(), archived_at timestamptz
);
create table public.family_invites (
  id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete restrict,
  role public.family_role not null check(role <> 'owner'), token_hash text not null unique, short_code_hash text not null unique,
  created_by uuid not null references public.family_members(id), created_at timestamptz not null default now(),
  expires_at timestamptz not null, max_uses integer not null default 1 check(max_uses between 1 and 20), use_count integer not null default 0,
  revoked_at timestamptz, accepted_at timestamptz, accepted_by uuid references auth.users(id), claimed_member_id uuid references public.family_members(id),
  check(expires_at > created_at)
);
create table public.sync_changes (
  server_sequence bigint generated always as identity primary key, family_id uuid not null references public.families(id) on delete restrict,
  entity_type text not null, entity_id uuid not null, operation_id uuid not null, payload jsonb not null, tombstone boolean not null default false,
  created_at timestamptz not null default now(), unique(family_id, operation_id)
);
create table public.sync_receipts (
  operation_id uuid primary key, family_id uuid not null references public.families(id) on delete restrict,
  idempotency_key uuid not null, server_sequence bigint references public.sync_changes(server_sequence), created_at timestamptz not null default now(),
  unique(family_id, idempotency_key)
);
create table public.sync_conflicts (
  id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete restrict,
  entity_type text not null, entity_id uuid not null, local_payload jsonb not null, remote_payload jsonb not null,
  status text not null default 'open' check(status in ('open','resolved')), created_at timestamptz not null default now(), resolved_at timestamptz
);
create index sync_changes_family_cursor_idx on public.sync_changes(family_id, server_sequence);
create index membership_account_idx on public.family_members(account_id, family_id) where state = 'active';

create function public.has_family_role(p_family uuid, p_roles public.family_role[]) returns boolean
language sql stable security definer set search_path = public as $$
 select exists (select 1 from public.family_members m where m.family_id=p_family and m.account_id=auth.uid() and m.state='active' and m.role=any(p_roles));
$$;
revoke all on function public.has_family_role(uuid, public.family_role[]) from public;
grant execute on function public.has_family_role(uuid, public.family_role[]) to authenticated;

-- Atomic acceptance locks an invite; client passes a SHA-256 encoded token, raw token never persists.
create function public.accept_family_invite(p_token_hash text, p_claim_member uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v public.family_invites; v_member uuid;
begin
 select * into v from public.family_invites where token_hash=p_token_hash for update;
 if not found or v.revoked_at is not null or v.expires_at <= now() or v.use_count >= v.max_uses then raise exception 'invite_invalid'; end if;
 select id into v_member from public.family_members where family_id=v.family_id and account_id=auth.uid() and state='active';
 if v_member is null then
   if p_claim_member is not null then update public.family_members set account_id=auth.uid(), role=v.role where id=p_claim_member and family_id=v.family_id and account_id is null and state='active' returning id into v_member; end if;
   if v_member is null then insert into public.family_members(id,family_id,account_id,display_name,role) values(gen_random_uuid(),v.family_id,auth.uid(),coalesce((select display_name from public.profiles where id=auth.uid()),'Участник'),v.role) returning id into v_member; end if;
 end if;
 update public.family_invites set use_count=use_count+1, accepted_at=now(), accepted_by=auth.uid(), claimed_member_id=v_member where id=v.id;
 return v_member;
end $$;
revoke all on function public.accept_family_invite(text, uuid) from public;
grant execute on function public.accept_family_invite(text, uuid) to authenticated;

alter table public.profiles enable row level security; alter table public.families enable row level security; alter table public.family_members enable row level security; alter table public.devices enable row level security; alter table public.storage_locations enable row level security; alter table public.batches enable row level security; alter table public.qr_codes enable row level security; alter table public.inventory_events enable row level security; alter table public.batch_photos enable row level security; alter table public.family_invites enable row level security; alter table public.sync_changes enable row level security; alter table public.sync_receipts enable row level security; alter table public.sync_conflicts enable row level security;
create policy profile_self on public.profiles for all using(id=auth.uid()) with check(id=auth.uid());
create policy family_read on public.families for select using(public.has_family_role(id, array['owner','admin','member','viewer']::public.family_role[]));
create policy member_read on public.family_members for select using(public.has_family_role(family_id, array['owner','admin','member','viewer']::public.family_role[]));
create policy device_self on public.devices for all using(account_id=auth.uid()) with check(account_id=auth.uid());
create policy locations_read on public.storage_locations for select using(public.has_family_role(family_id,array['owner','admin','member','viewer']::public.family_role[]));
create policy locations_write on public.storage_locations for all using(public.has_family_role(family_id,array['owner','admin']::public.family_role[])) with check(public.has_family_role(family_id,array['owner','admin']::public.family_role[]));
create policy batches_read on public.batches for select using(public.has_family_role(family_id,array['owner','admin','member','viewer']::public.family_role[]));
create policy batches_write on public.batches for all using(public.has_family_role(family_id,array['owner','admin','member']::public.family_role[])) with check(public.has_family_role(family_id,array['owner','admin','member']::public.family_role[]));
create policy events_read on public.inventory_events for select using(public.has_family_role(family_id,array['owner','admin','member','viewer']::public.family_role[]));
create policy events_insert on public.inventory_events for insert with check(public.has_family_role(family_id,array['owner','admin','member']::public.family_role[]));
create policy qr_read on public.qr_codes for select using(public.has_family_role(family_id,array['owner','admin','member','viewer']::public.family_role[]));
create policy qr_write on public.qr_codes for all using(public.has_family_role(family_id,array['owner','admin','member']::public.family_role[])) with check(public.has_family_role(family_id,array['owner','admin','member']::public.family_role[]));
create policy photo_read on public.batch_photos for select using(public.has_family_role(family_id,array['owner','admin','member','viewer']::public.family_role[]));
create policy photo_write on public.batch_photos for all using(public.has_family_role(family_id,array['owner','admin','member']::public.family_role[])) with check(public.has_family_role(family_id,array['owner','admin','member']::public.family_role[]));
create policy invites_owner_admin on public.family_invites for all using(public.has_family_role(family_id,array['owner','admin']::public.family_role[])) with check(public.has_family_role(family_id,array['owner','admin']::public.family_role[]));
create policy changes_read on public.sync_changes for select using(public.has_family_role(family_id,array['owner','admin','member','viewer']::public.family_role[]));
create policy receipts_read on public.sync_receipts for select using(public.has_family_role(family_id,array['owner','admin','member']::public.family_role[]));
create policy conflicts_read on public.sync_conflicts for select using(public.has_family_role(family_id,array['owner','admin','member']::public.family_role[]));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values ('batch-photos','batch-photos',false,10485760,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy photos_storage_read on storage.objects for select using(bucket_id='batch-photos' and public.has_family_role((storage.foldername(name))[2]::uuid,array['owner','admin','member','viewer']::public.family_role[]));
create policy photos_storage_write on storage.objects for insert with check(bucket_id='batch-photos' and name ~ '^families/[0-9a-f-]+/batches/[0-9a-f-]+/[0-9a-f-]+\\.(jpg|png|webp)$' and public.has_family_role((storage.foldername(name))[2]::uuid,array['owner','admin','member']::public.family_role[]));

-- Push is deliberately event-only in R3. Replays return the existing receipt;
-- the caller never gets a second inventory effect.
create function public.push_inventory_event(p_operation_id uuid, p_event jsonb) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_sequence bigint; v_family uuid := (p_event->>'family_id')::uuid;
begin
 if not public.has_family_role(v_family, array['owner','admin','member']::public.family_role[]) then raise exception 'not_allowed'; end if;
 select server_sequence into v_sequence from public.sync_receipts where operation_id=p_operation_id;
 if found then return v_sequence; end if;
 insert into public.inventory_events(id,family_id,batch_id,actor_member_id,event_type,quantity_delta,payload,client_created_at,device_id,idempotency_key)
 values (p_operation_id,v_family,(p_event->>'batch_id')::uuid,(p_event->>'actor_member_id')::uuid,p_event->>'event_type',(p_event->>'quantity_delta')::integer,coalesce(p_event->'payload','{}'),(p_event->>'client_created_at')::timestamptz,(p_event->>'device_id')::uuid,(p_event->>'idempotency_key')::uuid)
 on conflict(family_id,device_id,idempotency_key) do nothing;
 insert into public.sync_changes(family_id,entity_type,entity_id,operation_id,payload) values(v_family,'inventory_event',p_operation_id,p_operation_id,p_event) returning server_sequence into v_sequence;
 insert into public.sync_receipts(operation_id,family_id,idempotency_key,server_sequence) values(p_operation_id,v_family,(p_event->>'idempotency_key')::uuid,v_sequence) on conflict(operation_id) do nothing;
 return v_sequence;
end $$;
create function public.pull_changes(p_family_id uuid, p_after bigint, p_limit integer default 200) returns setof public.sync_changes
language sql stable security definer set search_path = public as $$
 select * from public.sync_changes where family_id=p_family_id and server_sequence > p_after and public.has_family_role(p_family_id,array['owner','admin','member','viewer']::public.family_role[]) order by server_sequence limit least(greatest(p_limit,1),500)
$$;
revoke all on function public.push_inventory_event(uuid,jsonb) from public;
revoke all on function public.pull_changes(uuid,bigint,integer) from public;
grant execute on function public.push_inventory_event(uuid,jsonb), public.pull_changes(uuid,bigint,integer) to authenticated;
