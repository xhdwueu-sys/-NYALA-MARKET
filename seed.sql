-- التصنيفات الأساسية
insert into public.categories(name_ar, slug, icon, sort_order) values
('السيارات والمركبات','vehicles','car',1),
('الإلكترونيات','electronics','smartphone',2),
('المنزل والأثاث','home-furniture','sofa',3),
('العقارات','real-estate','house',4),
('الملابس والأزياء','fashion','shirt',5),
('المعدات والأدوات','equipment','wrench',6),
('الخدمات','services','briefcase',7)
on conflict (slug) do nothing;

-- قواعد الرسوم (بالجنيه السوداني)
-- null category_id = سعر افتراضي لكل الأقسام

-- إعلان عادي (افتراضي)
insert into public.fee_rules (category_id, is_featured, price_sdg, duration_days, note_ar)
values (null, false, 500, 30, 'رسوم إعلان عادي — 30 يوم')
on conflict do nothing;

-- إعلان مميز (افتراضي)
insert into public.fee_rules (category_id, is_featured, price_sdg, duration_days, note_ar)
values (null, true, 1500, 30, 'رسوم إعلان مميز — ظهور أعلى + شارة')
on conflict do nothing;

-- رسوم خاصة لبعض الأقسام (أمثلة قابلة للتعديل من لوحة الإدارة)
insert into public.fee_rules (category_id, is_featured, price_sdg, duration_days, note_ar)
select c.id, false, 1000, 30, 'رسوم إعلان سيارات عادي'
from public.categories c where c.slug = 'vehicles'
on conflict (category_id, is_featured) do nothing;

insert into public.fee_rules (category_id, is_featured, price_sdg, duration_days, note_ar)
select c.id, true, 3000, 30, 'رسوم إعلان سيارات مميز'
from public.categories c where c.slug = 'vehicles'
on conflict (category_id, is_featured) do nothing;

insert into public.fee_rules (category_id, is_featured, price_sdg, duration_days, note_ar)
select c.id, false, 800, 30, 'رسوم إعلان عقارات عادي'
from public.categories c where c.slug = 'real-estate'
on conflict (category_id, is_featured) do nothing;

insert into public.fee_rules (category_id, is_featured, price_sdg, duration_days, note_ar)
select c.id, true, 2500, 30, 'رسوم إعلان عقارات مميز'
from public.categories c where c.slug = 'real-estate'
on conflict (category_id, is_featured) do nothing;
