-- For a deployment outside the private Sites owner-verification flow:
-- 1. Create and confirm your owner in Supabase Authentication > Users.
-- 2. Make ADMIN_EMAIL match that user's verified email.
-- 3. Run this in the SQL Editor, changing the email if necessary.
-- A zero-row result means the Auth user/profile has not been created.
update public.gwppro_profiles
set role='admin'
where email=lower('owner@example.com')
returning id,email,role;
