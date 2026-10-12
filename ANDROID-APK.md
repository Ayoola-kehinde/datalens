# DataLens — Android APK

Signed release APKs, built with Capacitor. The web app is bundled **inside** the APK,
so there is no browser, no web server, and no domain verification involved.

---

## Build it

```powershell
.\tools\build-apk.ps1
```

That's the whole thing. It checks the toolchain, assembles the web assets, copies them
into the Android project, runs Gradle, publishes to `dist\`, and verifies the result.

| Variant | Command | Signed with |
|---|---|---|
| **Release** (default) | `.\tools\build-apk.ps1` | your release keystore |
| Debug | `.\tools\build-apk.ps1 -Debug` | auto-generated Android debug key |
| Skip web rebuild | `.\tools\build-apk.ps1 -SkipWebBuild` | — |

Output lands in `dist\DataLens-release-v1.0.apk` with a SHA-256 checksum printed.

### Install

```powershell
adb install -r dist\DataLens-release-v1.0.apk
```

Or copy the file to the phone and tap it. Android will ask you to allow installation from
your file manager the first time — normal for any APK that isn't from the Play Store.

**Requires Android 7.0 (API 24) or newer.**

---

## Toolchain

Everything is installed per-user. No administrator rights needed after initial setup.

| Tool | Version | Script | Manual |
|---|---|---|---|
| Node.js | 22 LTS | — | `winget install OpenJS.NodeJS.LTS` |
| JDK | **21** | `tools\setup-java.ps1` | `winget install Microsoft.OpenJDK.21` |
| Android SDK | platform 36 | `tools\setup-android-sdk.ps1` | — |
| Release key | 4096-bit RSA, 30y | `tools\setup-release-key.ps1` | — |

> **JDK 21 is required, not 17.** Capacitor 8 compiles against Java 21. A JDK 17 build
> fails with `error: invalid source release: 21`. This is the single most common
> build failure on this project.

---

## Signing

```
android/keystore/datalens-release.jks      the private key   (gitignored)
android/keystore.properties                the password      (gitignored)
android/keystore.properties.example        template          (committed)
```

The key is 4096-bit RSA, SHA256withRSA, valid 30 years, alias `datalens`.

### ⚠️ Back up the .jks

Android requires every future version of an installed app to be signed with the **identical
key**. Lose `datalens-release.jks` and you cannot update any copy already on a device — you'd
have to change `applicationId` and ship as an entirely new app.

Copy it somewhere private and permanent. The password is in `keystore.properties` next to it.

### Builds without the key

`build.gradle` reads `keystore.properties` if it exists and otherwise **falls back to the
debug signer** rather than failing. A fresh clone with no key still produces an installable
APK — it just isn't the real signing identity, and can't replace a properly signed install.

---

## What works on Android

Everything. All seven views are live in the APK:

| Feature | Status |
|---|---|
| Snapshot (six pillars, evidence, citations) | ✅ |
| Ask (conversational analysis) | ✅ with internet |
| Signals (risk detection) | ✅ |
| Peers (comparison, percentiles) | ✅ |
| What Changed (diff) | ✅ |
| My Thesis (edits + watchlist) | ✅ persists on device |
| Reports (extraction simulation) | ✅ |
| Evidence drawer, concept explainer | ✅ |
| Dark / light theme | ✅ |
| Offline | ✅ bundled sample data |

## What differs from the web

| | Web (PWA) | Android APK |
|---|---|---|
| **Service worker** | Active — caches the shell for offline | **Inert.** The WebView loads assets from the APK's filesystem, so there's nothing to cache and nothing to go stale |
| **Data source** | Supabase when configured | Same. Needs internet |
| **Offline data** | Cached pages | Bundled sample data always available |
| **Install** | "Add to Home screen" | Normal app install |
| **Updates** | Silent, on next load | New APK install |

### Requires an internet connection

- **Live Supabase data** — companies, extractions, thesis sync. Without it the app falls
  back to bundled sample data and says so in the sidebar ("Sample data" / "local only").
- **Ask** — answers are computed locally from the loaded data, but retrieving fresh
  company data needs the network.
- **Automated review** — calls the Supabase Edge Function. Also the only path to Groq and
  Slack; both secrets live server-side and are unreachable from the device.

### Not implemented

- **No camera or file upload.** Capacitor's camera/filesystem plugins aren't installed.
  The Reports view runs its simulated extraction pipeline.
- **No push notifications.**
- **No biometric lock.**
- **`background_color` is `#ffffff` per the manifest spec**, so the splash shows white
  before the dark app loads. Cosmetic; change it in `manifest.json` and
  `capacitor.config.json` if the flash bothers you.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `invalid source release: 21` | JDK 17 active | `tools\setup-java.ps1` — points at 21 |
| `SDK location not found` | No `android/local.properties` | `tools\setup-android-sdk.ps1` |
| `Package platforms not found` | Semicolon in the package ID split by the `.bat` wrapper | Use `--package_file=` (the script already does) |
| Signature mismatch on install | An APK signed with a different key is installed | Uninstall the old copy first |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Same as above | `adb uninstall com.datalens.app`, then install |
| Play Protect blocks the APK | Unsideloaded app | Expected. "More details → Install anyway" |
| Large download stalls | Flaky connection to `dl.google.com` | `tools\fetch-cmdline-tools.ps1` resumes rather than restarts |

---

*DataLens runs illustrative sample data for a Nigerian market context. Not investment
advice. Figures are not real reported results.*