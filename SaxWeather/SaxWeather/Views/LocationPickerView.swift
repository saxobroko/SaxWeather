//
//  LocationPickerView.swift
//  SaxWeather
//
//  Created by Your Name on 2026-06-16.
//

import SwiftUI
import MapKit
import CoreLocation

// Wrapper struct to make annotations Identifiable
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var selectedLocationName: String?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var markerCoordinate: CLLocationCoordinate2D?
    @State private var errorMessage: String?
    @State private var isLoading = false
    /// Transient banner shown at the top of the view. Distinct
    /// from `errorMessage` (which is the persistent inline text
    /// below the map) — toasts are time-limited, attention-
    /// grabbing, and disappear on their own.
    @State private var toast: ToastMessage?

    /// Lightweight toast model. `id` is what SwiftUI diffs on
    /// to detect that a new toast has replaced the old one, so
    /// rapid re-fires always show the new text rather than
    /// inheriting a stale value.
    struct ToastMessage: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let style: Style
        enum Style { case info, warning }
    }
    @Environment(\.presentationMode) private var presentationMode
    
    // For reverse geocoding
    private let geocoder = CLGeocoder()
    
    // Computed property to provide annotations as Identifiable items
    private var annotations: [MapAnnotationItem] {
        if let coordinate = markerCoordinate {
            return [MapAnnotationItem(coordinate: coordinate)]
        }
        return []
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Map view with marker
                ZStack(alignment: .center) {
                    Map(coordinateRegion: $region, interactionModes: [.pan, .zoom],
                        showsUserLocation: true,
                        annotationItems: annotations) { annotation in
                        MapMarker(coordinate: annotation.coordinate)
                    }
                    
                    // Marker in the center
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                        .offset(y: -10) // Adjust to point correctly
                }
                .frame(height: 300)
                
                // Location information
                VStack(alignment: .leading, spacing: 8) {
                    if let coordinate = markerCoordinate {
                        HStack {
                            Text("Coordinates:")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let locationName = selectedLocationName {
                        HStack {
                            Text("Location:")
                                .font(.headline)
                            Spacer()
                            Text(locationName)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    } else if isLoading {
                        HStack {
                            Text("Location:")
                                .font(.headline)
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Select") {
                    if let coordinate = markerCoordinate {
                        selectLocation(coordinate: coordinate)
                    }
                }
                .disabled(markerCoordinate == nil)
            )
            .onChange(of: region.center.latitude) { _ in
                // Update marker coordinate when map is moved
                let newCenter = region.center
                markerCoordinate = newCenter
                scheduleReverseGeocode(newCenter)
            }
            .onChange(of: region.center.longitude) { _ in
                // Update marker coordinate when map is moved
                let newCenter = region.center
                markerCoordinate = newCenter
                scheduleReverseGeocode(newCenter)
            }
            // Transient toast banner. Slides in from the top
            // when `toast` is non-nil and auto-dismisses after
            // `duration` seconds (handled in `showToast`).
            .overlay(alignment: .top) {
                if let toast = toast {
                    HStack(spacing: 10) {
                        Image(systemName: toast.style == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(toast.text)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(2)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(toast.style == .warning ? Color.orange : Color.blue)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
                    .onTapGesture {
                        withAnimation { self.toast = nil }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: toast)
        }
    }
    
    // Debounce geocoding requests to avoid rate limiting
    @State private var geocodeWorkItem: DispatchWorkItem?
    
    private func scheduleReverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        // Cancel any pending geocoding request
        geocodeWorkItem?.cancel()
        
        // Cancel any ongoing geocoding request
        geocoder.cancelGeocode()
        
        // Create a new work item that will execute after a delay
        let workItem = DispatchWorkItem {
            self.reverseGeocodeLocation(coordinate)
        }
        
        geocodeWorkItem = workItem
        
        // Execute after 0.5 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    private func selectLocation(coordinate: CLLocationCoordinate2D) {
        // Validate coordinates using our validator
        let validationResult = CoordinateValidator.validate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard validationResult.isValid else {
            errorMessage = validationResult.errorMessage ?? "Invalid coordinates"
            showToast(
                validationResult.errorMessage ?? "Invalid coordinates",
                style: .warning
            )
            return
        }
        
        let validatedCoordinate = CLLocationCoordinate2D(
            latitude: validationResult.normalizedLatitude ?? coordinate.latitude,
            longitude: validationResult.normalizedLongitude ?? coordinate.longitude
        )
        
        selectedLocation = validatedCoordinate
        presentationMode.wrappedValue.dismiss()
    }
    
    private func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D) {
        // Clear previous error
        errorMessage = nil
        
        // Show loading indicator
        isLoading = true
        selectedLocationName = nil
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                // Ignore cancelled requests (these are expected when user is still moving the map)
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == CLError.geocodeFoundNoResult.rawValue ||
                       nsError.code == CLError.geocodeFoundPartialResult.rawValue ||
                       nsError.code == CLError.network.rawValue ||
                       nsError.code == CLError.geocodeCanceled.rawValue {
                        // Silently ignore these errors - they're common during map movement
                        self.selectedLocationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                        return
                    }
                    
                    self.errorMessage = "Could not determine location name"
                    self.showToast(
                        "Couldn't find a name for this location — using coordinates",
                        style: .warning
                    )
                    print("Geocoding error: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    // Fallback to coordinates if no readable name
                    self.selectedLocationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                    return
                }
                
                var locationComponents: [String] = []
                
                if let locality = placemark.locality, !locality.isEmpty {
                    locationComponents.append(locality)
                }
                
                if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
                    locationComponents.append(administrativeArea)
                }
                
                if let country = placemark.country, !country.isEmpty {
                    locationComponents.append(country)
                }
                
                if !locationComponents.isEmpty {
                    self.selectedLocationName = locationComponents.joined(separator: ", ")
                } else {
                    // Fallback to coordinates if no readable name
                    self.selectedLocationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                }
            }
        }
    }

    /// Show a transient toast at the top of the view. Auto-
    /// dismisses after `duration` seconds; tapping the toast
    /// dismisses it early. Repeated calls before dismissal
    /// replace the current toast (via the `id` change driving
    /// the SwiftUI transition).
    private func showToast(_ text: String, style: ToastMessage.Style = .info, duration: TimeInterval = 3.0) {
        withAnimation { toast = ToastMessage(text: text, style: style) }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            // Only clear if the current toast is still the one
            // we set (don't clobber a newer toast).
            if toast?.text == text {
                await MainActor.run {
                    withAnimation { self.toast = nil }
                }
            }
        }
    }
}

struct LocationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LocationPickerView(
            selectedLocation: .constant(nil),
            selectedLocationName: .constant(nil)
        )
    }
}