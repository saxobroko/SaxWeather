import SwiftUI
import Lottie
import UniformTypeIdentifiers

struct LottieDebugView: View {
    @State private var debugMessages: [String] = []
    @State private var selectedAnimation = "clear-day"
    @State private var showingFileExport = false
    @State private var exportData: Data?
    @State private var exportFilename = ""
    @State private var previewFailed = false
    @State private var refreshID = UUID() // Used to force view refresh
    
    // List matches your actual files in the bundle
    let availableAnimations = [
        "clear-day", "clear-night", "partly-cloudy", "partly-cloudy-night",
        "cloudy", "rainy", "thunderstorm", "foggy"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Animation selection
                    Picker("Animation", selection: $selectedAnimation) {
                        ForEach(availableAnimations, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    .padding(.top)
                    .onChange(of: selectedAnimation) { newValue in
                        // Reset preview state and force refresh when selection changes
                        previewFailed = false
                        refreshID = UUID() // Force view refresh
                        debugMessages = ["Selected animation: \(newValue)"]
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
                                // Use the refreshID to force view recreation
                                AnimationPreviewView(
                                    animationName: selectedAnimation,
                                    onFailure: { previewFailed = true }
                                )
                                .id(refreshID)
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                    
                    // Control buttons
                    HStack(spacing: 16) {
                        Button("Check File") { checkFileExists() }
                            .buttonStyle(.bordered)
                        
                        Button("Deep Inspect") { deepInspectFile() }
                            .buttonStyle(.bordered)
                        
                        Button("List All Files") { listAllFiles() }
                            .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    // Debug messages
                    VStack(alignment: .leading) {
                        Text("Debug Information")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(debugMessages, id: \.self) { message in
                                    Text(message)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal)
                                        .textSelection(.enabled)
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
            // Initialize with information about the selected animation
            checkFileExists()
        }
    }
    
    private func checkFileExists() {
        debugMessages = ["Checking for \(selectedAnimation)..."]
        
        // Check .lottie file
        if let url = Bundle.main.url(forResource: selectedAnimation, withExtension: "lottie") {
            debugMessages.append("✅ \(selectedAnimation).lottie exists at:")
            debugMessages.append(url.path)
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? Int {
                    debugMessages.append("File size: \(fileSize) bytes")
                }
            } catch {
                debugMessages.append("Error getting file attributes: \(error.localizedDescription)")
            }
        } else {
            debugMessages.append("❌ \(selectedAnimation).lottie not found")
        }
        
        // Check JSON file
        if let url = Bundle.main.url(forResource: selectedAnimation, withExtension: "json") {
            debugMessages.append("✅ \(selectedAnimation).json exists")
        } else {
            debugMessages.append("❌ \(selectedAnimation).json not found")
        }
    }
    
    private func deepInspectFile() {
        debugMessages = ["Deep inspecting \(selectedAnimation).lottie..."]
        
        guard let url = Bundle.main.url(forResource: selectedAnimation, withExtension: "lottie") else {
            debugMessages.append("❌ File not found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            debugMessages.append("File size: \(data.count) bytes")
            
            // Check if it's a ZIP file
            let isZip = data.prefix(4).map { $0 } == [0x50, 0x4B, 0x03, 0x04]
            debugMessages.append("Is ZIP file: \(isZip)")
            
            if !isZip {
                // Try to parse as JSON
                if let jsonString = String(data: data, encoding: .utf8) {
                    debugMessages.append("Content appears to be text/JSON")
                    if jsonString.count > 100 {
                        debugMessages.append("First 100 chars: \(jsonString.prefix(100))...")
                    } else {
                        debugMessages.append("Content: \(jsonString)")
                    }
                    
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        debugMessages.append("✅ Valid JSON structure")
                        
                        // Check for critical Lottie properties
                        if let dict = json as? [String: Any] {
                            let hasVersion = dict["v"] != nil
                            let hasLayers = dict["layers"] != nil
                            debugMessages.append("Has version: \(hasVersion)")
                            debugMessages.append("Has layers: \(hasLayers)")
                            
                            if hasVersion && hasLayers {
                                debugMessages.append("✅ File appears to be valid Lottie JSON")
                            } else {
                                debugMessages.append("❌ Missing essential Lottie properties")
                            }
                        }
                    } catch {
                        debugMessages.append("❌ Invalid JSON: \(error.localizedDescription)")
                    }
                } else {
                    debugMessages.append("❌ Not valid UTF-8 text")
                    debugMessages.append("First 10 bytes: \(data.prefix(10).map { String(format: "%02X", $0) }.joined(separator: " "))")
                }
            }
        } catch {
            debugMessages.append("❌ Error reading file: \(error.localizedDescription)")
        }
    }
    
    private func listAllFiles() {
        debugMessages = ["Listing all animation files in bundle:"]
        
        let lottieFiles = Bundle.main.paths(forResourcesOfType: "lottie", inDirectory: nil)
        debugMessages.append("\n📂 .lottie files (\(lottieFiles.count) found):")
        for path in lottieFiles {
            let filename = URL(fileURLWithPath: path).lastPathComponent
            debugMessages.append("- \(filename)")
        }
        
        let jsonFiles = Bundle.main.paths(forResourcesOfType: "json", inDirectory: nil)
        debugMessages.append("\n📂 .json files (\(jsonFiles.count) found):")
        for path in jsonFiles {
            let filename = URL(fileURLWithPath: path).lastPathComponent
            debugMessages.append("- \(filename)")
        }
        
        if lottieFiles.isEmpty && jsonFiles.isEmpty {
            debugMessages.append("No animation files found in bundle")
        }
    }
}

// Animation preview component - enhanced for reliability
struct AnimationPreviewView: UIViewRepresentable {
    var animationName: String
    var onFailure: () -> Void
    
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
        
        // Create a LottieAnimationView
        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 4),
            animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        #if DEBUG
        print("🔍 Attempting to load animation: \(animationName)")
        #endif
        
        // Try multiple loading methods in sequence for maximum compatibility
        tryLoadAnimation(animationView, containerView)
        
        return containerView
    }
    
    private func tryLoadAnimation(_ animationView: LottieAnimationView, _ containerView: UIView) {
        // Method 1: Try direct named loading
        if let animation = LottieAnimation.named(animationName) {
            #if DEBUG
            print("✅ Method 1: Successfully loaded \(animationName) using direct naming")
            #endif
            setupAnimation(animationView, animation)
            return
        }
        
        // Method 2: Try with explicit bundle
        if let animation = LottieAnimation.named(animationName, bundle: Bundle.main) {
            #if DEBUG
            print("✅ Method 2: Successfully loaded \(animationName) with explicit bundle")
            #endif
            setupAnimation(animationView, animation)
            return
        }
        
        // Method 3: Try loading from .lottie file as data
        if let url = Bundle.main.url(forResource: animationName, withExtension: "lottie") {
            #if DEBUG
            print("🔍 Found \(animationName).lottie, trying to load...")
            #endif
            do {
                let data = try Data(contentsOf: url)
                if let animation = try? LottieAnimation.from(data: data) {
                    #if DEBUG
                    print("✅ Method 3: Successfully loaded \(animationName).lottie as data")
                    #endif
                    setupAnimation(animationView, animation)
                    return
                }
            } catch {
                #if DEBUG
                print("❌ Error loading .lottie data: \(error.localizedDescription)")
                #endif
            }
        }
        
        // Method 4: Try loading from .json file as data
        if let url = Bundle.main.url(forResource: animationName, withExtension: "json") {
            print("🔍 Found \(animationName).json, trying to load...")
            do {
                let data = try Data(contentsOf: url)
                if let animation = try? LottieAnimation.from(data: data) {
                    #if DEBUG
                    print("✅ Method 4: Successfully loaded \(animationName).json as data")
                    #endif
                    setupAnimation(animationView, animation)
                    return
                }
            } catch {
                #if DEBUG
                print("❌ Error loading .json data: \(error.localizedDescription)")
                #endif
            }
        }
        
        // If we get here, all methods failed
        #if DEBUG
        print("❌ All loading methods failed for: \(animationName)")
        #endif
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

// Helper view to export data
struct DocumentExporterView: UIViewControllerRepresentable {
    let data: Data
    let filename: String
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
        } catch {
            #if DEBUG
            print("Error writing temp file: \(error)")
            #endif
        }
        
        let controller = UIDocumentPickerViewController(forExporting: [tempURL])
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
