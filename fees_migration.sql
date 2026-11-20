-- Migration: إضافة نظام الرسوم والمدفوعات لمنصة نيالا ماركت
-- نفّذ هذا الملف إذا كان عندك قاعدة بيانات قديمة مسبقاً

-- جدول قواعد الرسوم
create table if not exists public.fee_rules (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete cascade,
  is_featured boolean not null default false,
  price_sdg numeric(12,2) not null check (price_sdg >= 0),
  duration_days int not null default 30 check (duration_days > 0),
  note_ar text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (category_id, is_featured)
);

alter table public.fee_rules enable row level security;

drop policy if exists "fee rules visible" on public.fee_rules;
create policy "fee rules visible" on public.fee_rules
for select using (active = true or public.is_admin());

drop policy if exists "admin manages fee rules" on public.fee_rules;
create policy "admin manages fee rules" on public.fee_rules
for all using (public.is_admin()) with check (public.is_admin());

-- أعمدة الرسوم في الإعلانات
alter table public.listings
  add column if not exists is_featured boolean not null default false,
  add column if not exists fee_amount numeric(12,2) not null default 0,
  add column if not exists payment_status text not null default 'unpaid',
  add column if not exists payment_method text,
  add column if not exists paid_at timestamptz;

-- قيود الحالة (قد تفشل إذا كانت القيم القديمة غير متوافقة، عدّلها يدوياً إن لزم)
do $$
begin
  alter table public.listings drop constraint if exists listings_payment_status_check;
  alter table public.listings add constraint listings_payment_status_check
    check (payment_status in ('unpaid','pending_review','paid','waived'));
exception when others then null;
end $$;

do $$
begin
  alter table public.listings drop constraint if exists listings_payment_method_check;
  alter table public.listings add constraint listings_payment_method_check
    check (payment_method is null or payment_method in ('cash','electronic'));
exception when others then null;
end $$;

create index if not exists listings_payment_status_idx on public.listings(payment_status);

-- تحديث دالة الحماية لتشمل payment_status
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

-- بذور رسوم أولية (إذا لم تكن موجودة)
insert into public.fee_rules (category_id, is_featured, price_sdg, duration_days, note_ar)
values (null, false, 500, 30, 'رسوم إعلان عادي — 30 يوم')
on conflict do nothing;

insert into public.fee_rules (category_id, is_featured, price_sdg, duration_days, note_ar)
values (null, true, 1500, 30, 'رسوم إعلان مميز — ظهور أعلى + شارة')
on conflict do nothing;
