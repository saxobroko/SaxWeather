//
//  BackgroundSettingsButton.swift
//  SaxWeather
//

import SwiftUI

struct BackgroundSettingsButton: View {
    @State private var showingBackgroundSettings = false
    // Get the store manager from the environment
    @EnvironmentObject var storeManager: StoreManager
    
    var body: some View {
        Button(action: {
            showingBackgroundSettings = true
        }) {
            HStack {
                Image(systemName: "photo.fill")
                Text("Background Settings")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .sheet(isPresented: $showingBackgroundSettings) {
            // Pass the environment object to the sheet
            BackgroundSettingsView()
                .environmentObject(storeManager)
        }
    }
}

// Add a preview with the environment object for Xcode previews
struct BackgroundSettingsButton_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundSettingsButton()
            .environmentObject(StoreManager.shared)
    }
}
