# `web/downloads/` — Windows installer hosting

The `/download` page in the Flutter app hard-links to:

```
https://tth-manager.vercel.app/downloads/TTHManagerSetup.exe
```

When `flutter build web` runs, **everything under `web/`** is copied as-is
into `build/web/`. Drop the installer at:

```
web/downloads/TTHManagerSetup.exe
```

and it will be deployed to that exact URL by Vercel on the next push.

## Building the installer

Inno Setup script lives at the repo root: [`installer.iss`](../../installer.iss).

```
flutter build windows --release
iscc installer.iss
copy installer_output\TTHManagerSetup.exe web\downloads\TTHManagerSetup.exe
```

## Where to host the binary — tradeoffs

A Flutter Windows release build is typically **40–90 MB**. Three options:

### 1. Vercel static (drop the file at `web/downloads/TTHManagerSetup.exe`)

- **Pros**: zero new infra; URL stays on the product domain; no auth
  handshake required.
- **Cons**: counted against Vercel bandwidth quotas (Hobby: 100 GB/mo,
  Pro: 1 TB/mo); deploy size grows with every release; LFS recommended
  if the file is committed to git (`git lfs track "*.exe"`); each
  redeploy re-uploads the binary.
- **Verdict**: fine while monthly downloads × file size stay under your
  bandwidth plan. Easiest path to ship.

### 2. GitHub Releases (recommended for stable distribution)

- Tag a release `v1.0.0`, attach `TTHManagerSetup.exe` as a release asset,
  point the page at:
  ```
  https://github.com/<org>/<repo>/releases/download/v1.0.0/TTHManagerSetup.exe
  ```
- **Pros**: unlimited bandwidth on public repos; versioned history; no
  Vercel bandwidth impact; per-release download analytics free.
- **Cons**: URL leaves the product domain (cosmetic only — users still
  trust github.com); each release needs a manual tag + asset upload (or
  CI workflow).
- **Verdict**: best for production. If you want the URL to stay on the
  product domain, add a Vercel rewrite (see below).

### 3. Cloudflare R2 (best when GitHub limits become annoying)

- Create an R2 bucket, enable the public-bucket endpoint, upload via
  `wrangler r2 object put`. URL looks like:
  ```
  https://pub-<hash>.r2.dev/TTHManagerSetup.exe
  ```
- **Pros**: zero egress fees (R2's defining feature); fast CDN edge;
  bucket-level versioning; pin a custom domain for cleaner URLs.
- **Cons**: extra account to manage; needs a CI step or wrangler run on
  every release.
- **Verdict**: best long-term if downloads grow into the GB/month range
  or you ship updates frequently.

## Keeping `/downloads/TTHManagerSetup.exe` on the product domain

If you host on Releases or R2 but want the URL to stay on
`tth-manager.vercel.app`, add a rewrite in [`vercel.json`](../../vercel.json):

```jsonc
{
  "rewrites": [
    {
      "source": "/downloads/TTHManagerSetup.exe",
      "destination": "https://github.com/<org>/<repo>/releases/latest/download/TTHManagerSetup.exe"
    },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

(Order matters — the specific `/downloads/...` rule must precede the
catch-all SPA rewrite.)
