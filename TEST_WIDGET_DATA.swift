import Foundation

// Quick test to verify widget data storage and API calls
// Run this in the main app's console to debug widget issues

func debugWidgetData() {
    let sharedDefaults = UserDefaults(suiteName: "group.com.saxobroko.SaxWeather")
    
    print("=" * 50)
    print("📱 WIDGET DATA DEBUG")
    print("=" * 50)
    
    // Check coordinates
    if let lat = sharedDefaults?.string(forKey: "latitude"),
       let lon = sharedDefaults?.string(forKey: "longitude") {
        print("✅ Manual Location: \(lat), \(lon)")
    } else {
        print("❌ No manual location stored")
    }
    
    if let lat = sharedDefaults?.string(forKey: "lastKnownLatitude"),
       let lon = sharedDefaults?.string(forKey: "lastKnownLongitude") {
        print("✅ GPS Location: \(lat), \(lon)")
    } else {
        print("❌ No GPS location stored")
    }
    
    // Check unit system
    let unitSystem = sharedDefaults?.string(forKey: "unitSystem") ?? "Metric"
    print("📏 Unit System: \(unitSystem)")
    
    // Check GPS setting
    let useGPS = sharedDefaults?.bool(forKey: "useGPS") ?? false
    print("🛰️  Use GPS: \(useGPS)")
    
    // Check latest weather data
    if let data = sharedDefaults?.data(forKey: "latestWeather"),
       let weatherDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
        print("\n✅ Cached Weather Data:")
        if let temp = weatherDict["temperature"] as? Double {
            print("   Temperature: \(temp)°")
        }
        if let condition = weatherDict["condition"] as? String {
            print("   Condition: \(condition)")
        }
        if let lastUpdate = weatherDict["lastUpdateDate"] as? Double {
            let date = Date(timeIntervalSince1970: lastUpdate)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            print("   Last Updated: \(formatter.string(from: date))")
        }
    } else {
        print("❌ No cached weather data")
    }
    
    print("=" * 50)
    print("💡 To refresh widget: Open SaxWeather app and ensure location is set")
    print("=" * 50)
}

// Call this from the main app when debugging
// debugWidgetData()
