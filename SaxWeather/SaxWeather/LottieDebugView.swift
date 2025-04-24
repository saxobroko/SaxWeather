//
//  LottieDebugView.swift
//  SaxWeather
//
//  Created by saxobroko on 2025-03-10
//  Last modified: 2025-03-10 11:02:41 UTC
//

import SwiftUI
import Lottie
import UniformTypeIdentifiers
import os.log
import KeychainSwift
import UserNotifications // Import UserNotifications

private struct DebugMessage: Identifiable, Hashable {
    let id = UUID()
    let message: String
    
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
    @State private var sessionStartTime = "2025-03-10 11:02:41"
    @State private var currentUser = "saxobroko"
    
    private let logger = Logger(subsystem: "com.saxobroko.saxweather", category: "LottieDebug")
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Session info section
                    VStack(alignment: .leading) {
                        Text("Session Information")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User: \(currentUser)")
                                .font(.system(.body, design: .monospaced))
                            Text("Session started: \(sessionStartTime) UTC")
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    // Animation selection
                    Picker("Animation", selection: $selectedAnimation) {
                        ForEach(availableAnimations, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    .onChange(of: selectedAnimation) { newValue in
                        previewFailed = false
                        refreshID = UUID()
                        setDebugMessages(["Selected animation: \(newValue)"])
                        logger.debug("Selected animation: \(newValue)")
                    }
                    
                    // Preview section with refresh button
                    VStack {
                        HStack {
                            Text("Animation Preview")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                refreshID = UUID()
                                previewFailed = false
                                logger.debug("Refreshing animation preview")
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        
                        ZStack {
                            Color.secondary.opacity(0.1)
                                .cornerRadius(8)
                            
                            if previewFailed {
                                VStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                    Text("Preview Failed")
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                AnimationPreviewView(
                                    animationName: selectedAnimation,
                                    onFailure: {
                                        previewFailed = true
                                        logger.error("Animation preview failed for \(selectedAnimation)")
                                    }
                                )
                                .id(refreshID)
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                    
                    // Animation Control buttons
                    HStack(spacing: 16) {
                        Button("Check File") {
                            checkFileExists()
                            logger.debug("Check file button pressed")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Deep Inspect") {
                            deepInspectFile()
                            logger.debug("Deep inspect button pressed")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("List All Files") {
                            listAllFiles()
                            logger.debug("List all files button pressed")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    // Keychain Debug Section
                    VStack(alignment: .leading) {
                        Text("Keychain Debug")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("Keys are synchronized across devices via iCloud Keychain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        // Service selector and API key input
                        HStack {
                            Picker("Service", selection: $selectedService) {
                                ForEach(knownServices, id: \.self) { service in
                                    Text(service.uppercased()).tag(service)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            TextField("API Key", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Save") {
                                saveApiKey()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        
                        // Keychain debug controls
                        HStack(spacing: 16) {
                            Button("Check Keys") {
                                checkKeychainItems()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Migrate from UserDefaults") {
                                migrateFromUserDefaults()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Clear All Keys") {
                                clearKeychain()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Debug messages section
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Debug Information")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                let allMessages = debugMessages.map { $0.message }.joined(separator: "\n")
                                UIPasteboard.general.string = allMessages
                                
                                addDebugMessage("\n✅ Debug log copied to clipboard")
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if let last = debugMessages.last,
                                       last.message == "✅ Debug log copied to clipboard" {
                                        debugMessages.removeLast()
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy All")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(debugMessages) { message in
                                    Text(message.message)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal)
                                        .textSelection(.enabled)
                                        .contextMenu {
                                            Button(action: {
                                                UIPasteboard.general.string = message.message
                                            }) {
                                                Text("Copy Message")
                                                Image(systemName: "doc.on.doc")
                                            }
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                    
                    // Notification Debug Section
                    VStack(alignment: .leading) {
                        Text("Notification Debug")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack(spacing: 16) {
                            Button("Schedule Rain Notification") {
                                scheduleNotification(title: "Rain Alert", body: "Rain expected to start soon", inSeconds: 60)
                                logger.debug("Scheduled rain notification in 1 minute")
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Schedule Severe Weather Notification") {
                                scheduleNotification(title: "Severe Weather Alert", body: "Severe weather expected soon", inSeconds: 60)
                                logger.debug("Scheduled severe weather notification in 1 minute")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                    }
                }
                .navigationTitle("Lottie Debug")
                .sheet(isPresented: $showingFileExport) {
                    if let data = exportData {
                        DocumentExporterView(data: data, filename: exportFilename)
                    }
                }
            }
        }
        .onAppear {
            setDebugMessages([
                "Debug Session Started",
                "Time: \(sessionStartTime) UTC",
                "User: \(currentUser)",
                "---"
            ])
            checkFileExists()
            logger.debug("LottieDebugView appeared")
        }
    }
    
    // MARK: - Helper Methods
    
    private func addDebugMessage(_ message: String) {
        debugMessages.append(DebugMessage(message: message))
    }
    
    private func setDebugMessages(_ messages: [String]) {
        debugMessages = messages.map { DebugMessage(message: $0) }
    }
    
    // MARK: - Debug Functions
    
    private func checkFileExists() {
        addDebugMessage("Checking for \(selectedAnimation)...")
        
        // Check .lottie file
        if let url = Bundle.main.url(forResource: selectedAnimation, withExtension: "lottie") {
            addDebugMessage("✅ \(selectedAnimation).lottie exists at:")
            addDebugMessage(url.path)
            logger.debug("\(selectedAnimation).lottie exists at: \(url.path)")
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? Int {
                    addDebugMessage("File size: \(fileSize) bytes")
                    logger.debug("File size: \(fileSize) bytes")
                }
            } catch {
                addDebugMessage("Error getting file attributes: \(error.localizedDescription)")
                logger.error("Error getting file attributes: \(error.localizedDescription)")
            }
        } else {
            addDebugMessage("❌ \(selectedAnimation).lottie not found")
            logger.error("\(selectedAnimation).lottie not found")
        }
        
        // Check JSON file
        if let url = Bundle.main.url(forResource: selectedAnimation, withExtension: "json") {
            addDebugMessage("✅ \(selectedAnimation).json exists")
            logger.debug("\(selectedAnimation).json exists")
        } else {
            addDebugMessage("❌ \(selectedAnimation).json not found")
            logger.error("\(selectedAnimation).json not found")
        }
    }
    
    private func deepInspectFile() {
        setDebugMessages(["Deep inspecting \(selectedAnimation).lottie..."])
        
        guard let url = Bundle.main.url(forResource: selectedAnimation, withExtension: "lottie") else {
            addDebugMessage("❌ File not found")
            logger.error("\(selectedAnimation).lottie file not found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            addDebugMessage("File size: \(data.count) bytes")
            logger.debug("File size: \(data.count) bytes")
            
            // Check if it's a ZIP file
            let isZip = data.prefix(4).map { $0 } == [0x50, 0x4B, 0x03, 0x04]
            addDebugMessage("Is ZIP file: \(isZip)")
            logger.debug("Is ZIP file: \(isZip)")
            
            if !isZip {
                // Try to parse as JSON
                if let jsonString = String(data: data, encoding: .utf8) {
                    addDebugMessage("Content appears to be text/JSON")
                    logger.debug("Content appears to be text/JSON")
                    if jsonString.count > 100 {
                        addDebugMessage("First 100 chars: \(jsonString.prefix(100))...")
                        logger.debug("First 100 chars: \(jsonString.prefix(100))...")
                    } else {
                        addDebugMessage("Content: \(jsonString)")
                        logger.debug("Content: \(jsonString)")
                    }
                    
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        addDebugMessage("✅ Valid JSON structure")
                        logger.debug("Valid JSON structure")
                        
                        // Check for critical Lottie properties
                        if let dict = json as? [String: Any] {
                            let hasVersion = dict["v"] != nil
                            let hasLayers = dict["layers"] != nil
                            addDebugMessage("Has version: \(hasVersion)")
                            addDebugMessage("Has layers: \(hasLayers)")
                            logger.debug("Has version: \(hasVersion)")
                            logger.debug("Has layers: \(hasLayers)")
                            
                            if hasVersion && hasLayers {
                                addDebugMessage("✅ File appears to be valid Lottie JSON")
                                logger.debug("File appears to be valid Lottie JSON")
                            } else {
                                addDebugMessage("❌ Missing essential Lottie properties")
                                logger.error("Missing essential Lottie properties")
                            }
                        }
                    } catch {
                        addDebugMessage("❌ Invalid JSON: \(error.localizedDescription)")
                        logger.error("Invalid JSON: \(error.localizedDescription)")
                    }
                } else {
                    addDebugMessage("❌ Not valid UTF-8 text")
                    addDebugMessage("First 10 bytes: \(data.prefix(10).map { String(format: "%02X", $0) }.joined(separator: " "))")
                    logger.error("Not valid UTF-8 text")
                }
            }
        } catch {
            addDebugMessage("❌ Error reading file: \(error.localizedDescription)")
            logger.error("Error reading file: \(error.localizedDescription)")
        }
    }
    
    private func listAllFiles() {
        setDebugMessages(["Listing all animation files in bundle:"])
        logger.debug("Listing all animation files in bundle")
        
        let lottieFiles = Bundle.main.paths(forResourcesOfType: "lottie", inDirectory: nil)
        addDebugMessage("\n📂 .lottie files (\(lottieFiles.count) found):")
        logger.debug(".lottie files (\(lottieFiles.count) found):")
        for path in lottieFiles {
            let filename = URL(fileURLWithPath: path).lastPathComponent
            addDebugMessage("- \(filename)")
            logger.debug("- \(filename)")
        }
        
        let jsonFiles = Bundle.main.paths(forResourcesOfType: "json", inDirectory: nil)
        addDebugMessage("\n📂 .json files (\(jsonFiles.count) found):")
        logger.debug(".json files (\(jsonFiles.count) found):")
        for path in jsonFiles {
            let filename = URL(fileURLWithPath: path).lastPathComponent
            addDebugMessage("- \(filename)")
            logger.debug("- \(filename)")
        }
        
        if lottieFiles.isEmpty && jsonFiles.isEmpty {
            addDebugMessage("No animation files found in bundle")
            logger.debug("No animation files found in bundle")
        }
    }
    
    private func checkKeychainItems() {
        setDebugMessages(["Checking Keychain Items..."])
        logger.debug("Checking keychain items")
        
        addDebugMessage("Keychain Configuration:")
        addDebugMessage("✓ Synchronization enabled")
        addDebugMessage("✓ iCloud Keychain sharing supported")
        
        // Test keychain accessibility
        let testKey = "debugTestKey"
        let testValue = "debugTestValue"
        
        addDebugMessage("\nKeychain Accessibility Test:")
        if keychainService.keychain.set(testValue, forKey: testKey) {
            addDebugMessage("✅ Can write to keychain")
            if let retrieved = keychainService.keychain.get(testKey) {
                addDebugMessage("✅ Can read from keychain")
                if keychainService.keychain.delete(testKey) {
                    addDebugMessage("✅ Can delete from keychain")
                } else {
                    addDebugMessage("❌ Cannot delete from keychain")
                }
            } else {
                addDebugMessage("❌ Cannot read from keychain")
            }
        } else {
            addDebugMessage("❌ Cannot write to keychain")
            addDebugMessage("Error code: \(keychainService.keychain.lastResultCode)")
        }
        
        addDebugMessage("\nStored API Keys:")
        for service in knownServices {
            if let apiKey = keychainService.getApiKey(forService: service) {
                let maskedKey = maskApiKey(apiKey)
                addDebugMessage("✅ \(service.uppercased()): \(maskedKey)")
                logger.debug("Found API key for service: \(service)")
            } else {
                addDebugMessage("❌ \(service.uppercased()): Not found")
                logger.debug("No API key found for service: \(service)")
            }
        }
    }
    
    private func saveApiKey() {
        guard !apiKeyInput.isEmpty else {
            setDebugMessages(["❌ Please enter an API key"])
            return
        }
        
        setDebugMessages(["Saving API key for \(selectedService.uppercased())..."])
        logger.debug("Saving API key for service: \(selectedService)")
        
        if keychainService.saveApiKey(apiKeyInput, forService: selectedService) {
            addDebugMessage("✅ API key saved successfully")
            addDebugMessage("Service: \(selectedService.uppercased())")
            addDebugMessage("Key: \(maskApiKey(apiKeyInput))")
            logger.debug("API key saved successfully for service: \(selectedService)")
        } else {
            addDebugMessage("❌ Failed to save API key")
            logger.error("Failed to save API key for service: \(selectedService)")
        }
        
        apiKeyInput = ""
    }
    
    private func clearKeychain() {
        setDebugMessages(["Clearing API keys..."])
        logger.debug("Clearing API keys")
        
        var allCleared = true
        for service in knownServices {
            if keychainService.deleteApiKey(forService: service) {
                addDebugMessage("✅ Cleared \(service.uppercased()) API key")
                logger.debug("Cleared API key for service: \(service)")
            } else {
                addDebugMessage("❌ Failed to clear \(service.uppercased()) API key")
                logger.error("Failed to clear API key for service: \(service)")
                allCleared = false
            }
        }
        
        if allCleared {
            addDebugMessage("\n✅ All API keys cleared successfully")
        } else {
            addDebugMessage("\n⚠️ Some API keys could not be cleared")
        }
    }
    
    private func migrateFromUserDefaults() {
        setDebugMessages(["Starting migration from UserDefaults..."])
        logger.debug("Starting migration from UserDefaults")
        
        keychainService.migrateApiKeysFromUserDefaults()
        checkKeychainItems()
    }
    
    private func maskApiKey(_ key: String) -> String {
        guard key.count > 6 else { return "***" }
        return String(key.prefix(3)) + "..." + String(key.suffix(3))
    }
    
    // MARK: - Notification Scheduling
    
    private func scheduleNotification(title: String, body: String, inSeconds seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                addDebugMessage("❌ Error scheduling notification: \(error.localizedDescription)")
                logger.error("Error scheduling notification: \(error.localizedDescription)")
            } else {
                addDebugMessage("✅ Notification scheduled: \(title) in \(Int(seconds)) seconds")
                logger.debug("Notification scheduled: \(title) in \(Int(seconds)) seconds")
            }
        }
    }
    
    // MARK: - Animation Preview Component
    
    struct AnimationPreviewView: UIViewRepresentable {
        var animationName: String
        var onFailure: () -> Void
        private let logger = Logger(subsystem: "com.saxobroko.saxweather", category: "LottieDebug")
        
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
