-- Save one class/date attendance session as a single atomic operation.
-- Run this after the existing CheckInGo migrations.

create or replace function public.checkingo_save_attendance_session(
  p_attendance_date date,
  p_section text,
  p_records jsonb,
  p_replace_session boolean default true
)
returns integer
language plpgsql
security invoker
set search_path = public, auth, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_input_count integer;
  v_unique_count integer;
  v_student_count integer;
  v_saved_count integer;
begin
  if v_owner_id is null then
    raise exception 'Sign in before saving attendance.' using errcode = '28000';
  end if;

  if p_attendance_date is null
     or p_section is null
     or char_length(trim(p_section)) not between 1 and 80 then
    raise exception 'A valid date and section are required.' using errcode = '22023';
  end if;

  if jsonb_typeof(p_records) is distinct from 'array'
     or jsonb_array_length(p_records) not between 1 and 5000 then
    raise exception 'Attendance must contain between 1 and 5000 students.' using errcode = '22023';
  end if;

  select count(*), count(distinct nullif(trim(entry.student_id), ''))
    into v_input_count, v_unique_count
  from jsonb_to_recordset(p_records)
    as entry(student_id text, student_name text, status text);

  if v_input_count <> v_unique_count then
    raise exception 'Attendance contains duplicate or empty student IDs.' using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_records)
      as entry(student_id text, student_name text, status text)
    where nullif(trim(entry.student_id), '') is null
       or char_length(trim(coalesce(entry.student_name, ''))) not between 1 and 120
       or entry.status is null
       or entry.status not in ('Present', 'Absent', 'Tardy')
  ) then
    raise exception 'Attendance contains an invalid student or status.' using errcode = '22023';
  end if;

  if p_replace_session then
    select count(*) into v_student_count
    from public.checkingo_students
    where owner_id = v_owner_id and section = p_section;

    if v_student_count <> v_input_count then
      raise exception 'The submitted attendance must include every student in the selected section.' using errcode = '22023';
    end if;
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_records)
      as entry(student_id text, student_name text, status text)
    left join public.checkingo_students as student
      on student.owner_id = v_owner_id
     and student.id = trim(entry.student_id)
     and (not p_replace_session or student.section = p_section)
    where student.id is null
  ) then
    raise exception 'Attendance includes a student outside your roster or selected section.' using errcode = '22023';
  end if;

  if p_replace_session then
    delete from public.checkingo_attendance
    where owner_id = v_owner_id
      and attendance_date = p_attendance_date
      and section = p_section;
  end if;

  insert into public.checkingo_attendance (
    owner_id, student_id, student_name, attendance_date, section, status
  )
  select
    v_owner_id,
    trim(entry.student_id),
    trim(entry.student_name),
    p_attendance_date,
    trim(p_section),
    entry.status
  from jsonb_to_recordset(p_records)
    as entry(student_id text, student_name text, status text)
  on conflict (owner_id, attendance_date, section, student_id)
  do update set
    student_name = excluded.student_name,
    status = excluded.status;

  get diagnostics v_saved_count = row_count;
  return v_saved_count;
end;
$$;

revoke all on function public.checkingo_save_attendance_session(date, text, jsonb, boolean)
  from public, anon;
grant execute on function public.checkingo_save_attendance_session(date, text, jsonb, boolean)
  to authenticated;
