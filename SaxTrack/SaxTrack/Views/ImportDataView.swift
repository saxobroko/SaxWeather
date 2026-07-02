//
//  ImportDataView.swift
//  SaxTrack
//
//  Created on 7/1/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportDataView: View {
    @Bindable var viewModel: FollowerTrackingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var importType: ImportType = .followers
    @State private var showingFilePicker = false
    @State private var showingManualEntry = false
    @State private var manualText = ""
    
    enum ImportType {
        case followers
        case following
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Import Instagram Data")
                            .font(.title2.bold())
                        
                        Text("Choose what you'd like to import")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Import Type Picker
                    Picker("Import Type", selection: $importType) {
                        Text("Followers").tag(ImportType.followers)
                        Text("Following").tag(ImportType.following)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Instructions
                    instructionsCard
                    
                    // Import Options
                    VStack(spacing: 16) {
                        Button {
                            showingManualEntry = true
                        } label: {
                            Label("Manual Entry", systemImage: "text.cursor")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.gradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button {
                            importSampleData()
                        } label: {
                            Label("Import Sample Data", systemImage: "person.3.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.purple.gradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView(importType: importType, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Instructions Card
    
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("How to Export from Instagram", systemImage: "info.circle.fill")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                InstructionStep(number: 1, text: "Open Instagram → Settings → Privacy")
                InstructionStep(number: 2, text: "Download Your Information → Request Download")
                InstructionStep(number: 3, text: "Select 'Some of your information'")
                InstructionStep(number: 4, text: "Check 'Followers' and 'Following'")
                InstructionStep(number: 5, text: "Wait for the download link (can take up to 48 hours)")
            }
            
            Text("For now, you can manually enter usernames or use sample data for testing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .glassCard()
        .padding(.horizontal)
    }
    
    // MARK: - Sample Data
    
    private func importSampleData() {
        Task {
            let sampleFollowers = [
                "user1", "user2", "user3", "user4", "user5",
                "user6", "user7", "user8", "user9", "user10"
            ]
            
            let sampleFollowing = [
                "user1", "user2", "user3", "user11", "user12",
                "user13", "user14", "user15", "user16", "user17"
            ]
            
            if importType == .followers {
                await viewModel.importFollowers(sampleFollowers)
            } else {
                await viewModel.importFollowing(sampleFollowing)
            }
            
            dismiss()
        }
    }
}

// MARK: - Instruction Step

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.blue.gradient)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Manual Entry View

struct ManualEntryView: View {
    let importType: ImportDataView.ImportType
    @Bindable var viewModel: FollowerTrackingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isImporting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter one username per line")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $text)
                    .frame(maxHeight: .infinity)
                    .padding(8)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
                    }
                
                Button {
                    importManualData()
                } label: {
                    if isImporting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Import \(getUsernames().count) Users")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(getUsernames().isEmpty ? Color.gray : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(getUsernames().isEmpty || isImporting)
            }
            .padding()
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getUsernames() -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func importManualData() {
        isImporting = true
        let usernames = getUsernames()
        
        Task {
            if importType == .followers {
                await viewModel.importFollowers(usernames)
            } else {
                await viewModel.importFollowing(usernames)
            }
            
            dismiss()
        }
    }
}

#Preview {
    ImportDataView(viewModel: FollowerTrackingViewModel(modelContext: ModelContext(try! ModelContainer(for: InstagramUser.self, FollowerSnapshot.self, FollowerChange.self))))
}
