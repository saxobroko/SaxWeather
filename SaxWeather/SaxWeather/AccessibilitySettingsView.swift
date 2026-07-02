//
//  AccessibilitySettingsView.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-18
//

import SwiftUI

struct AccessibilitySettingsView: View {
    @EnvironmentObject private var customisationRegistry: CustomisationRegistry

    var wrappedInNavigationStack: Bool = true
    // MARK: - Dynamic Type
    @AppStorage("useSystemTextSize") private var useSystemTextSize = true
    @AppStorage("customTextSizeMultiplier") private var customTextSizeMultiplier = 1.0

    // MARK: - Motion & Animations
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("reduceMotionForce") private var reduceMotionForce = false
    @AppStorage("disableWeatherAnimations") private var disableWeatherAnimations = false

    // MARK: - Visual Enhancements
    @AppStorage("increaseContrast") private var increaseContrast = false
    @AppStorage("highContrastOutline") private var highContrastOutline = false
    @AppStorage("boldText") private var boldText = false

    // MARK: - VoiceOver Support
    @AppStorage("enhancedVoiceOverLabels") private var enhancedVoiceOverLabels = true
    @AppStorage("speakWeatherAlerts") private var speakWeatherAlerts = true

     // MARK: - Haptic Feedback
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("hapticOnSelection") private var hapticOnSelection = true
    @AppStorage("tapticOnRefresh") private var tapticOnRefresh = true
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        let content = accessibilityForm
        #if os(iOS)
        if wrappedInNavigationStack {
            NavigationStack { content }
        } else {
            content
        }
        #elseif os(macOS)
        ScrollView {
            VStack(spacing: 20) {
                GroupBox(label: Text("Text Size").font(.title3).fontWeight(.semibold)) {
                    textSizeSection
                        .padding()
                }
                GroupBox(label: Text("Motion & Animations").font(.title3).fontWeight(.semibold)) {
                    motionSection
                        .padding()
                }
                GroupBox(label: Text("Visual Enhancements").font(.title3).fontWeight(.semibold)) {
                    visualSection
                        .padding()
                }
                GroupBox(label: Text("VoiceOver").font(.title3).fontWeight(.semibold)) {
                    voiceOverSection
                        .padding()
                }
                GroupBox(label: Text("Haptic Feedback").font(.title3).fontWeight(.semibold)) {
                    hapticSection
                        .padding()
                }
                GroupBox(label: Text("Reset").font(.title3).fontWeight(.semibold)) {
                    resetSection
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Accessibility")
        #endif
    }

    @ViewBuilder
    private var accessibilityForm: some View {
        #if os(iOS)
        Form {
            Section {
                textSizeSection
            } header: {
                Label("Text Size", systemImage: "textformat.size")
            } footer: {
                Text("Turn off “Use System Text Size” to set a custom scale just for this app.")
            }

            Section {
                motionSection
            } header: {
                Label("Motion & Animations", systemImage: "gyroscope")
            } footer: {
                Text("Reduce or disable motion and animated weather icons to cut down on movement.")
            }

            Section {
                visualSection
            } header: {
                Label("Visual", systemImage: "circle.lefthalf.filled")
            } footer: {
                Text("Boost contrast, add text outlines, and use bold text for easier reading.")
            }

            Section {
                voiceOverSection
            } header: {
                Label("VoiceOver", systemImage: "speaker.wave.3")
            } footer: {
                Text("Extra descriptions for screen readers and spoken severe-weather alerts.")
            }

            Section {
                hapticSection
            } header: {
                Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
            } footer: {
                Text("Pull-to-refresh haptics cannot be fully disabled (iOS limitation).")
            }

            Section {
                resetSection
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: useSystemTextSize) { newValue in
            customisationRegistry.set(\.visual.useSystemTextSize, newValue)
        }
        .onChange(of: customTextSizeMultiplier) { newValue in
            customisationRegistry.set(\.visual.fontScale, newValue)
        }
        .onChange(of: reduceMotion) { newValue in
            customisationRegistry.set(\.accessibility.reduceMotion, newValue)
        }
        .onChange(of: reduceMotionForce) { newValue in
            customisationRegistry.set(\.accessibility.reduceMotionForce, newValue)
        }
        .onChange(of: disableWeatherAnimations) { newValue in
            customisationRegistry.set(\.iconography.disableWeatherAnimations, newValue)
        }
        .onChange(of: increaseContrast) { newValue in
            customisationRegistry.set(\.visual.increaseContrast, newValue)
        }
        .onChange(of: highContrastOutline) { newValue in
            customisationRegistry.set(\.accessibility.highContrastOutline, newValue)
        }
        .onChange(of: boldText) { newValue in
            customisationRegistry.set(\.visual.boldText, newValue)
        }
        .onChange(of: enhancedVoiceOverLabels) { newValue in
            customisationRegistry.set(\.accessibility.enhancedVoiceOverLabels, newValue)
        }
        .onChange(of: speakWeatherAlerts) { newValue in
            customisationRegistry.set(\.behaviour.speakWeatherAlerts, newValue)
        }
        .onChange(of: enableHapticFeedback) { newValue in
            customisationRegistry.set(\.behaviour.enableHapticFeedback, newValue)
        }
        .onChange(of: hapticOnSelection) { newValue in
            customisationRegistry.set(\.accessibility.hapticOnSelection, newValue)
        }
        .onChange(of: tapticOnRefresh) { newValue in
            customisationRegistry.set(\.accessibility.tapticOnRefresh, newValue)
        }
        #else
        EmptyView()
        #endif
    }

    // MARK: - Sections
    
    private var textSizeSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $useSystemTextSize) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Use System Text Size", systemImage: "textformat.size")
                        Text("Follow system Dynamic Type settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityLabel("Use System Text Size")
                .accessibilityHint("When enabled, text will resize according to your system settings")
                
                if !useSystemTextSize {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Custom Text Size", systemImage: "textformat")
                            Spacer()
                            Text("\(Int(customTextSizeMultiplier * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $customTextSizeMultiplier, in: 0.75...1.5, step: 0.05)
                            .accessibilityLabel("Custom Text Size")
                            .accessibilityValue("\(Int(customTextSizeMultiplier * 100)) percent")
                        
                        HStack {
                            Text("Smaller")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Larger")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var motionSection: some View {
        Group {
            Toggle(isOn: $reduceMotion) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Reduce Motion", systemImage: "gyroscope")
                    Text("Minimize UI animations and transitions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Reduce Motion")
            .accessibilityHint("Reduces animations throughout the app")

            Toggle(isOn: $reduceMotionForce) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Force Reduce Motion", systemImage: "tortoise.circle.fill")
                    Text("Always reduce motion, even when the system setting is off.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Force Reduce Motion")

            Toggle(isOn: $disableWeatherAnimations) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Disable Weather Icons", systemImage: "cloud.sun")
                    Text("Use static weather icons instead of animated ones")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Disable Weather Icon Animations")
            .accessibilityHint("Shows static weather icons instead of animated ones")
        }
    }
    
    private var visualSection: some View {
        Group {
            Toggle(isOn: $increaseContrast) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Increase Contrast", systemImage: "circle.lefthalf.filled")
                    Text("Enhance contrast for better readability")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Increase Contrast")
            .accessibilityHint("Makes text and UI elements more distinct")

            Toggle(isOn: $highContrastOutline) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("High-Contrast Outline", systemImage: "square.dashed")
                    Text("Add an outline around text for low-vision users.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("High-Contrast Outline")

            Toggle(isOn: $boldText) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Bold Text", systemImage: "bold")
                    Text("Make all text heavier for improved legibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Bold Text")
            .accessibilityHint("Makes all text appear bolder")
        }
    }
    
    private var voiceOverSection: some View {
        Group {
            Toggle(isOn: $enhancedVoiceOverLabels) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Enhanced VoiceOver", systemImage: "speaker.wave.3")
                    Text("Provide detailed descriptions for screen readers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Enhanced VoiceOver Labels")
            .accessibilityHint("Provides more detailed descriptions when using VoiceOver")

            Toggle(isOn: $speakWeatherAlerts) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Announce Weather Alerts", systemImage: "megaphone")
                    Text("Automatically announce severe weather warnings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Announce Weather Alerts")
            .accessibilityHint("Speaks severe weather alerts when they occur")
        }
    }
    
    private var hapticSection: some View {
        Group {
            #if os(iOS)
            Toggle(isOn: $enableHapticFeedback) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    Text("Feel touch feedback for actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Haptic Feedback")
            .accessibilityHint("Enables vibration feedback for interactions")

            Toggle(isOn: $hapticOnSelection) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Haptic on Selection", systemImage: "hand.point.up.left.fill")
                    Text("Vibrate when a picker value changes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Haptic on Selection")

            Toggle(isOn: $tapticOnRefresh) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Taptic on Refresh", systemImage: "arrow.triangle.2.circlepath")
                    Text("Pulse the taptic engine when weather data refreshes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Taptic on Refresh")
            #else
            Text("Haptic feedback is only available on iOS devices")
                .font(.caption)
                .foregroundColor(.secondary)
            #endif
        }
    }

    private var resetSection: some View {
        Group {
            Button(role: .destructive) {
                resetToDefaults()
            } label: {
                HStack {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    Spacer()
                }
            }
            .accessibilityLabel("Reset Accessibility Settings to Defaults")
            .accessibilityHint("Resets all accessibility preferences to their default values")
        }
    }
    
    // MARK: - Actions
    
    private func resetToDefaults() {
        useSystemTextSize = true
        customTextSizeMultiplier = 1.0
        reduceMotion = false
        reduceMotionForce = false
        disableWeatherAnimations = false
        increaseContrast = false
        highContrastOutline = false
        boldText = false
        enhancedVoiceOverLabels = true
        speakWeatherAlerts = false
        enableHapticFeedback = true
        hapticOnSelection = true
        tapticOnRefresh = true
    }
}

#Preview {
    AccessibilitySettingsView()
}
