//
//  SaxTrackApp.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import SwiftUI
import SwiftData

@main
struct SaxTrackApp: App {
    @State private var shortcutImportData: ShortcutIntegrationService.ShortcutImportData?
    
    var body: some Scene {
        WindowGroup {
            ContentView(shortcutImportData: $shortcutImportData)
        }
        .modelContainer(for: [InstagramUser.self, FollowerSnapshot.self, FollowerChange.self])
        .handlesExternalEvents(matching: ["saxtrack"])
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle Shortcuts URL scheme
        if let importData = ShortcutIntegrationService.shared.handleShortcutURL(url) {
            shortcutImportData = importData
        }
    }
}
