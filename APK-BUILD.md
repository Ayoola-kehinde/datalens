# Building the DataLens Android APK

Two routes. **Route A needs nothing installed** and gets you a working APK today.
Route B is for later, when you want a signing key you control.

| | **Route A — PWA Builder** | **Route B — Bubblewrap** |
|---|---|---|
| Needs | A browser | Node, JDK, Android SDK |
| Setup time | ~5 minutes | ~40 minutes |
| Signing key | Google's debug key (yours to keep) | Your own keystore |
| Play Store | ❌ not accepted | ✅ ready |
| Good for | **Getting 2–3 testers onto it now** | Anything public-facing |

**Do Route A.** Route B only matters if you want the Play Store, and that's
nowhere near the next milestone.

---

## Before either route: put the app on the web

A PWA can only install from a secure origin, and the APK's WebView needs a real
HTTPS URL. Both routes require the site to be **deployed and publicly reachable**.

### Deploy to GitHub Pages (free, ~2 minutes, no build step)

DataLens is plain static files, so Pages can host it directly from your repo —
no Node, no bundler, no build pipeline.

1. Go to <https://github.com/Ayoola-kehinde/datalens/settings/pages>
2. Under **Build and deployment**:
   - **Source**: `Deploy from a branch`
   - **Branch**: `main`
   - **Folder**: `/ (root)`
3. Save. Wait ~60 seconds.

Your app is now at:

```
https://ayoola-kehinde.github.io/datalens/
```

> `.nojekyll` is already committed, which stops Pages from hiding
> `.well-known/assetlinks.json`. Without it, the APK shows a browser-bar warning.

**Verify it worked:** open that URL on your phone. If you see DataLens, you're ready.

---

## Route A — PWA Builder (recommended)

Google's own tool. It builds the APK in a browser tab on Google's servers, so
you need no Android tooling at all.

### Step 1 — feed it your URL

Go to **<https://www.pwabuilder.com>** and enter:

```
https://ayoola-kehinde.github.io/datalens/
```

Click **Start**. It fetches and validates your manifest. You should see your
name, icons, colours and standalone display mode all recognised.

If anything looks wrong, stop here — fix `manifest.webmanifest` and push again
before continuing.

### Step 2 — check the service worker

The **Service Worker** tab should report one detected. If it says "none found",
the deployed `sw.js` isn't reachable. Confirm it loads:

```
https://ayoola-kehinde.github.io/datalens/sw.js
```

### Step 3 — build the APK

1. Click **Package for stores** (top nav)
2. Choose **Android**
3. Select the default options
4. Click **Download APK**

You'll get a `.zip` containing a signed `.apk`.

### Step 4 — publish the fingerprint

This is the step people miss, and skipping it means the APK opens with a
"Open in browser" bar instead of launching standalone.

PWA Builder displays an `assetlinks.json` block on the confirmation screen,
containing a `sha256_cert_fingerprints` value. Copy that file over ours:

```powershell
# 1. Open the file PWA Builder gave you
notepad ".\.well-known\assetlinks.json"

#    Replace REPLACE_WITH_YOUR_SIGNING_CERT_SHA256 with the fingerprint
#    PWA Builder showed you. Keep everything else exactly as-is.
```

Then push it:

```powershell
git add ".well-known/assetlinks.json"
git commit -m "Add signing cert fingerprint for TWA verification"
git push
```

Wait ~60s for Pages to redeploy. **The fingerprint only matches the APK PWA
Builder just generated.** Generate a new APK later and you must re-copy it.

### Step 5 — get the APK onto your testers' phones

Extract `app-release.apk` from the downloaded zip.

**Simplest — direct link.** Commit the APK and share the URL:

```powershell
git add "*.apk"
git commit -m "Add test APK"
git push
```

Testers download from
`https://ayoola-kehinde.github.io/datalens/app-release.apk`
then enable **Settings → Apps → Special access → Install unknown apps** for
their browser. Warning screens are expected.

**Better UX — Firebase App Distribution (free).** Testers get an install link
in their browser with no "unknown source" warning, which matters a lot when the
people testing are not technical:

```powershell
npm install -g firebase-tools
firebase login
firebase projects:create "datalens" --free
cd app-release-folder
firebase appdistribution:distribute app-release.apk \
  --project YOUR_PROJECT_ID \
  --message "DataLens alpha 1 — internal test"
```

Testers receive an email and install from a link.

---

## Route B — Bubblewrap (later, when you need the Play Store)

Use this when you want a signing key you control, or Play Store release.

### Install the toolchain

```powershell
winget install OpenJS.NodeJS.LTS --source winget
winget install EclipseAdoptium.Temurin.17.JDK
# Then Android Studio (bundles the SDK): https://developer.android.com/studio
```

New terminal, then verify:

```powershell
node --version
java -version
```

### Generate the project

```powershell
npm install -g @bubblewrap/cli

bubblewrap init \
  --manifest https://ayoola-kehinde.github.io/datalens/manifest.webmanifest
```

It prints the exact `assetlinks.json` your APK needs. Paste that fingerprint into
`.well-known/assetlinks.json` in the repo and push — **before** you build, or the
app will launch with a browser bar.

Then:

```powershell
bubblewrap build            # debug APK, uses the local debug keystore
bubblewrap build --release  # release APK, uses your own key
```

### Your own signing key

```powershell
keytool -genkey -v -keystore datalens-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias datalens
```

> **Back up `datalens-release.jks` and its password somewhere safe and private.**
> Lose it and you can never update the app on the Play Store — you'd have to
> publish under a new listing. Never commit it.

Get its fingerprint for `assetlinks.json`:

```powershell
keytool -list -v -keystore datalens-release.jks -alias datalens
```

Find the `SHA256:` line under **Certificate fingerprints**.

---

## Install it without deploying at all (quick sanity check)

You can test the whole PWA on your own machine before deploying anything.
Service workers run on `localhost`, so this works with no HTTPS and no GitHub:

```powershell
powershell -ExecutionPolicy Bypass -File tools\serve.ps1
```

Then open **<http://localhost:8080>** in Chrome and press F12 → **Application** →
**Manifest**. You should see your name, icons and colours recognised, and a
green installability check.

This is the fastest way to confirm the PWA layer is correct before you touch
Pages or the APK at all.

> Note: this does **not** work from your phone's browser over the local network
> (`http://192.168.x.x:8080`). Chrome only grants service workers to secure
> origins, and a plain-HTTP LAN address isn't one. Android testers need the
> deployed HTTPS URL.

---

## What testers will and won't see in the APK

**Works:** all 7 views, company switching, chat, evidence drawer, thesis with
`localStorage` persistence, offline mode, theme toggle, icon and splash screen.

**Won't work yet:** no accounts, no backend. There is no Supabase, Groq or Slack
integration in this build — the app runs entirely on bundled sample data for
four companies. Your thesis and settings persist in device storage, so they
survive restarts but do **not** sync between testers or across devices.

That is deliberate: this build proves the app installs, launches and works on a
real Android device. The backend arrives next.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "Install app" never appears in Chrome | Not a secure context, or service worker didn't register | Must be `https://` or `localhost`. Check F12 → Application → Service Workers |
| Install prompt missing on Android | Chrome wants an engagement signal first | Visit a few times and interact. Add a "Share → Install app" button via `beforeinstallprompt` (already wired — use the ⤓ button in the header) |
| APK opens with a browser address bar | `assetlinks.json` doesn't match the APK's cert | Re-copy the fingerprint from PWA Builder, push, wait for redeploy |
| APK shows "Open in browser" warning | Same as above | Same fix |
| Changes not appearing after re-push | Old service worker cached the shell | Bump `CACHE_VERSION` in `sw.js`, or in Chrome go to the ⤓ button and choose Unregister, then reload |
| Pages returns 404 for icons | Jekyll ate dotfolders | `.nojekyll` is committed — confirm it's in the repo |
| `Pages` option missing in settings | Repo is private or Pages is disabled for the account | Pages works on private repos on the free plan, but the setting can be org-restricted |

---

## Release checklist for testers

- [ ] Site loads over HTTPS at the GitHub Pages URL
- [ ] F12 → Application → Manifest shows no errors
- [ ] Offline mode works: DevTools → Network → Offline, reload, app still opens
- [ ] PWA Builder validates the manifest and detects the service worker
- [ ] APK downloaded and installed on a real Android device
- [ ] App launches **without** a browser address bar (fingerprint matched)
- [ ] All 7 tabs render on a phone-sized viewport
- [ ] Thesis edits survive closing and reopening the app
- [ ] Testers were told: sample data only, not investment advice

---

*DataLens is a prototype running illustrative sample data for a Nigerian market
context. It is not investment advice and the figures are not real reported
results. See `PRD.md` for scope and `README.md` for the full file guide.*