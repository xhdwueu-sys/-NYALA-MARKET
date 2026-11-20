-- Run this migration on an existing Nyala Market Supabase database.
alter table public.profiles
  add column if not exists verified_seller boolean not null default false,
  add column if not exists verification_note text;

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
create index if not exists listing_reports_status_created_idx on public.listing_reports(status, created_at desc);
alter table public.listing_reports enable row level security;

drop policy if exists "reporter and admin can read reports" on public.listing_reports;
create policy "reporter and admin can read reports" on public.listing_reports
for select to authenticated using (reporter_id = auth.uid() or public.is_admin());

drop policy if exists "authenticated users can report listings" on public.listing_reports;
create policy "authenticated users can report listings" on public.listing_reports
for insert to authenticated with check (
 reporter_id = auth.uid()
 and exists (select 1 from public.listings l where l.id = listing_id and l.status = 'active')
);

drop policy if exists "admin manages reports" on public.listing_reports;
create policy "admin manages reports" on public.listing_reports
for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin verifies sellers" on public.profiles;
create policy "admin verifies sellers" on public.profiles
for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Prevent sellers from self-approving their own ads by changing status directly.
create or replace function public.guard_listing_moderation()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() and new.status is distinct from old.status then
    raise exception 'Only administrators can change listing moderation status';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_listing_moderation_trigger on public.listings;
create trigger guard_listing_moderation_trigger
before update on public.listings
for each row execute procedure public.guard_listing_moderation();
