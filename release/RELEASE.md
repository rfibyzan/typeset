# Typeset release guide

How to ship an update so installed apps offer it automatically.

## One-time setup

1. Create the GitHub repo `rfibyzan/typeset` and push this folder.
2. Make sure `update.json` exists at the repo root on the `main` branch.
   The app checks `https://raw.githubusercontent.com/rfibyzan/typeset/main/update.json`
   about 3 seconds after its window loads. Offline or failed check = silent, no nag.

## Publishing a new version (example: 1.0.1)

1. In `doc-formatter.ahk`, bump `APP_VERSION := "1.0.0"` to `"1.0.1"`.
2. Compile 64-bit:
   `Ahk2Exe.exe /in doc-formatter.ahk /out Typeset.exe /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"`
3. Rebuild the package folder `release\Typeset-1.0.1\` with:
   `Typeset.exe`, `WebView2Loader.dll`, `64bit\WebView2Loader.dll`, `ui\`
   (never ship `typeset.ini`; it holds user settings and is created on first run).
4. Zip it as `Typeset-1.0.1.zip` and note the exact byte size.
5. On GitHub, create release `v1.0.1` and upload the zip.
6. Update `update.json` on `main`:
   `{ "version": "1.0.1", "url": ".../releases/download/v1.0.1/Typeset-1.0.1.zip",
      "notes": "Short English release notes.", "size": <exact bytes> }`

## What the app does

- Settings tab shows a red `Update Available` card; other tabs only get a red dot
  on the Settings rail icon.
- `Update` downloads the zip with `curl.exe` in the background (app stays usable,
  Cancel available). `Later` hides it for this session only.
- When the download is complete the app closes itself, a helper replaces every
  file except `*.ini`, relaunches, and deletes itself.
- A failed download or install returns to the card with `Update failed. Try again.`
