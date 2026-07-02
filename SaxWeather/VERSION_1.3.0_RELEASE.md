# Version 1.3.0

**Release Date**: June 27, 2026
**Tag**: `v1.3.0`

## Features

### iCloud Sync
- Sync active customisation profile across devices via `NSUbiquitousKeyValueStore`
- Opt-in toggle in Settings → Backup & Restore
- Last-modified-wins conflict resolution

### Aurora Cosmetic System
- Aurora Palette: tints every card with ocean-blue tones
- Aurora Chart Skin: re-skins rain probability, precipitation timeline, hourly forecast
- Aurora Backgrounds: animated weather backgrounds
- Per-card and per-chart colour schemes with Aurora override
- Live preview with 30-second countdown
- "Use this" / "Use now" buttons wire to pickers

### Cosmetic Tile Placeholders
- Kind-appropriate SF Symbol placeholders
- Per-IAP tile image slots in `Assets.xcassets/cosmetic_tile_<short_id>.imageset/`

### Settings UI
- Removed `ProfileSwitcherView` (replaced by searchable catalogue)
- macOS fixes for `SettingsView`
- Improved Backup & Restore with iCloud section

## Bug Fixes

- Preview countdown timer now counts down correctly (shared `PreviewProfileManager`)
- Aurora Palette and Chart Skin now visibly change UI when enabled
- Default app look unchanged for free users

## Removed

- Aurora Lottie cosmetic IAP
- Leaderboard feature (never shipped)

## Files

- New: `Services/iCloudSyncService.swift`
- Modified: 23 files
- Removed: `Views/Settings/ProfileSwitcherView.swift`

## Aurora Pack

3 items (Backgrounds, Palette, Chart Skin) at $9.99.

## Links

- Branch: `version/1.3.0`
- Tag: `v1.3.0`
