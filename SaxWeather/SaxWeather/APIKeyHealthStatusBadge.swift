//
//  APIKeyHealthStatusBadge.swift
//  SaxWeather
//
//  Reusable SwiftUI components for surfacing API key health
//  information to the user. Shown inline in Settings next to
//  each provider, and as a banner on the main weather screen
//  when at least one key is known to be invalid.
//
//  Created: 2026-06-16
//

import SwiftUI

/// Compact indicator (icon + colour) that summarises the health
/// of a single API key.
struct APIKeyHealthStatusBadge: View {
    let entry: APIKeyHealthEntry
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .foregroundColor(tint)
                .font(compact ? .caption : .subheadline)
            if !compact {
                Text(label)
                    .font(.caption)
                    .foregroundColor(tint)
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("API key status: \(label). \(entry.detail ?? "")")
    }

    private var iconName: String {
        switch entry.status {
        case .unknown:       return "questionmark.circle"
        case .valid:         return "checkmark.seal.fill"
        case .invalid:       return "xmark.octagon.fill"
        case .quotaExceeded: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch entry.status {
        case .unknown:       return .secondary
        case .valid:         return .green
        case .invalid:       return .red
        case .quotaExceeded: return .orange
        }
    }

    private var label: String {
        switch entry.status {
        case .unknown:       return String(localized: "Untested")
        case .valid:         return String(localized: "Verified")
        case .invalid:       return String(localized: "Invalid")
        case .quotaExceeded: return String(localized: "Quota exceeded")
        }
    }
}

/// A more detailed card showing the status, last-checked time,
/// detail message and a "Re-test" button. Designed to sit inside
/// a settings section.
struct APIKeyHealthCard: View {
    @ObservedObject var monitor: APIKeyHealthMonitor
    let service: APIKeyService
    @ObservedObject var weatherService: WeatherService
    @State private var isValidating = false
    @State private var lastValidation: WeatherService.APIKeyValidationResult?

    var body: some View {
        let entry = monitor.entry(for: service)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                APIKeyHealthStatusBadge(entry: entry)
                Spacer()
                Button {
                    Task { await runValidation() }
                } label: {
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Re-test", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isValidating || !hasStoredKey)
            }

            if let detail = detailToShow {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if entry.lastChecked > .distantPast {
                Text("Last checked \(entry.lastChecked, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var hasStoredKey: Bool {
        KeychainService.shared.hasApiKey(forService: service.rawValue)
    }

    private var detailToShow: String? {
        if let result = lastValidation {
            switch result {
            case .valid(let detail):
                return "✅ \(detail)"
            case .invalid(let detail, _):
                return "❌ \(detail)"
            case .quotaExceeded(let detail):
                return "⚠️ \(detail)"
            case .unknown:
                return "No key configured."
            }
        }
        return monitor.entry(for: service).detail
    }

    @MainActor
    private func runValidation() async {
        isValidating = true
        defer { isValidating = false }
        let result = await weatherService.validateAPIKey(for: service)
        lastValidation = result
    }
}

/// Banner shown at the top of the main weather view whenever at
/// least one stored key is flagged as invalid.
struct APIKeyHealthBanner: View {
    @ObservedObject var monitor: APIKeyHealthMonitor
    var onTap: () -> Void = {}

    var body: some View {
        if monitor.hasAnyBlockingIssue {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "key.slash")
                        .font(.title3)
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("API key needs attention")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        Text(detailLine)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.red.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.85), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var detailLine: String {
        let services = monitor.blockingServices.map(\.displayName).joined(separator: ", ")
        if services.isEmpty { return "One or more API keys are no longer valid." }
        return "\(services) rejected the stored key. Tap to update it in Settings."
    }
}
