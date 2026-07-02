// FileImportView.swift
// Enhanced import with JSON file support, clipboard detection, and drag & drop

import SwiftUI
import UniformTypeIdentifiers

struct FileImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: FollowerTrackingViewModel
    
    @State private var isImporting = false
    @State private var importType: ImportType = .followers
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var importedCount = 0
    
    // Clipboard
    @State private var clipboardData: ShortcutIntegrationService.ClipboardData?
    @State private var showClipboardPrompt = false
    
    // File picker
    @State private var showFilePicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    headerSection
                    
                    // Import Type Picker
                    importTypePicker
                    
                    // Clipboard Detection
                    if let clipboard = clipboardData {
                        clipboardPromptCard(clipboard)
                    }
                    
                    // Import Options
                    importOptionsSection
                    
                    // Instructions
                    instructionsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Successful", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Imported \(importedCount) users successfully!")
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await checkClipboard()
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.bounce, value: isImporting)
            
            Text("Import Instagram Data")
                .font(.title2.bold())
            
            Text("Choose your preferred import method")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private var importTypePicker: some View {
        Picker("Import Type", selection: $importType) {
            Text("Followers").tag(ImportType.followers)
            Text("Following").tag(ImportType.following)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private func clipboardPromptCard(_ clipboard: ShortcutIntegrationService.ClipboardData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Detected in Clipboard")
                        .font(.headline)
                    Text("\(clipboard.usernames.count) usernames found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                Button {
                    importFromClipboard(clipboard)
                } label: {
                    Label("Import", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    clipboardData = nil
                } label: {
                    Label("Dismiss", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .glassCard()
        .padding(.horizontal)
    }
    
    private var importOptionsSection: some View {
        VStack(spacing: 16) {
            Text("Import Methods")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // JSON File Import
            ImportOptionCard(
                icon: "doc.fill",
                iconColor: .blue,
                title: "Instagram Export File",
                description: "Import from Instagram's official data export (JSON)",
                badge: "Recommended"
            ) {
                showFilePicker = true
            }
            
            // Manual Entry
            ImportOptionCard(
                icon: "keyboard.fill",
                iconColor: .purple,
                title: "Manual Entry",
                description: "Type or paste usernames directly",
                badge: nil
            ) {
                // Navigate to existing manual import
                dismiss()
            }
            
            // Sample Data
            ImportOptionCard(
                icon: "sparkles",
                iconColor: .orange,
                title: "Sample Data",
                description: "Generate test data to try the app",
                badge: "Demo"
            ) {
                importSampleData()
            }
        }
        .padding(.horizontal)
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Get Instagram Data")
                .font(.headline)
            
            InstructionStep(number: 1, text: "Go to Instagram Settings → Security → Download Data")
            InstructionStep(number: 2, text: "Request a download (arrives in 1-48 hours)")
            InstructionStep(number: 3, text: "Extract the ZIP file")
            InstructionStep(number: 4, text: "Find 'followers_1.json' and 'following.json'")
            InstructionStep(number: 5, text: "Import those files here")
            
            Link(destination: URL(string: "https://help.instagram.com/181231772500920")!) {
                Label("Instagram Help Guide", systemImage: "safari")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .glassCard()
        .padding(.horizontal)
    }
    
    // MARK: - Import Logic
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importFromFile(url)
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func importFromFile(_ url: URL) {
        isImporting = true
        
        Task {
            do {
                let data = try Data(contentsOf: url)
                let parsed = try InstagramJSONParser.autoParseUsernames(from: data)
                
                // Use detected type or user's selection
                let finalType: ImportType = parsed.type == .followers ? .followers : .following
                
                await MainActor.run {
                    importUsernames(parsed.usernames, type: finalType)
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isImporting = false
                }
            }
        }
    }
    
    private func importFromClipboard(_ clipboard: ShortcutIntegrationService.ClipboardData) {
        let finalType = clipboard.type ?? importType
        importUsernames(clipboard.usernames, type: finalType)
        clipboardData = nil
    }
    
    private func importUsernames(_ usernames: [String], type: ImportType) {
        isImporting = true
        
        Task {
            switch type {
            case .followers:
                await viewModel.importFollowers(usernames)
            case .following:
                await viewModel.importFollowing(usernames)
            }
            
            await MainActor.run {
                importedCount = usernames.count
                showSuccess = true
                isImporting = false
            }
        }
    }
    
    private func importSampleData() {
        let sampleUsernames = [
            "sample_user_1", "sample_user_2", "sample_user_3",
            "test_account", "demo_profile", "example_user",
            "instagram_fan", "photo_lover", "travel_gram",
            "food_enthusiast"
        ]
        
        importUsernames(sampleUsernames, type: importType)
    }
    
    private func checkClipboard() async {
        clipboardData = await ShortcutIntegrationService.shared.detectInstagramDataInClipboard()
    }
    
    // MARK: - Supporting Types
    
    enum ImportType {
        case followers
        case following
    }
}

// MARK: - Supporting Views

struct ImportOptionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.gradient)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.2))
                                .foregroundStyle(.blue)
                                .cornerRadius(8)
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue.gradient))
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    FileImportView(viewModel: FollowerTrackingViewModel(modelContext: .init()))
}
