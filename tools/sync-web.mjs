/**
 * DataLens — web build step.
 *
 * Capacitor needs a single self-contained directory to bundle into the
 * APK. DataLens has no bundler: the app IS the static files. This script
 * assembles them into ./www, which is Capacitor's webDir.
 *
 * Run:  npm run build     (or npx cap copy, which calls this first)
 */

import { mkdir, rm, copyFile, readdir, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const OUT = path.join(ROOT, "www");

/* Files copied verbatim into the bundle. */
const FILES = [
  "index.html",
  "offline.html",
  "sw.js",
  "manifest.json",
  "config.js",
  ".nojekyll"
];

/* Directories copied recursively. */
const DIRS = ["icons"];

async function copyDir(src, dest) {
  await mkdir(dest, { recursive: true });
  for (const entry of await readdir(src)) {
    const s = path.join(src, entry);
    const d = path.join(dest, entry);
    const info = await stat(s);
    if (info.isDirectory()) await copyDir(s, d);
    else await copyFile(s, d);
  }
}

async function main() {
  await rm(OUT, { recursive: true, force: true });
  await mkdir(OUT, { recursive: true });

  let copied = 0;
  const missing = [];

  for (const f of FILES) {
    const src = path.join(ROOT, f);
    if (!existsSync(src)) { missing.push(f); continue; }
    await copyFile(src, path.join(OUT, f));
    copied++;
  }

  for (const d of DIRS) {
    const src = path.join(ROOT, d);
    if (!existsSync(src)) { missing.push(`${d}/`); continue; }
    await copyDir(src, path.join(OUT, d));
    copied++;
  }

  console.log(`web build -> ${path.relative(ROOT, OUT)}/  (${copied} entries)`);

  if (missing.length) {
    console.log(`  WARNING missing: ${missing.join(", ")}`);
  }

  // The service worker is meaningless inside an APK - the WebView loads
  // from disk and never goes offline in the way a browser tab does. Left
  // in place deliberately so the same www/ folder also serves as a PWA.
  const swSize = existsSync(path.join(OUT, "sw.js"))
    ? (await stat(path.join(OUT, "sw.js"))).size
    : 0;
  console.log(`  sw.js ${(swSize / 1024).toFixed(1)} KB (inactive inside the APK)`);
}

main().catch((err) => {
  console.error("web build failed:", err.message);
  process.exit(1);
});