//
//  AutoRefreshManager.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-18
//
//  NOTE: This file is kept for reference but not currently used.
//  Auto-refresh is implemented directly in ContentView using @AppStorage and Timer.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Notification Extension
extension Notification.Name {
    static let autoRefreshWeather = Notification.Name("autoRefreshWeather")
}
