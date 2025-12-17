//
//  BackgroundView.swift
//  SaxWeather
//
//  Created by Saxon on 2/3/2025.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storeManager: StoreManager
    @AppStorage("userCustomBackground") private var savedImageData: Data?
    @AppStorage("useCustomBackground") private var useCustomBackground = true
    
    let condition: String
    
    #if os(iOS)
    private func backgroundImage(for condition: String) -> Image? {
        if let uiImage = UIImage(named: "weather_background_\(condition)") {
            return Image(uiImage: uiImage)
        } else if let uiImage = UIImage(named: "weather_background_default") {
            return Image(uiImage: uiImage)
        }
        return nil
    }
    #elseif os(macOS)
    private func backgroundImage(for condition: String) -> Image? {
        if let nsImage = NSImage(named: "weather_background_\(condition)") {
            return Image(nsImage: nsImage)
        } else if let nsImage = NSImage(named: "weather_background_default") {
            return Image(nsImage: nsImage)
        }
        return nil
    }
    #endif
    
    var body: some View {
        GeometryReader { geometry in
            // Check if custom background should be used
            if storeManager.customBackgroundUnlocked && useCustomBackground,
               let imageData = savedImageData {
                #if os(iOS)
                if let customImage = UIImage(data: imageData) {
                    Image(uiImage: customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(
                            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.3)
                                .edgesIgnoringSafeArea(.all)
                        )
                } else {
                    defaultBackground(geometry: geometry)
                }
                #elseif os(macOS)
                if let customImage = NSImage(data: imageData) {
                    Image(nsImage: customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(
                            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.3)
                                .edgesIgnoringSafeArea(.all)
                        )
                } else {
                    defaultBackground(geometry: geometry)
                }
                #endif
            } else {
                defaultBackground(geometry: geometry)
            }
        }
    }

    @ViewBuilder
    private func defaultBackground(geometry: GeometryProxy) -> some View {
        if let bg = backgroundImage(for: condition) {
            bg
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            Color.blue.opacity(0.2).ignoresSafeArea()
        }
    }
}
