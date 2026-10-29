-- CheckInGo's client uses the Supabase publishable key with Supabase Auth.
-- Row Level Security limits every query to the signed-in teacher's records.

create table if not exists public.checkingo_students (
  owner_id uuid not null references auth.users (id) on delete cascade,
  id text not null check (length(trim(id)) > 0),
  name text not null check (length(trim(name)) > 0),
  course text not null check (length(trim(course)) > 0),
  section text not null check (length(trim(section)) > 0),
  created_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.checkingo_attendance (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  student_id text not null,
  student_name text not null,
  attendance_date date not null,
  section text not null,
  status text not null check (status in ('Present', 'Absent', 'Tardy')),
  created_at timestamptz not null default now(),
  constraint checkingo_attendance_one_per_student_per_day
    unique (owner_id, attendance_date, section, student_id),
  constraint checkingo_attendance_student_fk
    foreign key (owner_id, student_id)
    references public.checkingo_students (owner_id, id)
    on update cascade
    on delete cascade
);

create index if not exists checkingo_attendance_owner_date_idx
  on public.checkingo_attendance (owner_id, attendance_date desc);

create index if not exists checkingo_attendance_owner_student_idx
  on public.checkingo_attendance (owner_id, student_id, attendance_date desc);

alter table public.checkingo_students enable row level security;
alter table public.checkingo_attendance enable row level security;

drop policy if exists "Teachers manage their own students"
  on public.checkingo_students;
create policy "Teachers manage their own students"
  on public.checkingo_students
  for all
  to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

drop policy if exists "Teachers manage their own attendance"
  on public.checkingo_attendance;
create policy "Teachers manage their own attendance"
  on public.checkingo_attendance
  for all
  to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

revoke all on public.checkingo_students from anon;
revoke all on public.checkingo_attendance from anon;
grant select, insert, update, delete
  on public.checkingo_students to authenticated;
grant select, insert, update, delete
  on public.checkingo_attendance to authenticated;
