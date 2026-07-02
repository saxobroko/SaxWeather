//
//  LottieDebugView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-03-10
//  Last modified: 2026-01-11
//

#if os(iOS)

import SwiftUI
import Lottie
import UniformTypeIdentifiers
import os.log
import KeychainSwift
import UserNotifications
import WeatherKit

private struct DebugMessage: Identifiable, Hashable {
    let id = UUID()
    let message: String
    let timestamp: Date
    let type: MessageType
    
    enum MessageType {
        case info, success, warning, error
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DebugMessage, rhs: DebugMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct LottieDebugView: View {
    // MARK: - Properties
    @State private var debugMessages: [DebugMessage] = []
    @State private var selectedAnimation = "clear-day"
    @State private var showingFileExport = false
    @State private var exportData: Data?
    @State private var exportFilename = ""
    @State private var previewFailed = false
    @State private var refreshID = UUID()
    @State private var sessionStartTime = Date()
    @State private var selectedTab = 0
    @State private var autoScroll = true
    @State private var showSystemInfo = false
    
    private let logger = Logger(subsystem: "com.saxobroko.saxweather", category: "Debug")
    private let keychainService = KeychainService.shared
    
    // Known services for API keys
    private let knownServices = ["wu", "owm"]
    @State private var selectedService = "wu"
    @State private var apiKeyInput = ""
    
    // List matches your actual files in the bundle
    let availableAnimations = [
        "clear-day", "clear-night", "partly-cloudy", "partly-cloudy-night",
        "cloudy", "rainy", "thunderstorm", "foggy"
    ]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Debug Section", selection: $selectedTab) {
                    Text("Animations").tag(0)
                    Text("API Keys").tag(1)
                    Text("System").tag(2)
                    Text("Console").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case 0:
                            animationsSection
                        case 1:
                            apiKeysSection
                        case 2:
                            systemInfoSection
                        case 3:
                            consoleSection
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("🐞 Developer Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { exportDebugLog() }) {
                            Label("Export Debug Log", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { clearDebugLog() }) {
                            Label("Clear Console", systemImage: "trash")
                        }
                        Divider()
                        Toggle("Auto-scroll Console", isOn: $autoScroll)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFileExport) {
                if let data = exportData {
                    DocumentExporterView(data: data, filename: exportFilename)
                }
            }
        }
        .onAppear {
            addDebugMessage("Debug session started", type: .info)
            performInitialSystemCheck()
        }
    }
    
    // MARK: - Animations Section
    
    private var animationsSection: some View {
        VStack(spacing: 16) {
            // Header Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("Animation Testing")
                        .font(.title2.bold())
                }
                Text("Test and debug Lottie animations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            // Animation Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Animation")
                    .font(.headline)
                
                Picker("Animation", selection: $selectedAnimation) {
                    ForEach(availableAnimations, id: \.self) { name in
                        HStack {
                            Image(systemName: getAnimationIcon(name))
                            Text(name)
                        }.tag(name)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedAnimation) { newValue in
                    previewFailed = false
                    refreshID = UUID()
                    addDebugMessage("Selected animation: \(newValue)", type: .info)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Preview Card
            VStack(spacing: 12) {
                HStack {
                    Text("Live Preview")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        refreshID = UUID()
                        previewFailed = false
                        addDebugMessage("Refreshed preview", type: .info)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.bold())
                    }
                    .buttonStyle(.bordered)
                }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                    
                    if previewFailed {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Preview Failed")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Check console for details")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        AnimationPreviewView(
                            animationName: selectedAnimation,
                            onFailure: {
                                previewFailed = true
                                addDebugMessage("Animation preview failed for \(selectedAnimation)", type: .error)
                            }
                        )
                        .id(refreshID)
                    }
                }
                .frame(height: 250)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            
            // Action Buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    debugActionButton(
                        title: "Check File",
                        icon: "doc.text.magnifyingglass",
                        color: .blue
                    ) {
                        checkFileExists()
                    }
                    
                    debugActionButton(
                        title: "Deep Inspect",
                        icon: "scope",
                        color: .purple
                    ) {
                        deepInspectFile()
                    }
                }
                
                debugActionButton(
                    title: "List All Animations",
                    icon: "list.bullet.rectangle",
                    color: .green
                ) {
                    listAllFiles()
                }
            }
        }
    }
    
    // MARK: - API Keys Section
    
    private var apiKeysSection: some View {
        VStack(spacing: 16) {
            // Header Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("API Key Management")
                        .font(.title2.bold())
                }
                Text("Manage API keys stored in Keychain")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Keychain Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Secure Storage")
                        .font(.subheadline.bold())
                }
                Text("API keys are encrypted and synchronized via iCloud Keychain across your devices.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Add/Edit API Key
            VStack(alignment: .leading, spacing: 12) {
                Text("Add or Update Key")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Picker("Service", selection: $selectedService) {
                        ForEach(knownServices, id: \.self) { service in
                            Text(service.uppercased()).tag(service)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    
                    SecureField("API Key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: { saveApiKey() }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKeyInput.isEmpty)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Stored Keys
            VStack(alignment: .leading, spacing: 12) {
                Text("Stored API Keys")
                    .font(.headline)
                
                ForEach(knownServices, id: \.self) { service in
                    apiKeyRow(service: service)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Quick Actions
            HStack(spacing: 12) {
                debugActionButton(
                    title: "Test Keychain",
                    icon: "stethoscope",
                    color: .blue
                ) {
                    checkKeychainItems()
                }
                
                debugActionButton(
                    title: "Migrate from UserDefaults",
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange
                ) {
                    migrateFromUserDefaults()
                }
            }
            
            debugActionButton(
                title: "Clear All Keys",
                icon: "trash.fill",
                color: .red
            ) {
                clearKeychain()
            }
        }
    }
    
    // MARK: - System Info Section
    
    private var systemInfoSection: some View {
        VStack(spacing: 16) {
            ThemeEditorCard()

            // Header Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("System Information")
                        .font(.title2.bold())
                }
                Text("App and device diagnostics")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Session Info
            infoCard(
                title: "Session",
                icon: "clock.fill",
                color: .blue,
                items: [
                    ("Started", sessionStartTime.formatted(date: .abbreviated, time: .standard)),
                    ("Duration", formatDuration(from: sessionStartTime)),
                    ("User", NSUserName())
                ]
            )
            
            // App Info
            infoCard(
                title: "Application",
                icon: "app.fill",
                color: .purple,
                items: [
                    ("Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"),
                    ("Build", Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"),
                    ("Bundle ID", Bundle.main.bundleIdentifier ?? "Unknown")
                ]
            )
            
            // Device Info
            infoCard(
                title: "Device",
                icon: "iphone",
                color: .orange,
                items: [
                    ("Model", UIDevice.current.model),
                    ("iOS Version", UIDevice.current.systemVersion),
                    ("Name", UIDevice.current.name)
                ]
            )
            
            // Storage Info
            infoCard(
                title: "Storage",
                icon: "internaldrive.fill",
                color: .pink,
                items: getStorageInfo()
            )

            // Onboarding Controls
            // Lets the developer re-trigger the onboarding
            // flow on demand for testing. Setting the
            // `isFirstLaunch` flag and posting
            // `.debugRerunOnboarding` is the same path the
            // production code uses, so this exercises the
            // real flow rather than a debug-only shortcut.
            onboardingDebugCard()

            // Notification Settings
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.indigo)
                    Text("Notifications")
                        .font(.headline)
                }
                
                Button("Check Authorization Status") {
                    checkNotificationSettings()
                }
                .buttonStyle(.bordered)
                
                Button("Schedule Test Notification") {
                    scheduleTestNotification()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Console Section
    
    private var consoleSection: some View {
        VStack(spacing: 16) {
            // Header Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "terminal.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("Debug Console")
                        .font(.title2.bold())
                    Spacer()
                    
                    // Message count badge
                    Text("\(debugMessages.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                Text("Real-time logging and debug output")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Filter Buttons
            HStack(spacing: 8) {
                filterButton(icon: "info.circle.fill", color: .blue, label: "Info")
                filterButton(icon: "checkmark.circle.fill", color: .green, label: "Success")
                filterButton(icon: "exclamationmark.triangle.fill", color: .orange, label: "Warning")
                filterButton(icon: "xmark.circle.fill", color: .red, label: "Error")
            }
            
            // Console Output
            VStack(spacing: 0) {
                if debugMessages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "terminal")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No messages yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Debug messages will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(debugMessages) { message in
                                    consoleMessageRow(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .frame(height: 400)
                        .onChange(of: debugMessages.count) { _ in
                            if autoScroll, let lastMessage = debugMessages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            
            // Quick Actions
            HStack(spacing: 12) {
                debugActionButton(
                    title: "Copy All",
                    icon: "doc.on.doc",
                    color: .blue
                ) {
                    copyConsoleToClipboard()
                }
                
                debugActionButton(
                    title: "Export Log",
                    icon: "square.and.arrow.up",
                    color: .purple
                ) {
                    exportDebugLog()
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func debugActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }
    
    private func infoCard(title: String, icon: String, color: Color, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(item.1)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func onboardingDebugCard() -> some View {
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "isFirstLaunch")

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.badge.questionmark.fill")
                    .foregroundColor(.teal)
                Text("Onboarding")
                    .font(.headline)
                Spacer()
                // Live status: ✅ if completed (flag is
                // false), ⚠️ if still on first launch
                // (flag is true).
                Text(isFirstLaunch ? "⚠️ First launch" : "✅ Completed")
                    .font(.caption.bold())
                    .foregroundColor(isFirstLaunch ? .orange : .green)
            }

            Text("Re-trigger or reset the new-user onboarding tour for testing.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Button(action: rerunOnboarding) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Re-run Onboarding")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)

                Button(action: markOnboardingComplete) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Mark Onboarding Complete")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func rerunOnboarding() {
        UserDefaults.standard.set(true, forKey: "isFirstLaunch")
        NotificationCenter.default.post(name: .debugRerunOnboarding, object: nil)
        addDebugMessage("🔁 Re-running onboarding flow", type: .info)
    }

    /// Reset the `isFirstLaunch` flag to `false` so the
    /// onboarding view won't show on next launch. Useful for
    /// cleaning up after testing.
    private func markOnboardingComplete() {
        UserDefaults.standard.set(false, forKey: "isFirstLaunch")
        addDebugMessage("✅ Onboarding marked complete", type: .success)
    }

    private func apiKeyRow(service: String) -> some View {
        HStack {
            Image(systemName: "key.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(service.uppercased())
                    .font(.subheadline.bold())
                
                if let apiKey = keychainService.getApiKey(forService: service) {
                    Text(maskApiKey(apiKey))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            if keychainService.getApiKey(forService: service) != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func consoleMessageRow(message: DebugMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: message.type.icon)
                .font(.body)
                .foregroundColor(message.type.color)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dateFormatter.string(from: message.timestamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Text(message.message)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = message.message
            }) {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
        }
    }
    
    private func filterButton(icon: String, color: Color, label: String) -> some View {
        Button(action: {
            // Filter functionality can be added here
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }
    
    // MARK: - Helper Methods
    
    private func addDebugMessage(_ message: String, type: DebugMessage.MessageType) {
        debugMessages.append(DebugMessage(message: message, timestamp: Date(), type: type))
        logger.debug("\(message)")
    }
    
    private func setDebugMessages(_ messages: [String], type: DebugMessage.MessageType = .info) {
        debugMessages = messages.map { DebugMessage(message: $0, timestamp: Date(), type: type) }
    }
    
    private func clearDebugLog() {
        debugMessages.removeAll()
        addDebugMessage("Console cleared", type: .info)
    }
    
    private func exportDebugLog() {
        let logText = debugMessages.map { message in
            "[\(dateFormatter.string(from: message.timestamp))] \(message.message)"
        }.joined(separator: "\n")
        
        exportData = logText.data(using: .utf8)
        exportFilename = "saxweather-debug-\(Date().ISO8601Format()).txt"
        showingFileExport = true
        addDebugMessage("Exporting debug log", type: .info)
    }
    
    private func copyConsoleToClipboard() {
        let allMessages = debugMessages.map { message in
            "[\(dateFormatter.string(from: message.timestamp))] \(message.message)"
        }.joined(separator: "\n")
        
        UIPasteboard.general.string = allMessages
        addDebugMessage("Copied \(debugMessages.count) messages to clipboard", type: .success)
    }
    
    private func performInitialSystemCheck() {
        addDebugMessage("System: iOS \(UIDevice.current.systemVersion)", type: .info)
        addDebugMessage("Device: \(UIDevice.current.model)", type: .info)
        
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            addDebugMessage("App Version: \(version)", type: .info)
        }
    }
    
    private func getAnimationIcon(_ name: String) -> String {
        switch name {
        case "clear-day": return "sun.max.fill"
        case "clear-night": return "moon.stars.fill"
        case "partly-cloudy", "partly-cloudy-night": return "cloud.sun.fill"
        case "cloudy": return "cloud.fill"
        case "rainy": return "cloud.rain.fill"
        case "thunderstorm": return "cloud.bolt.fill"
        case "foggy": return "cloud.fog.fill"
        default: return "photo"
        }
    }
    
    private func formatDuration(from startDate: Date) -> String {
        let duration = Date().timeIntervalSince(startDate)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func getStorageInfo() -> [(String, String)] {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            
            let available = values.volumeAvailableCapacity ?? 0
            let total = values.volumeTotalCapacity ?? 0
            let used = total - available
            
            return [
                ("Total", ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)),
                ("Used", ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file)),
                ("Available", ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .file))
            ]
        } catch {
            return [("Error", error.localizedDescription)]
        }
    }
    
    private func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    addDebugMessage("Notifications: ✅ Authorized", type: .success)
                case .denied:
                    addDebugMessage("Notifications: ❌ Denied", type: .error)
                case .notDetermined:
                    addDebugMessage("Notifications: ⚠️ Not determined", type: .warning)
                case .provisional:
                    addDebugMessage("Notifications: ⚠️ Provisional", type: .warning)
                case .ephemeral:
                    addDebugMessage("Notifications: ⚠️ Ephemeral", type: .warning)
                @unknown default:
                    addDebugMessage("Notifications: ❓ Unknown", type: .warning)
                }
            }
        }
    }
    
    private func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "SaxWeather Debug"
        content.body = "Test notification scheduled at \(Date().formatted(date: .omitted, time: .standard))"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    addDebugMessage("Failed to schedule notification: \(error.localizedDescription)", type: .error)
                } else {
                    addDebugMessage("Test notification scheduled for 5 seconds", type: .success)
                }
            }
        }
    }
    
    // MARK: - Debug Functions
    
    private func checkFileExists() {
        addDebugMessage("Checking for \(selectedAnimation)...", type: .info)
        
        // Check .lottie file
        if let url = Bundle.main.url(forResource: selectedAnimation, withExtension: "lottie") {
            addDebugMessage("✅ \(selectedAnimation).lottie exists", type: .success)
            addDebugMessage("Path: \(url.path)", type: .info)
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? Int {
                    addDebugMessage("Size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))", type: .info)
                }
            } catch {
                addDebugMessage("Error getting file attributes: \(error.localizedDescription)", type: .error)
            }
        } else {
            addDebugMessage("❌ \(selectedAnimation).lottie not found", type: .error)
        }
        
        // Check JSON file
        if Bundle.main.url(forResource: selectedAnimation, withExtension: "json") != nil {
            addDebugMessage("✅ \(selectedAnimation).json exists", type: .success)
        } else {
            addDebugMessage("⚠️ \(selectedAnimation).json not found", type: .warning)
        }
    }
    
    private func deepInspectFile() {
        addDebugMessage("Deep inspecting \(selectedAnimation).lottie...", type: .info)
        
        guard let url = Bundle.main.url(forResource: selectedAnimation, withExtension: "lottie") else {
            addDebugMessage("❌ File not found", type: .error)
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            addDebugMessage("File size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))", type: .info)
            
            // Check if it's a ZIP file
            let isZip = data.prefix(4).map { $0 } == [0x50, 0x4B, 0x03, 0x04]
            addDebugMessage("Is ZIP file: \(isZip ? "Yes" : "No")", type: .info)
            
            if !isZip {
                // Try to parse as JSON
                if String(data: data, encoding: .utf8) != nil {
                    addDebugMessage("Content appears to be text/JSON", type: .info)
                    
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        addDebugMessage("✅ Valid JSON structure", type: .success)
                        
                        // Check for critical Lottie properties
                        if let dict = json as? [String: Any] {
                            let hasVersion = dict["v"] != nil
                            let hasLayers = dict["layers"] != nil
                            addDebugMessage("Has version: \(hasVersion ? "Yes" : "No")", type: hasVersion ? .success : .warning)
                            addDebugMessage("Has layers: \(hasLayers ? "Yes" : "No")", type: hasLayers ? .success : .warning)
                            
                            if hasVersion && hasLayers {
                                addDebugMessage("✅ Valid Lottie JSON", type: .success)
                            } else {
                                addDebugMessage("❌ Missing essential Lottie properties", type: .error)
                            }
                        }
                    } catch {
                        addDebugMessage("❌ Invalid JSON: \(error.localizedDescription)", type: .error)
                    }
                } else {
                    addDebugMessage("❌ Not valid UTF-8 text", type: .error)
                }
            }
        } catch {
            addDebugMessage("❌ Error reading file: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func listAllFiles() {
        addDebugMessage("Listing all animation files...", type: .info)
        
        let lottieFiles = Bundle.main.paths(forResourcesOfType: "lottie", inDirectory: nil)
        addDebugMessage("📂 Found \(lottieFiles.count) .lottie files", type: .info)
        for path in lottieFiles {
            let filename = URL(fileURLWithPath: path).lastPathComponent
            addDebugMessage("  • \(filename)", type: .info)
        }
        
        let jsonFiles = Bundle.main.paths(forResourcesOfType: "json", inDirectory: nil)
        addDebugMessage("📂 Found \(jsonFiles.count) .json files", type: .info)
        for path in jsonFiles {
            let filename = URL(fileURLWithPath: path).lastPathComponent
            addDebugMessage("  • \(filename)", type: .info)
        }
        
        if lottieFiles.isEmpty && jsonFiles.isEmpty {
            addDebugMessage("⚠️ No animation files found in bundle", type: .warning)
        }
    }
    
    private func checkKeychainItems() {
        addDebugMessage("Checking Keychain items...", type: .info)
        
        addDebugMessage("Keychain: iCloud sync enabled ✓", type: .info)
        
        // Test keychain accessibility
        let testKey = "debugTestKey"
        let testValue = "debugTestValue"
        
        if keychainService.keychain.set(testValue, forKey: testKey) {
            addDebugMessage("✅ Can write to keychain", type: .success)
            if keychainService.keychain.get(testKey) != nil {
                addDebugMessage("✅ Can read from keychain", type: .success)
                if keychainService.keychain.delete(testKey) {
                    addDebugMessage("✅ Can delete from keychain", type: .success)
                } else {
                    addDebugMessage("❌ Cannot delete from keychain", type: .error)
                }
            } else {
                addDebugMessage("❌ Cannot read from keychain", type: .error)
            }
        } else {
            addDebugMessage("❌ Cannot write to keychain", type: .error)
            addDebugMessage("Error code: \(keychainService.keychain.lastResultCode)", type: .error)
        }
        
        addDebugMessage("Stored API Keys:", type: .info)
        for service in knownServices {
            if let apiKey = keychainService.getApiKey(forService: service) {
                let maskedKey = maskApiKey(apiKey)
                addDebugMessage("✅ \(service.uppercased()): \(maskedKey)", type: .success)
            } else {
                addDebugMessage("⚠️ \(service.uppercased()): Not configured", type: .warning)
            }
        }
    }
    
    private func saveApiKey() {
        guard !apiKeyInput.isEmpty else {
            addDebugMessage("❌ Please enter an API key", type: .error)
            return
        }
        
        addDebugMessage("Saving API key for \(selectedService.uppercased())...", type: .info)
        
        if keychainService.saveApiKey(apiKeyInput, forService: selectedService) {
            addDebugMessage("✅ API key saved successfully", type: .success)
            addDebugMessage("Service: \(selectedService.uppercased())", type: .info)
            addDebugMessage("Key: \(maskApiKey(apiKeyInput))", type: .info)
        } else {
            addDebugMessage("❌ Failed to save API key", type: .error)
        }
        
        apiKeyInput = ""
    }
    
    private func clearKeychain() {
        addDebugMessage("Clearing API keys...", type: .warning)
        
        var allCleared = true
        for service in knownServices {
            if keychainService.deleteApiKey(forService: service) {
                addDebugMessage("✅ Cleared \(service.uppercased())", type: .success)
            } else {
                addDebugMessage("❌ Failed to clear \(service.uppercased())", type: .error)
                allCleared = false
            }
        }
        
        if allCleared {
            addDebugMessage("✅ All API keys cleared", type: .success)
        } else {
            addDebugMessage("⚠️ Some keys could not be cleared", type: .warning)
        }
    }
    
    private func migrateFromUserDefaults() {
        addDebugMessage("Starting migration from UserDefaults...", type: .info)
        keychainService.migrateApiKeysFromUserDefaults()
        addDebugMessage("Migration complete", type: .success)
        checkKeychainItems()
    }
    
    private func maskApiKey(_ key: String) -> String {
        guard key.count > 6 else { return "***" }
        return String(key.prefix(3)) + "..." + String(key.suffix(3))
    }
    
    // MARK: - Animation Preview Component
    
    struct AnimationPreviewView: UIViewRepresentable {
        var animationName: String
        var onFailure: () -> Void
        private let logger = Logger(subsystem: "com.saxobroko.saxweather", category: "Debug")
        
        func makeUIView(context: Context) -> UIView {
            let containerView = UIView()
            containerView.backgroundColor = .clear
            
            // Add a label to show what we're trying to load
            let loadingLabel = UILabel()
            loadingLabel.text = "Loading: \(animationName)"
            loadingLabel.textAlignment = .center
            loadingLabel.textColor = .darkGray
            loadingLabel.font = UIFont.systemFont(ofSize: 12)
            loadingLabel.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(loadingLabel)
            
            NSLayoutConstraint.activate([
                loadingLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
                loadingLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
            ])
            
            // Create animation view
            let animationView = LottieAnimationView()
            animationView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(animationView)
            
            NSLayoutConstraint.activate([
                animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                animationView.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 4),
                animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            logger.debug("Attempting to load animation: \(animationName)")
            tryLoadAnimation(animationView, containerView)
            
            return containerView
        }
        
        private func tryLoadAnimation(_ animationView: LottieAnimationView, _ containerView: UIView) {
            // Method 1: Try direct named loading
            if let animation = LottieAnimation.named(animationName) {
                logger.debug("Successfully loaded \(animationName) using direct naming")
                setupAnimation(animationView, animation)
                return
            }
            
            // Method 2: Try with explicit bundle
            if let animation = LottieAnimation.named(animationName, bundle: Bundle.main) {
                logger.debug("Successfully loaded \(animationName) with explicit bundle")
                setupAnimation(animationView, animation)
                return
            }
            
            // Method 3: Try loading from .lottie file as data
            if let url = Bundle.main.url(forResource: animationName, withExtension: "lottie"),
               let data = try? Data(contentsOf: url),
               let animation = try? LottieAnimation.from(data: data) {
                logger.debug("Successfully loaded \(animationName).lottie as data")
                setupAnimation(animationView, animation)
                return
            }
            
            // Method 4: Try loading from .json file as data
            if let url = Bundle.main.url(forResource: animationName, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let animation = try? LottieAnimation.from(data: data) {
                logger.debug("Successfully loaded \(animationName).json as data")
                setupAnimation(animationView, animation)
                return
            }
            
            // If we get here, all methods failed
            logger.error("All loading methods failed for: \(animationName)")
            showFailureIndicator(containerView)
            DispatchQueue.main.async {
                self.onFailure()
            }
        }
        
        private func setupAnimation(_ animationView: LottieAnimationView, _ animation: LottieAnimation) {
            animationView.animation = animation
            animationView.loopMode = .loop
            animationView.contentMode = .scaleAspectFit
            animationView.play()
        }
        
        private func showFailureIndicator(_ containerView: UIView) {
            let errorLabel = UILabel()
            errorLabel.text = "Failed to load animation"
            errorLabel.textAlignment = .center
            errorLabel.textColor = .red
            errorLabel.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(errorLabel)
            
            NSLayoutConstraint.activate([
                errorLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                errorLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])
        }
        
        func updateUIView(_ uiView: UIView, context: Context) {
            // Nothing to update - view is recreated with new ID when animation changes
        }
    }
    
    // MARK: - Document Exporter
    
    struct DocumentExporterView: UIViewControllerRepresentable {
        let data: Data
        let filename: String
        
        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            
            do {
                try data.write(to: tempURL)
            } catch {
                print("Error writing temp file: \(error)")
            }
            
            let controller = UIDocumentPickerViewController(forExporting: [tempURL])
            return controller
        }
        
        func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
            // Nothing to update
        }
    }
}

#endif
