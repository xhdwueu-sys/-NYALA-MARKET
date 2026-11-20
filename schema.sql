create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  city text,
  role text not null default 'user' check (role in ('user','admin')),
  verified_seller boolean not null default false,
  verification_note text,
  created_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null unique,
  slug text not null unique,
  icon text not null default 'grid',
  sort_order int not null default 0,
  active boolean not null default true
);

-- قواعد الرسوم: حسب القسم + نوع الإعلان (عادي / مميز)
create table if not exists public.fee_rules (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete cascade, -- null = سعر افتراضي لكل الأقسام
  is_featured boolean not null default false,
  price_sdg numeric(12,2) not null check (price_sdg >= 0),
  duration_days int not null default 30 check (duration_days > 0),
  note_ar text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (category_id, is_featured)
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  category_id uuid not null references public.categories(id),
  title text not null check (char_length(title) between 5 and 120),
  description text not null default '',
  price numeric(14,2),
  currency text not null default 'SDG',
  city text not null default 'غير محدد',
  condition text not null default 'used' check (condition in ('new','used')),
  phone text,
  whatsapp text,
  is_featured boolean not null default false,
  fee_amount numeric(12,2) not null default 0,
  payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid','pending_review','paid','waived')),
  payment_method text
    check (payment_method is null or payment_method in ('cash','electronic')),
  paid_at timestamptz,
  status text not null default 'pending'
    check (status in ('pending','active','rejected','sold','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.listing_images (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  image_url text not null,
  sort_order int not null default 0
);

create table if not exists public.listing_reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (reason in ('fraud','fake_item','wrong_category','prohibited','duplicate','other')),
  details text not null default '',
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  unique (listing_id, reporter_id)
);

create index if not exists listings_status_created_idx on public.listings(status, created_at desc);
create index if not exists listings_category_idx on public.listings(category_id);
create index if not exists listings_city_idx on public.listings(city);
create index if not exists listings_payment_status_idx on public.listings(payment_status);
create index if not exists listing_reports_status_created_idx on public.listing_reports(status, created_at desc);

create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.fee_rules enable row level security;
alter table public.listings enable row level security;
alter table public.listing_images enable row level security;
alter table public.listing_reports enable row level security;

-- Profiles
create policy "profiles read own or admin" on public.profiles
for select using (id = auth.uid() or public.is_admin());
create policy "profiles update own" on public.profiles
for update using (id = auth.uid()) with check (id = auth.uid());
create policy "admin verifies sellers" on public.profiles
for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Categories
create policy "categories visible" on public.categories
for select using (active = true or public.is_admin());
create policy "admin manages categories" on public.categories
for all using (public.is_admin()) with check (public.is_admin());

-- Fee rules (public read active, admin manage)
create policy "fee rules visible" on public.fee_rules
for select using (active = true or public.is_admin());
create policy "admin manages fee rules" on public.fee_rules
for all using (public.is_admin()) with check (public.is_admin());

-- Listings
create policy "active listings public, seller/admin see own" on public.listings
for select using (status = 'active' or seller_id = auth.uid() or public.is_admin());
create policy "signed-in user creates own listing" on public.listings
for insert to authenticated with check (seller_id = auth.uid());
create policy "seller updates own pending or active listing" on public.listings
for update to authenticated
using (seller_id = auth.uid() or public.is_admin())
with check (seller_id = auth.uid() or public.is_admin());
create policy "admin deletes listings" on public.listings
for delete using (public.is_admin());

-- Images
create policy "listing images follow listing visibility" on public.listing_images
for select using (
  exists (select 1 from public.listings l
    where l.id = listing_id and (l.status = 'active' or l.seller_id = auth.uid() or public.is_admin()))
);
create policy "seller adds image to own listing" on public.listing_images
for insert to authenticated with check (
  exists (select 1 from public.listings l where l.id = listing_id and l.seller_id = auth.uid())
);
create policy "seller or admin deletes image" on public.listing_images
for delete using (
  exists (select 1 from public.listings l where l.id = listing_id and (l.seller_id = auth.uid() or public.is_admin()))
);

-- Reports
create policy "reporter and admin can read reports" on public.listing_reports
for select to authenticated using (reporter_id = auth.uid() or public.is_admin());
create policy "authenticated users can report listings" on public.listing_reports
for insert to authenticated with check (
  reporter_id = auth.uid()
  and exists (select 1 from public.listings l where l.id = listing_id and l.status = 'active')
);
create policy "admin manages reports" on public.listing_reports
for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Auto profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Prevent non-admins from changing moderation status
create or replace function public.guard_listing_moderation()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() and new.status is distinct from old.status then
    raise exception 'Only administrators can change listing moderation status';
  end if;
  if not public.is_admin() and new.payment_status is distinct from old.payment_status then
    raise exception 'Only administrators can change payment status';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_listing_moderation_trigger on public.listings;
create trigger guard_listing_moderation_trigger
before update on public.listings
for each row execute procedure public.guard_listing_moderation();

-- Storage bucket
insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true)
on conflict (id) do nothing;

create policy "public can view listing images" on storage.objects
for select using (bucket_id = 'listing-images');
create policy "authenticated upload listing images" on storage.objects
for insert to authenticated with check (bucket_id = 'listing-images');
create policy "owner or admin deletes listing images" on storage.objects
for delete to authenticated using (bucket_id = 'listing-images' and (owner = auth.uid() or public.is_admin()));
