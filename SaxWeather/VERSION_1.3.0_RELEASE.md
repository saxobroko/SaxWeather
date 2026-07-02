# 🎉 Version 1.3.0 - Released

**Release Date**: June 27, 2026
**Tag**: `v1.3.0`
**Branch**: `version/1.3.0`

---

## 🌟 Major Features

### 1. iCloud Sync for Customisation Profiles ☁️
- ✅ Mirror your active customisation profile across every device signed in to the same iCloud account
- ✅ Uses `NSUbiquitousKeyValueStore` — Apple's purpose-built key-value store for small, frequently-read preferences
- ✅ Last-modified-wins conflict resolution
- ✅ Opt-in toggle in Settings → Backup & Restore
- ✅ Status indicator showing sync state (enabled / disabled / unavailable)
- ✅ Force-pull from iCloud button
- ✅ Delete remote copy button
- ✅ Automatic push on every profile mutation
- ✅ Automatic pull on launch and on external-change notifications

### 2. Aurora Cosmetic System 🎨
- ✅ **Aurora Palette** — a new colour palette that tints every card on the home screen with ocean-blue tones
- ✅ **Aurora Chart Skin** — re-skins the rain probability chart, precipitation timeline, and hourly forecast pill strip with Aurora gradients
- ✅ **Aurora Backgrounds** — animated weather backgrounds with Aurora styling
- ✅ Per-card colour schemes with Aurora override (temperature, precipitation, wind, sunrise, UV, air quality, pollen, hourly, daily, alerts, hero, details)
- ✅ Per-chart colour schemes with Aurora override (rain probability, precipitation timeline, hourly forecast)
- ✅ Live preview coordinator with 30-second countdown overlay
- ✅ "Use this" / "Use now" buttons wire to the pickers
- ✅ Palette picker and chart skin picker in Settings → Appearance → Cosmetic Colours

### 3. Cosmetic Tile Placeholders 🖼️
- ✅ Kind-appropriate SF Symbol placeholders for every cosmetic kind
- ✅ Distinct gradient stops so users can tell kinds apart at a glance
- ✅ Per-IAP tile image slots — drop a JPEG/PNG into `Assets.xcassets/cosmetic_tile_<short_id>.imageset/` for a custom preview image
- ✅ 26 empty imageset directories created (one per catalog product)

### 4. Settings UI Rebuild ⚙️
- ✅ Removed `ProfileSwitcherView` — replaced by the searchable catalogue
- ✅ macOS-specific fixes for `SettingsView` (listStyle, WeatherSources)
- ✅ Improved Backup & Restore screen with dedicated iCloud section
- ✅ AppKit support in `StyledCard` for macOS compatibility

---

## 🐛 Bug Fixes

### Preview Countdown Timer
- **v4**: Promoted `PreviewProfileManager` to a shared `@StateObject` owned by `SaxWeatherApp` and injected via `.environmentObject(...)`. Every view that participates in the preview flow now observes the *same* instance, removing the `nil`-fallback footgun.
- **v3**: Moved the timer to `.common` mode and ensured the shared manager is passed through the view hierarchy. Added the missing `.onReceive` listener in `ContentView`.
- **v2**: Made `remainingSeconds` a `@Published` property driven by a `Timer.scheduledTimer`. The overlay now observes the manager via `@ObservedObject` so it re-renders on every change.

### Aurora Visibility
- **Aurora Palette now visibly changes the UI when enabled** — was a silent no-op due to non-reactive `ColourToken`. Now wrapped in a new `ColourTokenStore` that observes `CustomisationRegistry` and notifies views when the palette changes.
- **Aurora Chart Skin now visibly re-skins charts when enabled** — was a silent no-op due to non-reactive `ChartPalette`. Now wrapped in a new `ChartPaletteStore` that observes both `CustomisationRegistry` and `StoreManager`.
- **Aurora Palette preview is now live** — the preview button now navigates the user to the main forecast view so they can see the palette applied to their real weather.
- **Aurora Chart Skin now actually re-skins the chart** — `PreviewProfileManager.applyCosmetic(_:to:)` now applies `chartSkin = .aurora` for the Aurora Chart Skin IAP (previously a no-op).

### Default Look
- **Default look of the app is now unchanged** — the Part E tint is removed from `StyledCard.swift` and only applied when the Aurora Palette is selected AND owned. The Part F defaults in `ChartColorScheme` and `CardColorScheme` now match the original hardcoded colours exactly.

---

## 🗑️ Removed

### Aurora Lottie Cosmetic
- Removed the paid Aurora Lottie IAP (`com.saxweather.cosmetic.aurora.lottie`)
- Deleted `Services/LottieSkin.swift`
- Removed the `lottieSkin` field from `IconographySpec`
- Removed the `LottieSkinOverlay` view modifier and `LottieSkinPalette` resolver
- Removed the `.lottie` case from `CosmeticKind`
- Removed the product entry from `CosmeticCatalog.allProducts`
- Removed the product entry from `configuration.storekit`
- The free bundled Lottie animations in `Lottie Animations/` are unaffected

### Leaderboard Feature
- Removed all leaderboard code, CloudKit integration, and leaderboard settings
- Deleted files: `CloudKitLeaderboardManager.swift`, `LeaderboardDebugView.swift`, `LeaderboardOptInView.swift`, `LeaderboardSettingsView.swift`, `LeaderboardView.swift`
- The leaderboard was an experiment that never shipped
- Updated the "leaderboard effect" copy in the Supporter Badge subtitle and long description

---

## 📦 What's Included in v1.3.0

### 🆕 New Files Added (1)
1. `Services/iCloudSyncService.swift` — iCloud sync for customisation profiles

### 📝 Files Modified (23)
1. `CHANGELOG.md` — Updated changelog with [1.3.0] entry
2. `project.pbxproj` — Bumped MARKETING_VERSION to 1.3.0
3. `BackgroundSettingsView.swift` — Cosmetic integration
4. `DetailedWeatherView.swift` — Cosmetic integration
5. `ForecastView.swift` — Cosmetic integration
6. `Helpers/BackgroundRefreshCoordinator.swift` — Refresh improvements
7. `Helpers/ColourToken.swift` — Reactive colour tokens
8. `Helpers/SettingsBehaviour.swift` — Settings behaviour updates
9. `Localizable.xcstrings` — New strings for cosmetics and iCloud sync
10. `OnboardingView.swift` — Updated onboarding flow
11. `SaxWeather.entitlements` — Added iCloud entitlements
12. `Services/CardColorScheme.swift` — Per-card colour schemes
13. `Services/CustomisationRegistry.swift` — iCloud sync integration
14. `SettingsView.swift` — macOS fixes, removed ProfileSwitcherView
15. `Views/ExtendedWeatherDetailViews.swift` — Cosmetic integration
16. `Views/LocationPickerView.swift` — Cosmetic integration
17. `Views/Settings/CardSettingsView.swift` — Cosmetic integration
18. `Views/Settings/ChartSkinPickerView.swift` — Chart skin picker
19. `Views/Settings/KnobSearchView.swift` — Search improvements
20. `Views/Settings/PalettePickerView.swift` — Palette picker
21. `Views/Settings/SettingsBackupAndRestoreView.swift` — iCloud section
22. `Views/Settings/ThemeEditorCard.swift` — Theme editor improvements
23. `Views/StyledCard.swift` — AppKit support, cosmetic integration

### 🗑️ Files Removed (1)
- `Views/Settings/ProfileSwitcherView.swift` — Replaced by searchable catalogue

---

## 📊 Statistics

### Code Metrics
- **Files Changed**: 25 files
- **Insertions**: 907 lines
- **Deletions**: 560 lines
- **Net Change**: +347 lines

### Aurora Pack
- **Items**: 3 (Backgrounds, Palette, Chart Skin)
- **Price**: $9.99 (save vs. buying separately: $3.99 + $1.99 + $1.99 = $7.97)

---

## 🔗 GitHub Links

### View Release
- **Branch**: https://github.com/saxobroko/SaxWeather/tree/version/1.3.0
- **Tag**: https://github.com/saxobroko/SaxWeather/releases/tag/v1.3.0

### Clone
```bash
git clone https://github.com/saxobroko/SaxWeather.git
cd SaxWeather
git checkout v1.3.0
```

---

## 🎯 What's Next

### Future Enhancements
- [ ] Radar imagery integration
- [ ] Apple Watch complications
- [ ] Additional cosmetic packs
- [ ] Custom cosmetic creation
- [ ] Weather sharing improvements