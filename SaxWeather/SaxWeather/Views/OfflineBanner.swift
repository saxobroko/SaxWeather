//
//  OfflineBanner.swift
//  SaxWeather
//
//  Created on 16/06/2026
//
//  Top-of-screen banner that slides down when the device
//  transitions from online to offline. Sits above the tab bar
//  and respects safe area. Watches `NetworkMonitor.shared` so
//  it appears / disappears automatically — no manual toggling
//  required from view code.
//

import SwiftUI

struct OfflineBanner: View {
    @ObservedObject private var monitor = NetworkMonitor.shared

    var body: some View {
        // Only render content when the device is actually
        // offline. SwiftUI still keeps the view in the hierarchy
        // (because of `.safeAreaInset`) but the height collapses
        // to 0 when offline is false, so the underlying content
        // reflows naturally.
        Group {
            if !monitor.isConnected {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("You're offline — showing cached data")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.orange,
                            Color.orange.opacity(0.85)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: monitor.isConnected)
    }
}

#Preview("Offline") {
    VStack {
        OfflineBanner()
        Spacer()
    }
}
