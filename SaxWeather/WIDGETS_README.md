# SaxWeather Widgets Guide

## Available Widgets

### 1. SaxWeather (Main Widget)
**Description:** Comprehensive weather display with all details  
**API Support:** ✅ All (Weather Underground, OpenWeatherMap, OpenMeteo)  
**Sizes:** Small, Medium, Large, Lock Screen (Circular, Rectangular, Inline)

**Shows:**
- Current temperature
- Feels like temperature
- High/Low for today
- Humidity
- Wind speed
- UV Index
- Pressure

---

### 2. SaxWeather Compact
**Description:** Minimal current weather display  
**API Support:** ✅ All (Weather Underground, OpenWeatherMap, OpenMeteo)  
**Sizes:** Small, Lock Screen (Circular, Rectangular, Inline)

**Shows:**
- Current temperature
- Weather condition icon
- High/Low for today

---

### 3. Daily Forecast ⭐ NEW
**Description:** Today's forecast high and low temperatures  
**API Support:** ⚠️ OpenWeatherMap or OpenMeteo only (NO Weather Underground)  
**Sizes:** Lock Screen only (Circular, Rectangular, Inline)

**Shows:**
- Today's high temperature (with ↑ indicator)
- Today's low temperature (with ↓ indicator)
- Weather condition

**Why no Weather Underground?**  
Weather Underground personal weather stations only provide current observations, not forecast data.

---

## Widget Update Behavior

### Auto-Updates (NEW as of Dec 25, 2025)
All widgets now fetch fresh weather data automatically:

- **Current Weather Widgets:** Every 15 minutes
- **Forecast Widget:** Every 30 minutes
- **Independent of App:** No need to open the app for widgets to update
- **Smart Fallback:** Uses cached data if network unavailable

### How It Works
1. Widget wakes up on schedule
2. Reads your location preference (GPS or manual coordinates)
3. Fetches fresh data from OpenMeteo API
4. Updates display with new data
5. Schedules next update

---

## API Requirements

### Current Weather Data
All three APIs provide current weather:
- ✅ Weather Underground
- ✅ OpenWeatherMap
- ✅ OpenMeteo (Free!)

### Forecast Data (High/Low)
Only two APIs provide forecasts:
- ❌ Weather Underground (No forecast support)
- ✅ OpenWeatherMap
- ✅ OpenMeteo (Free!)

---

## Setup Instructions

### Adding Widgets

#### For Home Screen (iOS):
1. Long-press on home screen
2. Tap (+) in top-left corner
3. Search for "SaxWeather"
4. Choose a widget
5. Select size
6. Add to home screen

#### For Lock Screen (iOS):
1. Long-press on lock screen
2. Tap "Customize"
3. Tap widget area
4. Search for "SaxWeather"
5. Choose a widget
6. Done

### Widget Permissions
Widgets automatically inherit location and API settings from the main app. Make sure you've configured:
- ✅ Location permission (if using GPS)
- ✅ At least one API key (or rely on free OpenMeteo)

---

## Troubleshooting

### Widget Shows "No Data"
**Possible causes:**
1. App hasn't been opened yet (open app once to initialize)
2. No valid location set (check Settings > Saved Locations)
3. Network unavailable and no cached data
4. API keys invalid (if not using OpenMeteo)

**Solutions:**
- Open the main app at least once
- Verify location settings (GPS or manual coordinates)
- Check API key configuration in Settings
- Wait for next auto-update (15-30 minutes)

### Forecast Widget Shows "No Data"
**Possible causes:**
1. Using Weather Underground as primary source (doesn't support forecasts)
2. Location not configured
3. No network and no cached forecast data

**Solutions:**
- Use OpenWeatherMap or rely on OpenMeteo fallback
- Verify location is set correctly
- Open main app to cache initial forecast data

### Widget Not Updating
**Possible causes:**
1. Low Power Mode enabled (iOS reduces background updates)
2. Widget budget exhausted (iOS limits widget updates)
3. Network issues

**Solutions:**
- Disable Low Power Mode temporarily
- Wait a few hours for widget budget to reset
- Open app to force refresh and sync

### Wrong Temperature Units
Widgets automatically use the unit system configured in the main app:
1. Open SaxWeather app
2. Go to Settings
3. Change "Unit System" (Metric/Imperial/UK)
4. Widgets will update on next refresh

---

## Data Sources

### Primary Data Sources (Priority Order)
1. **Weather Underground** (if configured)
   - Personal weather station data
   - Most accurate for your exact location
   - Current conditions only

2. **OpenWeatherMap** (if configured)
   - Professional weather service
   - Current conditions + forecasts
   - Requires API key

3. **OpenMeteo** (automatic fallback)
   - Free weather service
   - Current conditions + forecasts
   - No API key required
   - Used by widgets for auto-updates

### Widget Auto-Updates Use OpenMeteo
Widgets always use OpenMeteo for automatic updates because:
- ✅ Free (no API key needed)
- ✅ Reliable and fast
- ✅ Provides complete data (current + forecast)
- ✅ Privacy-friendly (no authentication)
- ✅ Works even if other APIs fail

---

## Privacy & Battery

### Location Access
- Widgets use location saved by main app
- GPS location updated when app is opened
- Manual coordinates always available as fallback
- No location tracking in background

### Battery Impact
- Minimal impact (Apple optimizes widget updates)
- Network requests only every 15-30 minutes
- Cached data used when possible
- No continuous background processes

### Data Usage
- Very small (~1-5 KB per update)
- Only downloads when widget refreshes
- Compressed API responses
- Approximately 2-5 MB per month for all widgets

---

## Technical Details

### Shared Data Storage
Widgets and app share data using App Group:
- **Group ID:** `group.com.saxobroko.SaxWeather`
- **Shared Settings:** Location, unit system, API keys
- **Cached Weather:** Last known weather data
- **Security:** Sandboxed, encrypted on device

### Update Schedule
```
Current Weather Widgets: .after(15 minutes)
Forecast Widget: .after(30 minutes)
```

### Network Requests
All widget network requests:
- Use URLSession with 15-second timeout
- Respect Low Data Mode
- Fail gracefully with cached data
- No retry storms

---

## Frequently Asked Questions

**Q: Do widgets drain my battery?**  
A: No, widgets have minimal battery impact. iOS manages widget updates efficiently.

**Q: Do I need an API key?**  
A: No! Widgets work with free OpenMeteo. API keys only needed for Weather Underground or OpenWeatherMap preferences.

**Q: Why doesn't my WU data show in the forecast widget?**  
A: Weather Underground doesn't provide forecast data (high/low temps). The forecast widget uses OpenMeteo or OpenWeatherMap.

**Q: Can I have multiple widgets?**  
A: Yes! Add as many as you want. They all share the same data source.

**Q: Do widgets work offline?**  
A: Widgets will show the last cached weather data when offline. Data refreshes when network returns.

**Q: How do I remove a widget?**  
A: Long-press the widget and select "Remove Widget" or drag it to the "Remove" area.

---

## Support

For issues or questions:
- Check Settings > About > Source Code
- Review CHANGELOG.md for recent updates
- Verify API configuration in Settings

---

**Last Updated:** December 25, 2025  
**Widget Version:** 2.0 (Auto-updating)
