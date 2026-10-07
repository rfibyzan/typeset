# Typeset

One-click document formatting for Microsoft Word, driven by presets.
Pick a preset, press the shortcut, and the selected text is reformatted:
font, size, style, color, spacing, alignment, and spacing before/after,
each applied only when its toggle is on.

## Features

- **Presets**: named formatting profiles, e.g. Laprak, TP, Kode, with
  per-property toggles, rename with duplicate-name guard, and delete.
- **Caption & Heading**: table/figure caption styles plus an automatic
  heading cycler (H1–H9) and Normal style reset.
- **Preset switcher popup**: `Win+Shift+F` opens a focused preset picker that closes itself when you click away.
- **Global shortcuts**: fully remappable from Settings; conflicts are
  rejected with a warning.
- **Auto-update**: checks GitHub on launch, downloads in the background
  while you keep working, then self-installs on restart without touching
  your `typeset.ini`.
- **Themes**: dark and light, per-user font list, Always-on-Top option.

## Install

1. Download the latest `Typeset-X.Y.Z.zip` from the
   [releases page](https://github.com/rfibyzan/typeset/releases).
2. Extract it anywhere and run `Typeset.exe`.
3. Select text in Word, press `Ctrl+Shift+F` to format it.

No installer, no admin rights. Settings live in `typeset.ini`
next to the exe and are preserved across updates.

## Default shortcuts

| Action          | Shortcut       |
|-----------------|----------------|
| Format Text     | Ctrl+Shift+F   |
| Select Preset   | Win+Shift+F    |
| Table Caption   | Ctrl+Shift+T   |
| Figure Caption  | Ctrl+Shift+G   |
| Heading Cycler  | Ctrl+Alt+Arrow |
| Typeset Menu    | Win+Shift+C    |

All of them can be changed in Settings.

## Updating

When a new version is published, a red `Update Available` card appears
at the top of Settings (plus a red dot on the Settings rail icon on
other tabs). Click `Update`, keep working while it downloads, and the
app restarts itself on the new version. `Later` hides it until the next
launch. `View Changelog` opens the release notes on GitHub.

## Fonts

The UI uses Geist and JetBrains Mono from `ui/fonts/` (web). The same
Geist files are bundled under `assets/fonts/` (SIL Open Font License,
see `OFL.txt`) and registered automatically to the user font store on
first run, so native notifications render in the identical typeface.
No admin rights needed and nothing is installed system-wide.

## For maintainers

- Source of truth: `doc-formatter.ahk` (AutoHotkey v2) + `ui/`.
- Bump `APP_VERSION`, compile 64-bit with Ahk2Exe, zip
  `Typeset.exe` + `WebView2Loader.dll` + `64bit/` + `ui/`,
  publish a GitHub release, then point `update.json` at it.
- See `release/RELEASE.md` for the step-by-step checklist and
  `CHANGELOG.md` for version history.
