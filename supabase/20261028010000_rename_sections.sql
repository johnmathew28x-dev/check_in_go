-- Allow authenticated teachers to rename their own section records.
-- Existing row-level security still restricts updates to the signed-in owner.
grant update (name) on table public.checkingo_sections to authenticated;
