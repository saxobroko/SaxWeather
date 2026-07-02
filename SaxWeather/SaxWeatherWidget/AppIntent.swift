//
//  AppIntent.swift
//  SaxWeatherWidget
//
//  Created by Saxon on 18/5/2025.
//

import WidgetKit
import AppIntents

@available(iOS 17.0, macOS 14.0, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "Select a location for the weather widget." }

    @Parameter(title: "Location")
    var location: LocationEntity?
}
