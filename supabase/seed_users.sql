-- Starting accounts. Every user signs in with the temporary password "password"
-- and must choose their own the first time (profiles.must_change_password = true).
-- Already applied to the live project; only re-run on a fresh database.
-- To add people later, use "Manage team" in the app instead.

do $$
declare
  u record;
  uid uuid;
  addr text;
begin
  for u in
    select * from (values
      ('admin',  'Admin',  'admin'),
      ('priya',  'Priya',  'member'),
      ('dan',    'Dan',    'member'),
      ('marcus', 'Marcus', 'member')
    ) as v(username, display_name, role)
  loop
    uid  := gen_random_uuid();
    addr := u.username || '@tasktracker.example.com';

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token
    ) values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', addr,
      extensions.crypt('password', extensions.gen_salt('bf')), now(),
      jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'),
                         'username', u.username, 'display_name', u.display_name, 'role', u.role),
      jsonb_build_object('display_name', u.display_name),
      now(), now(), '', '', '', '', '', '', '', ''
    );

    insert into auth.identities (user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (uid, uid::text,
            jsonb_build_object('sub', uid::text, 'email', addr, 'email_verified', true, 'phone_verified', false),
            'email', now(), now(), now());
  end loop;
end $$;

-- Link existing actions to accounts with a matching name.
update public.meeting_actions a
set owner_id = p.id
from public.profiles p
where a.owner_id is null and lower(a.owner) = p.username;
