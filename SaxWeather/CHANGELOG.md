# Changelog

## [1.3.0] - 2026-06-27

### Added
- iCloud sync for customisation profiles (`Services/iCloudSyncService.swift`)
- Aurora cosmetic system: palette, chart skin, backgrounds
- Per-card and per-chart colour schemes with Aurora override
- Live cosmetic preview with 30-second countdown overlay
- Cosmetic tile placeholders and per-IAP tile image slots
- Palette picker and chart skin picker in Settings

### Changed
- Aurora Chart Skin now affects rain probability, precipitation timeline, and hourly forecast
- Aurora Palette now affects every card via `.styledCard()` modifier
- Aurora Pack now ships 3 items (Backgrounds, Palette, Chart Skin) at $9.99

### Fixed
- Preview countdown timer now counts down correctly (shared `PreviewProfileManager` via `@StateObject`)
- Aurora Palette and Chart Skin now visibly change UI when enabled
- Default app look unchanged for free users

### Removed
- Aurora Lottie cosmetic IAP
- Leaderboard feature (never shipped)

## [1.2.5] - 2026-01-18

### Added
- Accessibility settings: dynamic text size, reduce motion, increased contrast, bold text, larger touch targets, VoiceOver labels, haptic controls
- Accessibility modifiers for app-wide consistency

### Fixed
- Weather background updates immediately on app launch
- Text scaling applies throughout the app
- Animations respect reduce motion setting

## [1.2.4] - 2026-01-11

### Added
- Home screen widgets (small, medium, large) with 5-minute auto-refresh
- Lock screen accessory widgets (iOS 16+)
- Saved locations
- Detailed weather view with summary/detail toggle
- macOS support
- Glass effect design (iOS 26.2+)
- Pull-to-refresh
- Cloudy and foggy weather backgrounds
- 3-tier weather alert system (WeatherKit, BOM, MET.no)
- Weather data attribution
- Background data refresh

### Changed
- Improved feels-like temperature calculations
- Redesigned settings with submenus
- Enhanced hourly forecast with visual graph

### Fixed
- BOM 403 error
- Widget high/low temperature display
- SwiftUI NavigationStack compatibility
- WeatherKit type conflicts

## [1.2.2] - 2024-03-21

### Changed
- NavigationStack replaces NavigationView
- Pre-iOS 17 onChange support

## [1.2.1] - 2024-03-21

### Added
- Initial CHANGELOG.md
- Improved error handling

## [1.2.0] - 2024-03-20

### Added
- Weather notifications
- Hourly forecast view

## [1.0]
- Initial release
