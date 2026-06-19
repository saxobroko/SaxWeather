//
//  BackgroundRefreshStatusView.swift
//  SaxWeather
//
//  A debug view to check background refresh configuration
//

import SwiftUI
import BackgroundTasks

#if os(iOS)
struct BackgroundRefreshStatusView: View {
    @State private var backgroundRefreshStatus = "Checking..."
    @State private var lastRefreshTime: Date?
    @State private var nextScheduledRefresh: Date?
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Background Refresh")
                        .font(.headline)
                    Spacer()
                    Text(backgroundRefreshStatus)
                        .foregroundColor(statusColor)
                }
                
                if let lastRefresh = lastRefreshTime {
                    HStack {
                        Text("Last Refresh")
                        Spacer()
                        Text(lastRefresh, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let nextRefresh = nextScheduledRefresh {
                    HStack {
                        Text("Next Scheduled")
                        Spacer()
                        Text(nextRefresh, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Background Refresh Status")
            } footer: {
                Text("Background refresh allows widgets to update without opening the app. If disabled, check Settings → General → Background App Refresh.")
            }
            
            Section {
                Button {
                    checkBackgroundRefreshStatus()
                } label: {
                    Label("Check Status", systemImage: "arrow.clockwise")
                }
                
                Button {
                    scheduleImmediateRefresh()
                } label: {
                    Label("Test Refresh", systemImage: "bolt.fill")
                }
                
                Button {
                    openBackgroundRefreshSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
            } header: {
                Text("Actions")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(title: "Task ID", value: "com.saxobroko.SaxWeather.refresh")
                    InfoRow(
                        title: "Interval",
                        value: formattedInterval(seconds: BackgroundRefreshCoordinator.shared.nextIntervalSeconds)
                    )
                    InfoRow(
                        title: "Failures",
                        value: "\(BackgroundRefreshCoordinator.shared.consecutiveFailures)"
                    )
                    InfoRow(
                        title: "Low Power Mode",
                        value: BackgroundRefreshCoordinator.shared.isLowPowerModeEnabled ? "On (2× backoff)" : "Off"
                    )
                    InfoRow(title: "Policy", value: "Exponential backoff on failure")
                }
            } header: {
                Text("Configuration")
            }

            Section {
                Button {
                    BackgroundRefreshCoordinator.shared.resetFailureCounter()
                    checkBackgroundRefreshStatus()
                } label: {
                    Label("Reset Backoff Counter", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Debug")
            } footer: {
                Text("Resets the consecutive-failure counter. The next background refresh will use the base 5-minute interval.")
            }
        }
        .navigationTitle("Background Refresh")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkBackgroundRefreshStatus()
        }
    }

    /// Format an interval (in seconds) as a human-readable string.
    /// We render in minutes up to 60 min, then in hours.
    private func formattedInterval(seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 {
            return "\(minutes) minutes"
        }
        let hours = Double(minutes) / 60.0
        return String(format: "%.1f hours", hours)
    }

    private var statusColor: Color {
        switch backgroundRefreshStatus {
        case "Available":
            return .green
        case "Denied", "Restricted":
            return .red
        default:
            return .orange
        }
    }

    private func checkBackgroundRefreshStatus() {
        let status = UIApplication.shared.backgroundRefreshStatus

        switch status {
        case .available:
            backgroundRefreshStatus = "Available"
        case .denied:
            backgroundRefreshStatus = "Denied"
        case .restricted:
            backgroundRefreshStatus = "Restricted"
        @unknown default:
            backgroundRefreshStatus = "Unknown"
        }

        // Try to read last refresh time from UserDefaults
        if let lastRefresh = UserDefaults.standard.object(forKey: "lastBackgroundRefresh") as? Date {
            lastRefreshTime = lastRefresh
        }

        // Next scheduled refresh now uses the *coordinator's*
        // computed interval, which reflects the backoff state
        // and Low Power Mode adjustments.
        let coordinator = BackgroundRefreshCoordinator.shared
        if let last = coordinator.lastSuccessDate ?? lastRefreshTime {
            nextScheduledRefresh = last.addingTimeInterval(coordinator.nextIntervalSeconds)
        } else {
            nextScheduledRefresh = Date().addingTimeInterval(coordinator.nextIntervalSeconds)
        }
    }
    
    private func scheduleImmediateRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.saxobroko.SaxWeather.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1) // 1 second from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Immediate refresh scheduled")
            
            // Show alert
            let alert = UIAlertController(
                title: "Test Scheduled",
                message: "Background refresh test scheduled. Check Console.app in a few seconds.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        } catch {
            print("❌ Failed to schedule: \(error)")
        }
    }
    
    private func openBackgroundRefreshSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    NavigationView {
        BackgroundRefreshStatusView()
    }
}
#endif
