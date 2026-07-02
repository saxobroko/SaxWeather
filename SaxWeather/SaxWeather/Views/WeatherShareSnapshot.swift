//
//  WeatherShareSnapshot.swift
//  SaxWeather
//
//  Renders a styled weather card image for sharing via the
//  system share sheet (summary mode).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import Photos
import LinkPresentation
import UniformTypeIdentifiers
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Snapshot data

struct WeatherShareSnapshotData {
    let locationName: String
    let condition: String
    let temperature: String
    let feelsLike: String?
    let rainOutlook: String?
    let isNight: Bool

    static func make(
        weather: Weather,
        locationName: String,
        unitSystem: String
    ) -> WeatherShareSnapshotData? {
        guard let temperature = weather.temperature else { return nil }

        let unit = UnitSystem.from(rawValue: unitSystem)
        let unitSymbol = unit.temperatureLabel
        let tempText = String(format: "%.1f%@", temperature, unitSymbol)
        let feelsText = weather.feelsLike.map {
            String(format: "Feels like %.1f%@", $0, unitSymbol)
        }

        let hours = weather.hourlyPrecipitation.map {
            (hour: $0.hour, probability: $0.probability)
        }
        let rainOutlook = rainOutlookLine(
            hours: hours,
            timeZoneIdentifier: weather.locationTimeZoneIdentifier
        )

        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour < 6 || hour > 18

        return WeatherShareSnapshotData(
            locationName: locationName,
            condition: weather.condition,
            temperature: tempText,
            feelsLike: feelsText,
            rainOutlook: rainOutlook,
            isNight: isNight
        )
    }

    private static func rainOutlookLine(
        hours: [(hour: Date, probability: Int)],
        timeZoneIdentifier: String?
    ) -> String? {
        guard !hours.isEmpty else { return nil }

        if let nextRain = WidgetRainLine.nextSignificantRain(
            hours: hours,
            timeZoneIdentifier: timeZoneIdentifier
        ) {
            return WidgetRainLine.format(nextRain, timeZoneIdentifier: timeZoneIdentifier)
        }

        let maxProbability = hours.map(\.probability).max() ?? 0
        if maxProbability > 0 {
            return "Up to \(maxProbability)% chance of rain in the next 24h"
        }
        return "No rain expected in the next 24h"
    }
}

// MARK: - Share card view

struct WeatherShareSnapshotCard: View {
    let data: WeatherShareSnapshotData

    private var symbolName: String {
        AnimationRegistry.shared.symbolName(for: data.condition, isNight: data.isNight)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.28, blue: 0.58),
                    Color(red: 0.20, green: 0.14, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Text(data.locationName)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)
                    .padding(.horizontal, 24)

                Spacer(minLength: 12)

                Image(systemName: symbolName)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 72, weight: .light))
                    .padding(.bottom, 8)

                Text(data.temperature)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(data.condition)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                if let feelsLike = data.feelsLike {
                    Text(feelsLike)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 6)
                }

                Spacer(minLength: 16)

                if let rainOutlook = data.rainOutlook {
                    HStack(spacing: 8) {
                        Image(systemName: "cloud.rain.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(rainOutlook)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 20)

                Text("SaxWeather")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 22)
            }
        }
        .frame(width: 360, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Image renderer

enum WeatherShareSnapshotRenderer {
    @MainActor
    static func renderImage(from data: WeatherShareSnapshotData) -> PlatformImage? {
        let card = WeatherShareSnapshotCard(data: data)
        let renderer = ImageRenderer(content: card)
        #if canImport(UIKit)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
        #elseif canImport(AppKit)
        return renderer.nsImage
        #else
        return nil
        #endif
    }
}

// MARK: - PNG export

enum WeatherShareSnapshotExporter {
    static func writePNG(from image: PlatformImage) -> URL? {
        #if canImport(UIKit)
        guard let data = image.pngData() else { return nil }
        #elseif canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        #else
        return nil
        #endif

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("saxweather-snapshot-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Share button

struct WeatherShareButton: View {
    let context: WeatherShareContext

    @State private var shareImage: PlatformImage?
    @State private var shareImageURL: URL?
    @State private var showingOptions = false
    @State private var showingSnapshotPreview = false
    @State private var showingLinkShare = false
    @State private var showingTextShare = false
    @State private var linkShareText = ""
    @State private var summaryShareText = ""

    var body: some View {
        Button(action: presentShareOptions) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .accessibilityLabel("Share Weather")
        .accessibilityHint("Choose how to share the current weather")
        #if os(iOS)
        .confirmationDialog("Share Weather", isPresented: $showingOptions, titleVisibility: .visible) {
            Button("Weather Snapshot") {
                presentSnapshotPreview()
            }
            if WeatherShareLinkBuilder.makePublicShareURL(from: context) != nil {
                Button("Share Location Link") {
                    linkShareText = WeatherShareLinkBuilder.makeLinkShareText(from: context)
                    showingLinkShare = true
                }
            }
            Button("Share Text Summary") {
                summaryShareText = WeatherShareLinkBuilder.summaryText(from: context)
                showingTextShare = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingSnapshotPreview) {
            if let shareImage, let shareImageURL {
                WeatherSharePreviewSheet(image: shareImage, imageURL: shareImageURL)
            }
        }
        .sheet(isPresented: $showingLinkShare) {
            ActivityShareSheet(items: [linkShareText])
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingTextShare) {
            ActivityShareSheet(items: [summaryShareText])
                .presentationDetents([.medium])
        }
        #elseif os(macOS)
        .popover(isPresented: $showingOptions, arrowEdge: .top) {
            WeatherShareOptionsMacView(
                context: context,
                onSnapshot: presentSnapshotPreview,
                onLink: {
                    linkShareText = WeatherShareLinkBuilder.makeLinkShareText(from: context)
                    showingLinkShare = true
                },
                onSummary: {
                    summaryShareText = WeatherShareLinkBuilder.summaryText(from: context)
                    showingTextShare = true
                }
            )
            .frame(width: 280)
        }
        .popover(isPresented: $showingSnapshotPreview, arrowEdge: .top) {
            if let shareImage {
                MacShareView(image: shareImage)
                    .frame(width: 320, height: 120)
            }
        }
        #endif
    }

    private func presentShareOptions() {
        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif
        showingOptions = true
    }

    private func presentSnapshotPreview() {
        guard let data = WeatherShareSnapshotData.make(
            weather: context.weather,
            locationName: context.locationName,
            unitSystem: context.unitSystem
        ) else { return }

        #if canImport(UIKit)
        HapticFeedbackHelper.shared.light()
        #endif

        guard let image = WeatherShareSnapshotRenderer.renderImage(from: data) else { return }
        guard let url = WeatherShareSnapshotExporter.writePNG(from: image) else { return }
        shareImage = image
        shareImageURL = url
        showingSnapshotPreview = true
    }
}

// MARK: - Platform share sheets

#if os(iOS)
struct WeatherSharePreviewSheet: View {
    let image: UIImage
    let imageURL: URL

    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var saveAlert: SaveAlert?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                HStack(spacing: 12) {
                    Button(action: saveToPhotos) {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: { showingShareSheet = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .navigationTitle("Share Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityShareSheet(items: [
                    WeatherShareSnapshotActivityItemSource(image: image, imageURL: imageURL)
                ])
            }
            .alert(item: $saveAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func saveToPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    saveAlert = SaveAlert(
                        title: "Photos Access Needed",
                        message: "Allow SaxWeather to save images in Settings to save this snapshot."
                    )
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        if success {
                            HapticFeedbackHelper.shared.light()
                            saveAlert = SaveAlert(
                                title: "Saved",
                                message: "The weather snapshot was saved to your photo library."
                            )
                        } else {
                            saveAlert = SaveAlert(
                                title: "Save Failed",
                                message: error?.localizedDescription ?? "Could not save the image."
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct SaveAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

final class WeatherShareSnapshotActivityItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let imageURL: URL

    init(image: UIImage, imageURL: URL) {
        self.image = image
        self.imageURL = imageURL
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        imageURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.png.identifier
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "Weather Snapshot"
        metadata.imageProvider = NSItemProvider(contentsOf: imageURL)
        return metadata
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#if os(macOS)
struct WeatherShareOptionsMacView: View {
    let context: WeatherShareContext
    let onSnapshot: () -> Void
    let onLink: () -> Void
    let onSummary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share Weather")
                .font(.headline)
                .padding(.bottom, 4)

            Button(action: onSnapshot) {
                Label("Weather Snapshot", systemImage: "photo")
            }

            if WeatherShareLinkBuilder.makePublicShareURL(from: context) != nil {
                Button(action: onLink) {
                    Label("Share Location Link", systemImage: "link")
                }
            }

            Button(action: onSummary) {
                Label("Share Text Summary", systemImage: "text.quote")
            }
        }
        .padding(16)
    }
}

struct MacShareView: View {
    let image: NSImage

    var body: some View {
        VStack(spacing: 16) {
            Text("Share Weather Snapshot")
                .font(.headline)

            if let url = WeatherShareSnapshotExporter.writePNG(from: image) {
                ShareLink(item: url, preview: SharePreview("Weather Snapshot", image: Image(nsImage: image))) {
                    Label("Share Image", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }
}
#endif
