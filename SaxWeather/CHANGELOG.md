# Changelog

All notable changes to SaxWeather will be documented in this file.

## [1.3.0] - 2026-06-27

### Added
- **Per-chart colour scheme infrastructure** (Part F): a new `ChartColorScheme` struct (`Services/ChartColorScheme.swift`) defines per-chart default colour schemes (rain probability, precipitation timeline, hourly forecast) and the Aurora override. Each chart resolves its colours via `ChartColorScheme.resolve(defaultScheme:activeSkin:)`, which returns the Aurora override when the active skin is `.aurora` and the chart's own default otherwise. The chart skin is an override on top of the default, not a replacement.
- **Per-card colour scheme infrastructure** (Part F): a new `CardColorScheme` struct (`Services/CardColorScheme.swift`) defines per-card default colour schemes (temperature, precipitation, wind, sunrise, UV index, air quality, pollen, hourly forecast, daily forecast, weather alert, hero, weather details) and the Aurora override. Each card resolves its colours via `CardColorScheme.resolve(defaultScheme:activePalette:)`, which returns the Aurora override when the active palette is `.cosmeticAurora` and the card's own default otherwise. The palette is an override on top of the default, not a replacement.
- **Rain probability chart tests** (Part F): `SaxWeatherTests/RainProbabilityChartTests.swift` covers the default-colours-when-no-skin-equipped, Aurora-colours-when-Aurora-skin-equipped, re-resolve-on-skin-change, and store-re-resolve-on-profile-change contracts for the rain probability chart on the main page.
- **Chart colour scheme tests** (Part F): `SaxWeatherTests/ChartColorSchemeTests.swift` covers the Aurora-override-is-distinct-from-default, per-chart-defaults-are-distinct, resolve-applies-Aurora-override, convenience-methods-return-resolved-scheme, and gradient-colors-returns-five-colours contracts for the `ChartColorScheme` struct.
- **Card colour scheme tests** (Part F): `SaxWeatherTests/CardColorSchemeTests.swift` covers the Aurora-override-is-distinct-from-default, per-card-defaults-are-distinct, resolve-applies-Aurora-override, and convenience-methods-return-resolved-scheme contracts for the `CardColorScheme` struct.
- **Per-IAP tile image slot** (Part C): cosmetic store cards and detail views now read optional tile images from `Assets.xcassets/cosmetic_tile_<short_id>.imageset/`. Drop a JPEG/PNG named `tile.jpg` (or update `Contents.json` for a different filename) into the imageset to give the cosmetic a custom preview image. Missing images fall back to a kind-appropriate SF Symbol placeholder (e.g. `paintbrush.pointed.fill` for backgrounds, `swatchpalette.fill` for palette, `chart.line.uptrend.xyaxis` for chart, `rosette` for badge, `sparkles` for pack, `square.stack.3d.up.fill` for bundle). 26 empty imageset directories were created (one per catalog product after the Aurora Lottie removal).
- **Live cosmetic-preview coordinator** (Part A): a new `CosmeticPreviewCoordinator` (`Services/CosmeticPreviewCoordinator.swift`) drives the "Preview on your forecast for 30s" flow. Tapping Preview now navigates the user to the most relevant live view (main weather for backgrounds/palette, forecast for chart) and shows a persistent countdown overlay (`Views/Cosmetics/PreviewCountdownOverlay.swift`) with a "Stop Preview" button. When the timer expires or the user taps Stop, the original profile is restored and the user is returned to the detail view so they can tap Buy if they liked it.
- **Cosmetic tile placeholder helper** (Part C): `Views/Cosmetics/CosmeticTilePlaceholder.swift` provides a kind-appropriate SF Symbol placeholder for every cosmetic kind, with distinct gradient stops so the user can tell the kinds apart at a glance.
- **Chart palette tests** (Part A): `SaxWeatherTests/ChartPaletteTests.swift` covers the Aurora Chart Skin owned/unowned paths and the re-evaluation contract on entitlement change.
- **Preview coordinator tests** (Part A): `SaxWeatherTests/CosmeticPreviewCoordinatorTests.swift` covers destination dispatch per cosmetic kind, restore-on-stop, restore-on-timer-expiry, and snapshot integrity.
- **Palette picker in Settings** (Phase 5): a new `Views/Settings/PalettePickerView.swift` lists every pickable palette (the free `Default` and the cosmetic `Aurora`) using the same per-row lock-and-buy pattern as `BackgroundModeRow`. Tapping a free or owned row commits the selection to `VisualSpec.palette`; tapping a locked row presents the in-app cosmetics store at the matching product's detail sheet. A new "Cosmetic Colours" section in `SettingsView` exposes the picker via a tappable `PalettePickerRow` that shows the currently active palette name as the detail text.
- **Chart skin picker in Settings** (Phase 5): a new `Views/Settings/ChartSkinPickerView.swift` lists every `ChartSkin` case (`.none` as "Default", `.aurora`) with the same lock-and-buy pattern. Tapping an owned skin commits the selection to `ForecastSpec.chartSkin`; tapping a locked skin presents the cosmetics store. A new `ChartSkinPickerRow` in the same Settings section exposes the picker with the active skin's name as the detail text.
- **"Use this" / "Use now" buttons wire to the pickers** (Phase 5): `CosmeticDetailView` now exposes a "Use this" button when the user owns a palette / chart / background cosmetic, and a "Use now" button after a successful purchase. Both buttons call `CosmeticUsageCoordinator.useNow(_:isOwned:)` which (a) applies the cosmetic to the live profile via `CustomisationRegistry.set(\.visual.palette, …)` / `set(\.forecast.chartSkin, …)` / `set(\.background.mode, …)` and (b) publishes a `pendingUsage` that `ContentView` observes to switch to the Settings tab and present the matching picker. The coordinator also accepts an `isOwned` closure and refuses to act on unowned cosmetics.
- **Palette picker tests** (Phase 5): `SaxWeatherTests/PalettePickerTests.swift` covers the selectable list, lock state for unowned / owned palettes, selection commit, locked navigation, and active display name resolution.
- **Chart skin picker tests** (Phase 5): `SaxWeatherTests/ChartSkinPickerTests.swift` covers the same contract for chart skins.

### Changed
- **Aurora Chart Skin now affects real, visible charts** (Part F): the chart skin is no longer wired to a fictional hourly forecast chart — it now affects the rain probability chart on the main page (`PrecipitationGraphView`), the precipitation timeline bar in `AlertsView`, and the hourly forecast pill strip in `HourlyForecastView`. Each chart has its own default colour scheme (blue tones for rain probability, blue intensity ramps for the precipitation timeline, cool→warm gradient for the hourly forecast); the Aurora Chart Skin is an override on top of the default, not a replacement. A new `ChartColorScheme` struct (`Services/ChartColorScheme.swift`) defines per-chart defaults and the Aurora override, with a `resolve(defaultScheme:activeSkin:)` helper that picks the right colours based on the active chart skin.
- **Aurora Palette now affects every card with per-card defaults** (Part F): the palette is no longer wired only to `.solid` / `.outline` card styles — it now affects every card on the home screen via the `.styledCard()` modifier (which already tints `.glass` cards with `palette.surface` per the Part E fix). A new `CardColorScheme` struct (`Services/CardColorScheme.swift`) defines per-card defaults (temperature = orange, precipitation = blue, wind = teal, sunrise = orange, UV = purple, air quality = green, pollen = green, etc.) and the Aurora override, with a `resolve(defaultScheme:activePalette:)` helper that picks the right colours based on the active palette. The palette is an override on top of each card's default, not a replacement.
- **Aurora Palette preview is now live** (Part A): the palette preview no longer silently mutates the profile — it applies the Aurora palette and navigates the user to the main forecast view so they can see the change. After 30 seconds (or on "Stop Preview"), the original palette is restored and the user is returned to the detail view.
- **Aurora Chart Skin now actually re-skins the chart** (Part A): `PreviewProfileManager.applyCosmetic(_:to:)` now applies `chartSkin = .aurora` for the Aurora Chart Skin IAP (previously a no-op). The hourly pill strip in `HourlyForecastView` reads the resolved palette via `ChartPalette.activeColors(_:isOwned:)`, so the Aurora gradient renders immediately when the user equips the cosmetic.
- **Preview button UX** (Part A): the "Preview" button on `CosmeticDetailView` now drives the live preview coordinator instead of mutating the profile in place. The button is hidden for cosmetic kinds with no meaningful live preview (badge, supporter pack, bundle, icons, font, haptic, sound, widget theme, app icon).
- **Mega Pack: Aurora now grants 3 items** (Part B): the bundle's subtitle was updated from "All four Aurora items" to "All three Aurora items — backgrounds, palette, and chart skin". Price stays at $9.99 (still a "save vs. buying separately" deal: $3.99 + $1.99 + $1.99 = $7.97, so the $9.99 bundle prices in a "support the app" premium of ~$2 on top of the underlying discount).
- **Aurora Pack catalog count** (Part B): the Aurora pack now ships 3 items (Backgrounds, Palette, Chart Skin) instead of 4. The Aurora Lottie IAP was removed entirely.

### Fixed
- **Preview countdown timer now actually counts down from 30 to 0** (Part C v4): the Part C v3 fix tried to thread the shared `PreviewProfileManager` through the view hierarchy as an `@ObservedObject` parameter, but `CosmeticsStoreView` is instantiated from five different call sites (`ContentView`, `SettingsView`, `ChartSkinPickerView`, `PalettePickerView`, `BackgroundSettingsView`) and four of them passed `nil` — which fell back to a fresh `PreviewProfileManager()` inside the init. The preview then ran on the throwaway instance while the overlay in `ContentView` observed the original instance, which still had `remainingSeconds == 0`, so the UI showed `Ends in 0s` immediately. The fix promotes `PreviewProfileManager` to a shared `@StateObject` owned by `SaxWeatherApp` and injected via `.environmentObject(...)`, so every view that participates in the preview flow (the countdown overlay, the store sheet, the detail sheet, and the picker sheets) observes the *same* instance. `CosmeticsStoreView` and `CosmeticDetailView` now read the manager from the environment instead of accepting it as a parameter, which removes the `nil`-fallback footgun entirely.
- **Preview countdown timer now actually counts down from 30 to 0** (Part C v3): the Part C v2 fix correctly moved the timer to `.common` mode, but the overlay still showed `Ends in 0s` because `CosmeticsStoreView` and `CosmeticDetailView` were using a fresh instance of `PreviewProfileManager` instead of the shared one from `ContentView`. This caused the timer to run on one instance while the overlay observed another. Additionally, `ContentView` was missing the notification listener to perform the actual restoration when the timer expired. The fix ensures the shared manager is passed through the view hierarchy and adds the missing `.onReceive` listener in `ContentView`.
- **Preview countdown timer now actually counts down from 30 to 0** (Part C): was hardcoded to 0 because `PreviewProfileManager.remainingSeconds` was a computed property that the overlay didn't observe. Now `remainingSeconds` is a `@Published` property that the manager drives via a `Timer.scheduledTimer` (decrementing every second), and the overlay observes the manager via `@ObservedObject` so it re-renders on every change. When `remainingSeconds` reaches 0, the timer auto-restores the original profile. The "Stop Preview" button now also calls `PreviewProfileManager.cancelPreviewTimer()` so the timer stops immediately instead of continuing to tick in the background.


- **Default look of the app is now unchanged** (Part E + Part F revert): was changed by the Part E fix (always-on tint on `.glass` cards) and the Part F defaults (which didn't exactly match the original hardcoded colours). The Part E tint is now removed from `StyledCard.swift` and only applied when the Aurora Palette is selected AND owned. The Part F defaults in `ChartColorScheme` and `CardColorScheme` now match the original hardcoded colours exactly. The Aurora Palette and Aurora Chart Skin only affect the UI when selected AND owned — free users see the original look.
- **Aurora Palette now visibly changes the UI when enabled** (Part B): was a silent no-op due to non-reactive `ColourToken`. The palette is now wrapped in a new `ColourTokenStore` (`Helpers/ColourTokenStore.swift`) that observes `CustomisationRegistry` and notifies views when the palette changes. `StyledCardModifier` now observes the store via `@EnvironmentObject` and re-renders when the palette changes.
- **Aurora Chart Skin now visibly re-skins the chart when enabled** (Part B): was a silent no-op due to non-reactive `ChartPalette`. The chart palette is now wrapped in a new `ChartPaletteStore` (`Services/ChartPaletteStore.swift`) that observes both `CustomisationRegistry` (for the profile's chart skin) and `StoreManager` (for the user's entitlements) and notifies views when either changes. `HourlyForecastView` now observes the store via `@EnvironmentObject` and re-renders when the chart skin or entitlements change.
- **Aurora Palette preview** (Part A): the preview button now navigates the user to the main forecast view so they can see the palette applied to their real weather. Previously the preview silently mutated the profile while the user was still on the detail view, so nothing visible happened.
- **Aurora Chart Skin** (Part A): equipping the cosmetic now actually re-skins the hourly chart with the Aurora palette. Previously the chart continued to render with the default cool→warm gradient because `applyCosmetic` was a no-op for `.chart`.
- **Preview button UX** (Part A): the preview flow now navigates to a live view, shows a countdown overlay, and returns the user to the detail view when the preview ends. Previously the preview was a silent mutation with no visible feedback.
- **Aurora Palette and Aurora Chart Skin are now selectable as the active palette/chart** (Phase 5): previously there was no UI to commit the selection. After purchasing (or owning) the cosmetic, the user can now tap "Use now" / "Use this" on the detail sheet — the coordinator applies the cosmetic to the live profile, switches to the Settings tab, and presents the new picker. The picker can also be reached directly from Settings → Appearance → Cosmetic Colours. The `ColourTokenStore` (Part B) and `ChartPaletteStore` (Part B) re-render consumers the moment the selection lands.

- **Aurora Palette is now visible on the default home screen** (Part E): was invisible because the default `.glass` card style didn't use the palette. The `.glass` card style now tints the material with the palette's `surface` colour at 15% opacity so the palette is visible on every card on the home screen. The Aurora Palette's surface (ocean blue `#1F4E79`) now tints the glass cards navy/blue; the default palette's surface (system semantic colour) keeps the original look. The `Material.ultraThin` / `.thin` / `.regular` glass effect is preserved — the tint is an addition, not a replacement. Both `StyledCardModifier` (registry-driven) and `ThemedCardModifier` (live-preview) apply the tint so the Card Settings submenu shows the change in real time.
### Removed
- **Aurora Lottie cosmetic** (Part B): the paid Aurora Lottie IAP (`com.saxweather.cosmetic.aurora.lottie`) was removed entirely. Deleted files: `Services/LottieSkin.swift`. Removed the `lottieSkin` field from `IconographySpec` (ProfileSpecs.swift). Removed the `LottieSkinOverlay` view modifier and `LottieSkinPalette` resolver from `Views/ConditionIcon.swift`. Removed the `.lottie` case from `CosmeticKind` (CosmeticProduct.swift). Removed the product entry from `CosmeticCatalog.allProducts`. Removed the product entry from `configuration.storekit`. The free bundled Lottie animations in `Lottie Animations/` are unaffected — they're the default animations every user sees.
- **Leaderboard feature** (Part D): removed all leaderboard code, CloudKit integration, and leaderboard settings. Deleted files: `CloudKitLeaderboardManager.swift`, `LeaderboardDebugView.swift`, `LeaderboardOptInView.swift`, `LeaderboardSettingsView.swift`, `LeaderboardView.swift`. The leaderboard was an experiment that never shipped. The entitlements files (`SaxWeather.entitlements`, `SaxWeatherWidgetExtension.entitlements`, `SaxWeatherWidgetsExtension.entitlements`) and `Info.plist` had no CloudKit/iCloud entries to remove — the leaderboard code was never wired into the entitlements. The "leaderboard effect" copy in the Supporter Badge subtitle and long description was updated to remove the leaderboard reference.

## [1.2.5] - 2026-01-18

### Added
- Comprehensive accessibility settings following Apple's standards
  - Dynamic text size customization (75% - 150%)
  - Reduce motion options (disable animations, background effects, weather icons)
  - Visual enhancements (increased contrast, bold text, larger touch targets)
  - Enhanced VoiceOver support with detailed labels
  - Haptic feedback controls with intensity (iOS only)
- Accessibility modifiers for consistent app-wide implementation
  - Custom font size support with bold text
  - Touch target size optimization (44pt minimum, 120% when enabled)
  - Animation and transition controls based on reduce motion setting
  - Contrast enhancement for better readability
  - Enhanced VoiceOver labels with hints and values

### Fixed


- Weather background not updating on app launch until manual refresh
  - Background now updates immediately when weather data loads
  - Secondary update after forecast data loads for accuracy
  - Improved weather condition mapping to background types
- Background condition logic prioritizes current weather over forecast
- Text scaling now properly applies throughout the app
- Animations respect reduce motion accessibility setting

## [1.2.4] - 2026-01-11

> **Note**: Version 1.2.3 was skipped due to the extensive nature of these changes.

### Added
- Home screen widgets (small, medium, large) with 5-minute auto-refresh
- Lock screen accessory widgets for iOS 16+
- Saved locations feature - save and switch between multiple locations
- Detailed weather view with summary/detail toggle
- macOS support with native UI
- Glass effect design for iOS 26.2+ with fallbacks for older versions
- Pull-to-refresh gesture on main view
- Cloudy and foggy weather background animations
- 3-tier weather alert system (WeatherKit, Bureau of Meteorology, MET.no)
- Weather data attribution for legal compliance
- Background data refresh for widgets and app
- Done button for keyboard dismissal

### Changed
- Improved feels like temperature calculations (heat index, wind chill)
- Redesigned settings with organized submenus
- Unified appearance settings (theme + background)
- Enhanced hourly forecast with visual graph
- Updated 7-day forecast cards
- Better API call management and optimization
- Updated Lottie library to 4.40

### Fixed


- Australian weather alerts (BOM 403 error)
- Navigation bar display issues
- Forecast icon display
- Custom locations grayout issues
- Widget high/low temperature display
- SwiftUI compatibility issues with NavigationStack
- Toolbar implementation ambiguity
- onChange modifier for pre-iOS 17 compatibility
- WeatherKit type conflicts
- Rain animation display
- Location error handling
- Weather alerts page display
- Onboarding settings flow

## [1.2.2] - 2024-03-21

### Changed
- Updated BackgroundSettingsView to use NavigationStack instead of NavigationView for better iOS compatibility
- Fixed toolbar implementation to resolve ambiguity issues
- Updated onChange modifier to support pre-iOS 17 versions
- General code improvements and bug fixes
- Removed unnecessary MKDirectionsApplicationSupportedModes from Info.plist

### Fixed


- Resolved compiler errors related to SwiftUI compatibility
- Fixed ambiguous use of toolbar content
- Improved backward compatibility for iOS versions prior to 17.0
- Fixed App Store submission error related to routing capabilities

## [1.2.1] - 2024-03-21

### Added
- Initial CHANGELOG.md for version tracking
- Improved error handling

### Changed
- Version update and maintenance release

## [1.2.0] - 2024-03-20

### Added
- Weather notifications for rain and disasters
- Hourly view on forecast page
- Initial release features

### Changed
- Updated Lottie library to version 4.40
- Fixed onboarding settings flow
- Changed deprecated onChange implementation

## [Previous Versions]
- v1.1: Early feature additions
- v1.0: Initial release