-- Apply after 20261022000000_initial_schema.sql.
-- Keep student identifiers and labels bounded at the database boundary too.

revoke all on table public.checkingo_students from public, anon;
revoke all on table public.checkingo_attendance from public, anon;

alter table public.checkingo_students
  drop constraint if exists checkingo_students_id_length,
  drop constraint if exists checkingo_students_name_length,
  drop constraint if exists checkingo_students_course_length,
  drop constraint if exists checkingo_students_section_length;

alter table public.checkingo_students
  add constraint checkingo_students_id_length
    check (char_length(trim(id)) between 1 and 64),
  add constraint checkingo_students_name_length
    check (char_length(trim(name)) between 1 and 120),
  add constraint checkingo_students_course_length
    check (char_length(trim(course)) between 1 and 120),
  add constraint checkingo_students_section_length
    check (char_length(trim(section)) between 1 and 80);

alter table public.checkingo_attendance
  drop constraint if exists checkingo_attendance_student_name_length,
  drop constraint if exists checkingo_attendance_section_length;

alter table public.checkingo_attendance
  add constraint checkingo_attendance_student_name_length
    check (char_length(trim(student_name)) between 1 and 120),
  add constraint checkingo_attendance_section_length
    check (char_length(trim(section)) between 1 and 80);
