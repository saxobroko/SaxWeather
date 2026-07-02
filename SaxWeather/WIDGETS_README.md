# Widgets

## Available Widgets

### SaxWeather (Main)
Sizes: Small, Medium, Large, Lock Screen (Circular, Rectangular, Inline)

Shows: current temp, feels like, high/low, humidity, wind, UV, pressure

### SaxWeather Compact
Sizes: Small, Lock Screen

Shows: current temp, condition icon, high/low

### Daily Forecast
Sizes: Lock Screen only

Shows: today's high/low, condition

Requires OpenWeatherMap or OpenMeteo (Weather Underground doesn't provide forecasts).

## Auto-Updates

- Current weather widgets: every 15 minutes
- Forecast widget: every 30 minutes
- Uses OpenMeteo (free, no API key)
- Falls back to cached data when offline

## Setup

### Home Screen
1. Long-press home screen
2. Tap (+)
3. Search "SaxWeather"
4. Choose widget and size

### Lock Screen
1. Long-press lock screen
2. Tap "Customize"
3. Tap widget area
4. Search "SaxWeather"

## Troubleshooting

**No data**: Open the main app once to initialize. Check location and API settings.

**Not updating**: Disable Low Power Mode. iOS limits widget updates.

**Wrong units**: Change unit system in app Settings. Widgets update on next refresh.

## Data Sources

Priority: Weather Underground → OpenWeatherMap → OpenMeteo (fallback)

Widgets always use OpenMeteo for auto-updates (free, reliable, no API key).

## Technical

- App Group: `group.com.saxobroko.SaxWeather`
- Shared: location, unit system, API keys, cached weather
- Update schedule: `.after(15 minutes)` for current, `.after(30 minutes)` for forecast
- Network: 15-second timeout, respects Low Data Mode
