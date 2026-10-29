# Meeting Action Tracker

A single-page tracker for actions agreed in meetings. Team members sign in, add an action with an owner and due date, tick it off when it's done, and see open, done and overdue counts at a glance. Data lives in Supabase and updates live for everyone who has the page open.

## Signing in

| Username | Role   | First password |
|----------|--------|----------------|
| admin    | Admin  | `password`     |
| priya    | Member | `password`     |
| dan      | Member | `password`     |
| marcus   | Member | `password`     |

Everyone must choose their own password the first time they sign in. The app won't show the tracker until they do.

Usernames map to Supabase Auth accounts as `<username>@tasktracker.example.com`. Nobody needs to know that address; the sign-in form takes the username. No emails are sent to it.

### Managing the team

Sign in as an admin and choose **Manage team** to:

- **Add a user**: username, display name, first password (defaults to `password`) and role. They choose their own password at first sign-in.
- **Reset a password**: sets a new temporary password. The person must choose their own again at next sign-in.

Every user can change their own password with **Change password**, and sign out with **Sign out**.

## How it works

- `index.html` is the whole app: plain HTML, CSS and JavaScript, no build step. It loads [supabase-js](https://github.com/supabase/supabase-js) 2.45.4 from jsDelivr.
- Passwords are stored and checked by Supabase Auth (`auth.users`). The app never sees or stores them.
- `public.profiles` holds each person's username, display name, role and whether they still need to set a password. A profile is created automatically when an account is created with a username in its app metadata.
- `public.meeting_actions` holds the actions. `owner_id` links each action to its owner's profile; `created_by` records who added it.
- Only signed-in team members (accounts with a profile) can read or change anything. Anonymous visitors and self-made sign-ups see nothing.
- The `manage-users` Edge Function adds users and resets passwords using the Auth admin API. It checks that the caller is an admin, and the service key never leaves Supabase.

## Repository layout

```
index.html                               The app
vercel.json                              Security headers for Vercel
supabase/migrations/                     Database schema, in the order applied
supabase/seed_users.sql                  The four starting accounts (already applied)
supabase/functions/manage-users/index.ts Admin user management
```

All of this is already live on project `qhvynlhlcyghrzwlrjgh` (region ap-southeast-1). The files are here so the setup can be reviewed or rebuilt.

## Deploy to Vercel

1. In Vercel, choose **Add New → Project** and import `Conexantz/task-tracker-with-supabase`.
2. Leave **Framework Preset** as **Other**, with no build command and no output directory.
3. Click **Deploy**.

Every push to `main` redeploys automatically.

`vercel.json` adds a Content-Security-Policy that only allows scripts from jsDelivr, fonts from Google Fonts and network requests to this Supabase project (database, auth, realtime and Edge Functions all use that host). If you add another script, font or API source, update the matching directive or the browser will block it.

## Recommended Supabase settings

In the Supabase dashboard under **Authentication → Sign In / Providers**:

- Turn off **Allow new users to sign up**. Self sign-ups already get no access, but this stops stray accounts being created.
- Turn on **Leaked password protection** so people can't choose passwords that appear in known breaches.

## Deploying the Edge Function again

If you change `supabase/functions/manage-users/index.ts`:

```bash
supabase functions deploy manage-users --project-ref qhvynlhlcyghrzwlrjgh --no-verify-jwt
```

The function verifies the caller's session itself, so gateway JWT checking is off.

## Run locally

Open `index.html` in a browser, or serve the folder:

```bash
npx serve .
```
