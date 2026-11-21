-- Remote App Version Control for In-App Soft & Force Updates (iOS / Android)
-- Mirror of thai-quran-web/supabase/migrations/20261117000000_app_version_config.sql

create schema if not exists private;

create table if not exists public.app_version_config (
  id text primary key,
  platform text not null check (platform in ('android', 'ios')),
  min_version text not null default '1.0.0',
  min_build_number integer not null default 1,
  latest_version text not null default '1.0.3',
  latest_build_number integer not null default 11,
  is_force_update boolean not null default false,
  update_url text not null,
  title_th text not null default 'มีเวอร์ชันใหม่พร้อมใช้งาน',
  title_en text not null default 'Update Available',
  message_th text not null default 'กรุณาอัปเดตแอปพลิเคชัน Thai Quran เป็นเวอร์ชันล่าสุดเพื่อฟีเจอร์ใหม่และการทำงานที่สมบูรณ์',
  message_en text not null default 'Please update Thai Quran to the latest version for new features and improvements.',
  release_notes_th text,
  release_notes_en text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.app_version_config enable row level security;

grant select on table public.app_version_config to anon, authenticated;

drop policy if exists "app_version_config_public_read" on public.app_version_config;
create policy "app_version_config_public_read"
  on public.app_version_config
  for select
  to anon, authenticated
  using (is_active = true);

drop policy if exists "app_version_config_super_user_insert" on public.app_version_config;
create policy "app_version_config_super_user_insert"
  on public.app_version_config
  for insert
  to authenticated
  with check (private.is_super_user((select auth.uid())));

drop policy if exists "app_version_config_super_user_update" on public.app_version_config;
create policy "app_version_config_super_user_update"
  on public.app_version_config
  for update
  to authenticated
  using (private.is_super_user((select auth.uid())))
  with check (private.is_super_user((select auth.uid())));

drop policy if exists "app_version_config_super_user_delete" on public.app_version_config;
create policy "app_version_config_super_user_delete"
  on public.app_version_config
  for delete
  to authenticated
  using (private.is_super_user((select auth.uid())));

insert into public.app_version_config (
  id,
  platform,
  min_version,
  min_build_number,
  latest_version,
  latest_build_number,
  is_force_update,
  update_url,
  title_th,
  title_en,
  message_th,
  message_en,
  release_notes_th,
  release_notes_en,
  is_active
)
values
  (
    'android',
    'android',
    '1.0.0',
    1,
    '1.0.3',
    11,
    false,
    'https://play.google.com/store/apps/details?id=com.thaiquran.app',
    'มีเวอร์ชันใหม่พร้อมใช้งาน',
    'Update Available',
    'กรุณาอัปเดตแอปพลิเคชัน Thai Quran เป็นเวอร์ชันล่าสุดเพื่อฟีเจอร์ใหม่และการทำงานที่สมบูรณ์',
    'Please update Thai Quran to the latest version for new features and improvements.',
    E'• เพิ่มระบบแจ้งเตือนอัปเดตเวอร์ชันใหม่ภายในแอป\n• เพิ่มปุ่ม Hint-to-Skip ในโหมดท่องจำอัลกุรอาน\n• ปรับปรุงการรู้จำเสียงท่องจำให้แม่นยำยิ่งขึ้น\n• รวมคำแปลทั้ง 7 เล่มแบบออฟไลน์',
    E'• Added in-app update notification system\n• Added Hint-to-Skip button in Hifz mode\n• Improved voice recitation matching\n• All 7 translations bundled offline',
    true
  ),
  (
    'ios',
    'ios',
    '1.0.0',
    1,
    '1.0.3',
    11,
    false,
    -- Replace with your App Store URL (https://apps.apple.com/app/id<APP_ID>) or TestFlight invite URL
    'https://quran-th.com',
    'มีเวอร์ชันใหม่พร้อมใช้งาน',
    'Update Available',
    'กรุณาอัปเดตแอปพลิเคชัน Thai Quran เป็นเวอร์ชันล่าสุดเพื่อฟีเจอร์ใหม่และการทำงานที่สมบูรณ์',
    'Please update Thai Quran to the latest version for new features and improvements.',
    E'• เพิ่มระบบแจ้งเตือนอัปเดตเวอร์ชันใหม่ภายในแอป\n• เพิ่มปุ่ม Hint-to-Skip ในโหมดท่องจำอัลกุรอาน\n• ปรับปรุงการรู้จำเสียงท่องจำให้แม่นยำยิ่งขึ้น\n• รวมคำแปลทั้ง 7 เล่มแบบออฟไลน์',
    E'• Added in-app update notification system\n• Added Hint-to-Skip button in Hifz mode\n• Improved voice recitation matching\n• All 7 translations bundled offline',
    true
  )
on conflict (id) do update set
  min_version = excluded.min_version,
  min_build_number = excluded.min_build_number,
  latest_version = excluded.latest_version,
  latest_build_number = excluded.latest_build_number,
  is_force_update = excluded.is_force_update,
  update_url = excluded.update_url,
  title_th = excluded.title_th,
  title_en = excluded.title_en,
  message_th = excluded.message_th,
  message_en = excluded.message_en,
  release_notes_th = excluded.release_notes_th,
  release_notes_en = excluded.release_notes_en,
  is_active = excluded.is_active,
  updated_at = now();
