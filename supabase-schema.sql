-- PCMatch: esquema inicial. Ejecutar en Supabase SQL Editor en un proyecto nuevo.
create type public.request_status as enum ('draft','published','quoting','accepted','closed','cancelled');
create type public.quote_status as enum ('sent','viewed','accepted','not_selected','withdrawn');
create type public.verification_status as enum ('pending','verified','suspended','rejected');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Usuario PCMatch', city text,
  created_at timestamptz not null default now()
);
create table public.contact_details (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  email text, phone text, updated_at timestamptz not null default now()
);
create table public.user_roles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  role text not null check (role in ('buyer','seller','admin')),
  primary key (user_id, role)
);
create table public.seller_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  business_name text not null, ruc text, bio text,
  verification public.verification_status not null default 'pending',
  rating numeric(2,1) default 0, created_at timestamptz not null default now()
);
create table public.requests (
  id uuid primary key default gen_random_uuid(), buyer_id uuid not null references public.profiles(id),
  title text not null, category text not null, use_case text, budget_max numeric,
  city text, details text not null, status public.request_status not null default 'draft',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.quotes (
  id uuid primary key default gen_random_uuid(), request_id uuid not null references public.requests(id) on delete cascade,
  seller_id uuid not null references public.profiles(id), price numeric not null check (price > 0),
  configuration text not null, warranty text, delivery_time text, note text,
  status public.quote_status not null default 'sent', created_at timestamptz not null default now(),
  unique(request_id, seller_id)
);
create table public.contact_unlocks (
  id uuid primary key default gen_random_uuid(), request_id uuid not null references public.requests(id),
  quote_id uuid not null unique references public.quotes(id), buyer_id uuid not null references public.profiles(id),
  seller_id uuid not null references public.profiles(id), unlocked_at timestamptz not null default now()
);
create table public.ratings (
  id uuid primary key default gen_random_uuid(), unlock_id uuid not null unique references public.contact_unlocks(id),
  author_id uuid not null references public.profiles(id), recipient_id uuid not null references public.profiles(id),
  score smallint not null check (score between 1 and 5), comment text, created_at timestamptz not null default now()
);

-- Datos de una cuenta nunca se exponen directamente: solo mediante la función de desbloqueo.
alter table public.profiles enable row level security; alter table public.contact_details enable row level security;
alter table public.user_roles enable row level security; alter table public.seller_profiles enable row level security;
alter table public.requests enable row level security; alter table public.quotes enable row level security;
alter table public.contact_unlocks enable row level security; alter table public.ratings enable row level security;

create function public.is_verified_seller() returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.seller_profiles where user_id=(select auth.uid()) and verification='verified')
$$;
create function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.user_roles where user_id=(select auth.uid()) and role='admin')
$$;

create policy "own profile" on public.profiles for select to authenticated using (id=(select auth.uid()) or public.is_admin());
create policy "create own profile" on public.profiles for insert to authenticated with check (id=(select auth.uid()));
create policy "update own profile" on public.profiles for update to authenticated using (id=(select auth.uid())) with check (id=(select auth.uid()));
create policy "own contact only" on public.contact_details for all to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create policy "own roles" on public.user_roles for select to authenticated using (user_id=(select auth.uid()) or public.is_admin());
create policy "seller profiles readable" on public.seller_profiles for select to authenticated using (verification='verified' or user_id=(select auth.uid()) or public.is_admin());
create policy "seller creates own" on public.seller_profiles for insert to authenticated with check (user_id=(select auth.uid()));
create policy "seller updates own pending profile" on public.seller_profiles for update to authenticated using (user_id=(select auth.uid()) or public.is_admin()) with check (user_id=(select auth.uid()) or public.is_admin());
create policy "buyers create requests" on public.requests for insert to authenticated with check (buyer_id=(select auth.uid()));
create policy "buyers read own, sellers read open" on public.requests for select to authenticated using (buyer_id=(select auth.uid()) or (public.is_verified_seller() and status in ('published','quoting')) or public.is_admin());
create policy "buyer updates own request" on public.requests for update to authenticated using (buyer_id=(select auth.uid()) or public.is_admin()) with check (buyer_id=(select auth.uid()) or public.is_admin());
create policy "buyer can see offers; seller own offer" on public.quotes for select to authenticated using (seller_id=(select auth.uid()) or exists(select 1 from public.requests r where r.id=request_id and r.buyer_id=(select auth.uid())) or public.is_admin());
create policy "verified seller submits quote" on public.quotes for insert to authenticated with check (seller_id=(select auth.uid()) and public.is_verified_seller());
create policy "seller updates own quote" on public.quotes for update to authenticated using (seller_id=(select auth.uid()) or public.is_admin()) with check (seller_id=(select auth.uid()) or public.is_admin());
create policy "participants see unlock" on public.contact_unlocks for select to authenticated using (buyer_id=(select auth.uid()) or seller_id=(select auth.uid()) or public.is_admin());
create policy "participants rate" on public.ratings for insert to authenticated with check (author_id=(select auth.uid()) and exists(select 1 from public.contact_unlocks u where u.id=unlock_id and (u.buyer_id=(select auth.uid()) or u.seller_id=(select auth.uid()))));

-- Esta RPC es el único camino para aceptar una cotización y desbloquear contacto.
create function public.accept_quote(p_quote_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare q public.quotes; r public.requests; unlocked_id uuid;
begin
  select * into q from public.quotes where id=p_quote_id for update;
  select * into r from public.requests where id=q.request_id for update;
  if q.id is null then raise exception 'Cotización no encontrada'; end if;
  if r.buyer_id <> (select auth.uid()) then raise exception 'No autorizado'; end if;
  if r.status not in ('published','quoting') then raise exception 'La solicitud ya no acepta cotizaciones'; end if;
  update public.quotes set status=case when id=p_quote_id then 'accepted' else 'not_selected' end where request_id=r.id;
  update public.requests set status='accepted', updated_at=now() where id=r.id;
  insert into public.contact_unlocks(request_id,quote_id,buyer_id,seller_id) values(r.id,q.id,r.buyer_id,q.seller_id) returning id into unlocked_id;
  return unlocked_id;
end $$;

-- Solo los dos participantes pueden obtener contactos una vez desbloqueados.
create function public.get_unlocked_contact(p_quote_id uuid) returns table(display_name text,email text,phone text) language sql security definer set search_path='' as $$
  select p.display_name,c.email,c.phone from public.contact_unlocks u join public.contact_details c on c.user_id=case when u.buyer_id=(select auth.uid()) then u.seller_id else u.buyer_id end join public.profiles p on p.id=c.user_id
  where u.quote_id=p_quote_id and ((select auth.uid())=u.buyer_id or (select auth.uid())=u.seller_id)
$$;
grant execute on function public.accept_quote(uuid), public.get_unlocked_contact(uuid) to authenticated;

-- Crear perfil al iniciar sesión. El rol se elige después en la aplicación.
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name','Usuario PCMatch'));
  insert into public.contact_details(user_id,email) values(new.id,new.email);
  insert into public.user_roles(user_id,role) values(new.id,'buyer');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
