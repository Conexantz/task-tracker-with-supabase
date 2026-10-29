# Meeting Action Tracker

A single-page tracker for actions agreed in meetings. Add an action with an owner and due date, tick it off when it's done, and see open, done and overdue counts at a glance. Data lives in Supabase and updates live for everyone who has the page open.

## How it works

- `index.html` is the whole app: plain HTML, CSS and JavaScript with no build step.
- It loads [supabase-js](https://github.com/supabase/supabase-js) 2.45.4 from jsDelivr and talks to the `meeting_actions` table using the project's publishable key.
- Realtime is enabled on the table, so ticks, additions and deletions appear on every open screen within a second or two.
- Only the "Show done actions" toggle is stored in the browser (localStorage).

## Deploy to Vercel

1. In Vercel, choose **Add New → Project** and import `Conexantz/task-tracker-with-supabase`.
2. Leave **Framework Preset** as **Other**, with no build command and no output directory.
3. Click **Deploy**.

Every push to `main` redeploys automatically.

`vercel.json` adds security headers, including a Content-Security-Policy that only allows scripts from jsDelivr, fonts from Google Fonts and network requests to this Supabase project. If you move to a different Supabase project or add another script or font source, update `connect-src`, `script-src` or `font-src` there too, or the page will be blocked from loading it.

## Supabase setup

Project: `qhvynlhlcyghrzwlrjgh` (region ap-southeast-1).

Table `public.meeting_actions`:

| Column      | Type        | Notes                                  |
|-------------|-------------|----------------------------------------|
| id          | uuid        | Primary key, `gen_random_uuid()`       |
| text        | text        | The action, 1–500 characters           |
| owner       | text        | Who owns it, 1–100 characters          |
| due         | date        | Due date                               |
| done        | boolean     | Default `false`                        |
| done_at     | timestamptz | Set when ticked                        |
| example     | boolean     | Marks sample rows; "Remove examples" deletes them |
| created_at  | timestamptz | Default `now()`                        |

Row Level Security is on, with policies that let anyone using the publishable key read, add, update and delete actions. That suits an internal tool whose URL isn't shared publicly. To restrict it to your team, add Supabase Auth and change the policies from `to anon, authenticated` to `to authenticated`.

The publishable key in `index.html` is designed to be public; access is controlled by the RLS policies, not by keeping the key secret. Never put the `service_role` or a secret key in this file.

## Run locally

Open `index.html` in a browser, or serve the folder:

```bash
npx serve .
```
