# Changelog

All notable changes to Typeset, newest first.
Version numbers follow the in-app `APP_VERSION`.

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
