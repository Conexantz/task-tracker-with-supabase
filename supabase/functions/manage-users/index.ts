// manage-users: admin-only user management for the Meeting Action Tracker.
//
// Actions (POST JSON body):
//   { action: "create", username, display_name, password, role? }  -> creates an Auth user + profile
//   { action: "reset_password", user_id, password }                 -> sets a new initial password
//
// Callers must send their Supabase session token (supabase-js functions.invoke does this).
// The caller's profile must have role = 'admin'. Users created or reset here must choose
// their own password at next sign-in (profiles.must_change_password = true).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

// Usernames sign in as <username>@EMAIL_DOMAIN. Keep in sync with index.html.
const EMAIL_DOMAIN = "tasktracker.example.com";
const USERNAME_RE = /^[a-z0-9._-]{2,32}$/;
const MIN_PASSWORD = 8;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function serviceKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  // Projects on the new API keys expose secret keys as JSON: {"default": "sb_secret_..."}
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    return keys.default ?? Object.values(keys)[0] ?? "";
  } catch {
    return "";
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  if (!url || !key) return json({ error: "The function is missing its Supabase settings." }, 500);

  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

  // Who is calling?
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Sign in again to manage users." }, 401);
  const { data: caller, error: callerErr } = await admin.auth.getUser(token);
  if (callerErr || !caller?.user) return json({ error: "Sign in again to manage users." }, 401);

  const { data: me } = await admin.from("profiles").select("role").eq("id", caller.user.id).maybeSingle();
  if (me?.role !== "admin") return json({ error: "Only admins can manage users." }, 403);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Send a JSON body." }, 400);
  }

  const password = typeof body.password === "string" ? body.password : "";
  if (password.length < MIN_PASSWORD) {
    return json({ error: `Passwords need at least ${MIN_PASSWORD} characters.` }, 400);
  }

  try {
    if (body.action === "create") {
      const username = String(body.username ?? "").trim().toLowerCase();
      const displayName = String(body.display_name ?? "").trim() || username;
      const role = body.role === "admin" ? "admin" : "member";

      if (!USERNAME_RE.test(username)) {
        return json({ error: "Usernames use 2–32 lowercase letters, numbers, dots, dashes or underscores." }, 400);
      }
      if (displayName.length > 100) return json({ error: "Keep the display name under 100 characters." }, 400);

      const { data: taken } = await admin.from("profiles").select("id").eq("username", username).maybeSingle();
      if (taken) return json({ error: `The username "${username}" is already taken.` }, 409);

      const { data: created, error } = await admin.auth.admin.createUser({
        email: `${username}@${EMAIL_DOMAIN}`,
        password,
        email_confirm: true,
        app_metadata: { username, display_name: displayName, role },
        user_metadata: { display_name: displayName },
      });
      if (error || !created?.user) {
        const msg = error?.message ?? "Unknown error";
        const status = /already|exists|registered/i.test(msg) ? 409 : 400;
        return json({ error: status === 409 ? `The username "${username}" is already taken.` : msg }, status);
      }

      // The auth trigger normally creates the profile; upsert makes sure it exists with these values.
      const { error: profErr } = await admin.from("profiles").upsert({
        id: created.user.id,
        username,
        display_name: displayName,
        role,
        must_change_password: true,
      });
      if (profErr) {
        await admin.auth.admin.deleteUser(created.user.id);
        return json({ error: profErr.message }, 500);
      }

      return json({ user: { id: created.user.id, username, display_name: displayName, role } }, 201);
    }

    if (body.action === "reset_password") {
      const userId = String(body.user_id ?? "");
      if (!userId) return json({ error: "Choose a user to reset." }, 400);

      const { error } = await admin.auth.admin.updateUserById(userId, { password });
      if (error) return json({ error: error.message }, 400);

      await admin.from("profiles").update({ must_change_password: true }).eq("id", userId);
      return json({ ok: true });
    }

    return json({ error: "Unknown action." }, 400);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
