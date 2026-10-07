# Breakdown Desk — start here

This is a standalone, installable PWA for Vercel or GitHub Pages. It has no ChatGPT hosting or ChatGPT sign-in dependency.

Your three tabs are included: current breakdown status (default), report breakdown, and breakdown analysis. It saves machines and reasons for reuse, allows one active report per machine, and lets authorized staff close reports with their actual end time. Analysis includes date filters, department/machine/category summaries, and CSV export. Shared status refreshes every 30 seconds.

## Open it immediately

Double-click the top-level `index.html` after extracting the ZIP. It now includes its own JavaScript and styles and works without a development server. Click **Preview the app on this device** to try reporting, closing, and analysis. Preview records stay on that browser; they are separate from shared production records.

For real shared use, complete the Supabase setup and deploy over HTTPS. The PWA cannot be installed from a local file. Edit top-level `config.js` for this local entry; edit `public/config.js` for source builds and `ready-to-upload/config.js` for ready-built deployments.

## What is inside

- `ready-to-upload/`: already built website, no build tools needed to publish.
- `src/`: editable React source.
- `public/config.js`: configuration used by source builds.
- `database/setup.sql`: database tables, permissions and server-side operations.
- `vercel.json`: Vercel settings.

**Hosting files alone does not create the shared database.** Set up Supabase once as described below. Every device then connects to the same records using ordinary email/password accounts.

## 1. Connect the database

1. Create a project at https://supabase.com. Keep its database password private.
2. Open **SQL Editor**. Copy all of `database/setup.sql` and run it once in a new project. Do not run it repeatedly or in a database already containing these tables.
3. Open **Authentication → Users → Add user → Create new user**. Create your own email/password account. Enable automatic email confirmation when offered.
4. Return to SQL Editor and run this, replacing the example with the exact email you created:

```sql
INSERT INTO desk_private.staff(user_id,email,role)
SELECT id,lower(email),'admin'
FROM auth.users
WHERE lower(email)='your-email@example.com'
ON CONFLICT(user_id) DO UPDATE SET role='admin';
```

5. Check that this affected one row. Zero rows means the email did not match an account.
6. In Supabase project settings, copy your **Project URL** and **public publishable key** (or legacy `anon` public key). Paste them into both `public/config.js` and `ready-to-upload/config.js`:

```js
window.BREAKDOWN_CONFIG = {
  supabaseUrl: "https://YOUR-PROJECT.supabase.co",
  supabaseKey: "YOUR-PUBLIC-PUBLISHABLE-OR-ANON-KEY"
};
```

Only use a public key here. Never put a secret key, `service_role` key, database password or user password into these files or GitHub. Functions check the signed-in user's assigned role on every operation. Tables are in a private schema with row-level security; anonymous users cannot run the app's data functions.

7. For an internal plant app, disable public sign-ups in Supabase Authentication settings. Create staff accounts through its dashboard.

## 2A. Vercel deployment using GitHub

1. Create a GitHub repository.
2. Extract the ZIP and upload the **contents** of `breakdown-pwa` to the repository root. `package.json`, `index.html`, and `vercel.json` should be directly at the root, alongside `src/` and `public/`.
3. In Vercel, select **Add New → Project** and import the repository.
4. Choose **Vite**, build command `npm run build`, output folder `dist`, and Node.js 22 or newer. `vercel.json` also supplies the build settings.
5. Deploy, open its HTTPS URL, and sign in with your new account.

Update `public/config.js` in GitHub and redeploy to change the database configuration. Vercel builds from source; it does not use `ready-to-upload/`.

## 2B. GitHub Pages deployment without building

1. Create a repository for the published app.
2. Upload everything **inside `ready-to-upload/`** directly to the repository root. Keep `index.html`, `config.js`, `assets/`, `icons/`, `manifest.webmanifest`, `sw.js`, and `offline.html` together. Do not upload only index.html.
3. Ensure this root `config.js` contains your Supabase URL and public key.
4. Go to repository **Settings → Pages**. Select **Deploy from a branch**, branch `main`, folder `/(root)`, and save.
5. Open the HTTPS URL provided by GitHub Pages after deployment finishes.

Relative asset paths support `https://your-name.github.io/your-repository/`. GitHub stores code; GitHub Pages serves the app. Private repository/Pages availability depends on your GitHub plan. Breakdown records are stored in Supabase, not GitHub commits.

## 3. Add staff

1. Create staff accounts in Supabase **Authentication → Users → Add user → Create new user**. Use their real emails and give them credentials securely.
2. Sign in to the app as an administrator and click the gear icon.
3. Enter each account email and choose a role:
   - **Reporter:** view status, report faults and view/export analysis.
   - **Authorized staff:** the above plus closing breakdowns.
   - **Administrator:** the above plus managing staff access.
4. Staff can sign in on their devices using the same app URL.

You cannot change your own role in the app. Use another administrator to change it. Password resets are managed through Supabase Authentication's account controls.

## 4. Install the PWA

- Android/Chrome: browser menu → **Install app** or **Add to Home screen**.
- iPhone/Safari: **Share → Add to Home Screen**.
- Desktop Chrome/Edge: browser menu or address bar install button.

HTTPS is needed for installation and service workers. The top-level index.html opens locally for preview; installation requires the deployed HTTPS app.

## Offline and time calculations

After loading online, the app can show the latest saved current breakdown status offline, clearly marked as an outdated snapshot. Reporting and closing require a connection. Signing out clears the session and snapshot on that browser.

Times follow the device timezone. Set plant devices to Sri Lanka time for consistent display. Analysis clips downtime to selected dates. Totals sum downtime across machines, so they can exceed elapsed calendar time.

## Optional: edit and rebuild

Install Node.js 22 or newer, then run these in the extracted project folder:

```sh
npm install
npm run dev
```

To rebuild:

```sh
npm run build
```

Publish the contents of `dist/`. Replace `ready-to-upload` with that output after source changes. Increase the cache version in `public/sw.js` when changing service worker behavior.

## Verification and first test

The source was type-checked and built. Assets, PWA paths, and database request wiring were checked. The SQL is supplied for your own Supabase project; no live database or staff accounts have been created for you. End-to-end multi-device operation and phone installation must be checked after connecting your database.

First test: report ATM 36 under Milling department. Confirm it appears on another device. Close it as authorized staff and check its duration in analysis. Try closing a breakdown as a reporter to confirm that the database refuses it.

Official documentation: https://supabase.com/docs/guides/auth and https://supabase.com/docs/guides/database/postgres/row-level-security
