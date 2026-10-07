# Changelog

All notable changes to Typeset, newest first.
Version numbers follow the in-app `APP_VERSION`.

## [1.0.12]

### Added

- First-run onboarding: fresh installs start with no presets and a
  guided empty state instead of pre-made ones. Deleting the last
  preset returns to it.
- Preset backup: Export saves presets to a JSON file, Import merges
  one back (name clashes auto-renamed). Keep the file in a cloud
  drive to share presets between PCs, free, no account needed.

### Changed

- Formatting without any preset guides to creating one first.

## [1.0.11]

### Changed

- Native toast fades in and out over 180ms instead of popping;
  focus never leaves the active window.

## [1.0.10]

### Added

- Bundled Geist typeface auto-registers on first run (user fonts,
  no admin), so the native toast uses the exact same font as the UI.

## [1.0.9]

### Changed

- Native toast text uses semibold weight to match the app type.
- Preset switcher debug readout removed.

### Removed

- Leftover switcher instrumentation (debug footer element, keystroke
  counter, 200ms polling loop).

## [1.0.8]

### Changed

- Native toast matches the approved mockup (charcoal pill, emerald
  dot, comfortable padding) and sits snug above the taskbar on the
  active monitor instead of floating.

## [1.0.7]

### Added

- Custom font dropdown popover matching the app style, with
  type-to-filter, arrow-key navigation, Enter to pick, and Esc to
  close. Shared by the text and caption font pickers.

### Changed

- Native toast anchors to the active monitor work area with wider
  margins, so it never hugs the screen edge.

## [1.0.6]

### Added

- Frameless window with custom title bar: app logo, active preset
  badge, and working minimize and close buttons. Drag the bar to
  move the window; close returns to tray as before.

### Changed

- In-app success toasts restored for save, rename, delete, revert,
  and shortcut changes. Native toasts stay gated to closed or
  minimized windows, so the two never double up.
- Native toast dot renders with a guaranteed glyph font.

### Fixed

- Color wheel no longer shifts when the brightness percent changes;
  the label column has a fixed width.

## [1.0.5]

### Added

- Manual `Check for updates` link in the Settings footer, with
  up-to-date and failure feedback.
- Update check now busts caches and retries every 15 minutes while
  the app runs (a `Later` dismissal is still honored until restart).

### Changed

- Notifications fire only on preset switch. Settings edits
  (save, rename, delete, revert, shortcut change) are silent;
  the dirty bar clearing is the save confirmation. Errors and
  warnings still notify, as do Word formatting results and updates.
- Native toast restyled to match the app (charcoal pill with emerald
  dot, bottom-right) and only appears when the main window is closed
  or minimized; otherwise the in-app toast shows.
- Config file renamed to `typeset.ini` with one-time automatic
  migration from `doc_formatter.ini`.
- Tray hover tooltip reads `Typeset`; right-click shows the menu,
  left-click opens the window.
- Color picker top row centered so no lopsided gap remains.

## [1.0.4]

### Changed

- Color picker popup: brightness slider now docks to the right edge so
  no empty gap sits beside it, bottom padding tightened to hug the
  action buttons, and the screen-color button uses a proper droplet
  icon matching the app icon set.

## [1.0.3]

### Changed

- Tray right-click shows the menu again (Exit only); only left-click
  opens the Typeset window directly.

## [1.0.2]

### Added

- Tray icon now opens the Typeset window on left or right click.
  The tray menu keeps only `Exit`.
- `README.md` project documentation and this changelog.

### Changed

- Font picker controls restyled to match the preset dropdown
  (same chevron, padding, and border treatment).
- Settings subtexts generalized: `Typography Settings` and
  `Caption & Heading Styles`.

### Fixed

- Unsaved-changes indicator reliability: the dirty state is now
  recorded before the live preview renders, so a notification can
  never be skipped even if preview rendering throws on raw input.
  Covered by an automated check across all 17 edit paths.

## [1.0.1]

### Added

- `View Changelog` link in the Settings footer. Opens the matching
  GitHub release tag when an update is available, otherwise the
  releases page.
- App version footer in Settings (`Typeset vX.Y.Z`).

## [1.0.0]

### Added

- Initial release: preset-driven Word formatting with per-property
  toggles, caption and heading tools, preset switcher popup,
  remappable global shortcuts, themes, and GitHub-based auto-update
  with background download and self-install.
- Preset rename with case-insensitive duplicate-name guard.
- App icon (T monogram on charcoal tile with emerald accent).
