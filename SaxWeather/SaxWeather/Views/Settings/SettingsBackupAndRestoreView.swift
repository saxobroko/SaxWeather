
import SwiftUI
import UniformTypeIdentifiers

struct SettingsBackupAndRestoreView: View {
    @EnvironmentObject private var customisation: CustomisationRegistry
    @StateObject private var iCloud = iCloudSyncService.shared

    @State private var showingProfileImporter = false

    var body: some View {
        List {
            backupSection
            restoreSection
            iCloudSection
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Backup & Restore")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingProfileImporter) {
            ProfileImporterView()
        }
    }

    // MARK: - Backup

    private var backupSection: some View {
        Section {
            Button {
                showingProfileImporter = true
            } label: {
                Label("Back Up & Share Settings…", systemImage: "square.and.arrow.up.on.square")
            }
            .buttonStyle(.plain)
        } header: {
            Text("Backup")
        } footer: {
            Text("Export your current settings as a .saxtheme file. You can AirDrop it, save it to Files, or share it any other way.")
        }
    }

    // MARK: - Restore

    private var restoreSection: some View {
        Section {
            Button {
                showingProfileImporter = true
            } label: {
                Label("Restore from .saxtheme File…", systemImage: "square.and.arrow.down.on.square")
            }
            .buttonStyle(.plain)
        } header: {
            Text("Restore")
        } footer: {
            Text("Import a .saxtheme file from Files, AirDrop, or another app. Your current settings will be replaced.")
        }
    }

    // MARK: - iCloud Sync

    private var iCloudSection: some View {
        Section {
            Toggle(isOn: $iCloud.isEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync Settings via iCloud")
                        Text(iCloud.status.displayLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "icloud")
                        .foregroundStyle(.tint)
                }
            }

            if iCloud.isEnabled {
                if let lastSynced = iCloud.lastSyncedAt {
                    HStack {
                        Label("Last Synced", systemImage: "clock")
                        Spacer()
                        Text(lastSynced, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    iCloud.forcePull { remote in
                        customisation.apply(remote)
                    }
                } label: {
                    Label("Restore from iCloud Now", systemImage: "arrow.counterclockwise.icloud")
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    iCloud.deleteRemoteBackup()
                } label: {
                    Label("Remove iCloud Backup", systemImage: "trash")
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text(iCloudFooterText)
        }
    }

    private var iCloudFooterText: String {
        if iCloud.isEnabled {
            switch iCloud.status {
            case .unavailable(let reason):
                return reason
            case .error(let reason):
                return reason
            default:
                return "Your settings are mirrored to iCloud and will follow you to every device signed in to the same account."
            }
        } else {
            return "Turn on iCloud sync to automatically mirror your settings across every device signed in to the same iCloud account."
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsBackupAndRestoreView()
            .navigationTitle("Settings")
    }
    .environmentObject(CustomisationRegistry(testProfile: .makeDefault()))
}