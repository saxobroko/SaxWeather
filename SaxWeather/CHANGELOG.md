# Changelog

All notable changes to SaxWeather will be documented in this file.

## [1.2.4] - 2026-01-11 (Unreleased)

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