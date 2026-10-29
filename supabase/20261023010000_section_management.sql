-- Add teacher-owned section lists. Apply after the initial schema and security hardening.

create table if not exists public.checkingo_sections (
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null
    check (char_length(trim(name)) between 1 and 80),
  created_at timestamptz not null default now(),
  primary key (owner_id, name)
);

-- Preserve the existing roster and attendance section names.
insert into public.checkingo_sections (owner_id, name)
select owner_id, section from public.checkingo_students
union
select owner_id, section from public.checkingo_attendance
on conflict (owner_id, name) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'checkingo_students_section_fk'
      and conrelid = 'public.checkingo_students'::regclass
  ) then
    alter table public.checkingo_students
      add constraint checkingo_students_section_fk
      foreign key (owner_id, section)
      references public.checkingo_sections (owner_id, name)
      on update cascade on delete restrict;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'checkingo_attendance_section_fk'
      and conrelid = 'public.checkingo_attendance'::regclass
  ) then
    alter table public.checkingo_attendance
      add constraint checkingo_attendance_section_fk
      foreign key (owner_id, section)
      references public.checkingo_sections (owner_id, name)
      on update cascade on delete restrict;
  end if;
end;
$$;

alter table public.checkingo_sections enable row level security;

drop policy if exists "Teachers manage their own sections"
  on public.checkingo_sections;
create policy "Teachers manage their own sections"
  on public.checkingo_sections
  for all
  to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

revoke all on table public.checkingo_sections from public, anon;
grant select, insert, delete on table public.checkingo_sections to authenticated;
grant update (name) on table public.checkingo_sections to authenticated;
