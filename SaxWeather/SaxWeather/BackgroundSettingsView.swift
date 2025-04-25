//
//  BackgroundSettingsView.swift
//  SaxWeather
//

import SwiftUI

struct BackgroundSettingsView: View {
    @EnvironmentObject var storeManager: StoreManager
    @AppStorage("userCustomBackground") private var savedImageData: Data?
    @AppStorage("useCustomBackground") private var useCustomBackground = true
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingAlert = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                mainContent
                Spacer()
            }
            .navigationTitle("Background Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(image: $selectedImage, onImageSelected: { image in
                    if let imageData = image.jpegData(compressionQuality: 0.7) {
                        savedImageData = imageData
                        useCustomBackground = true
                    }
                })
            }
            .alert("Purchase Error", isPresented: $showingAlert, presenting: storeManager.purchaseError) { _ in
                Button("OK") { }
            } message: { error in
                Text(error)
            }
            .onChange(of: storeManager.purchaseError) { error in
                showingAlert = error != nil
            }
        }
    }
    
    private var mainContent: some View {
        Group {
            if storeManager.customBackgroundUnlocked {
                CustomBackgroundContent(
                    selectedImage: $selectedImage,
                    savedImageData: $savedImageData,
                    useCustomBackground: $useCustomBackground,
                    showingImagePicker: $showingImagePicker,
                    colorScheme: colorScheme
                )
            } else {
                purchaseView
            }
        }
        .padding()
    }
    
    private var purchaseView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .foregroundColor(.blue)
                .padding(.vertical)
            
            Text("Custom Backgrounds")
                .font(.title2)
                .bold()
            
            Text("Personalize your weather app with your own images!")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !storeManager.products.isEmpty, let product = storeManager.products.first {
                Text("Just \(product.displayPrice)")
                    .font(.headline)
                    .padding(.vertical, 5)
            }
            
            Button(action: {
                Task {
                    await storeManager.purchaseCustomBackground()
                }
            }) {
                Text(storeManager.purchaseInProgress ? "Processing..." : "Unlock Custom Backgrounds")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(storeManager.purchaseInProgress)
            
            Button("Restore Purchase") {
                Task {
                    await storeManager.restorePurchases()
                }
            }
            .padding(.top)
        }
        .padding()
        .background(Color(colorScheme == .dark ? .systemGray6 : .systemBackground))
        .cornerRadius(16)
        .shadow(radius: 5)
    }
}

struct CustomBackgroundContent: View {
    @Binding var selectedImage: UIImage?
    @Binding var savedImageData: Data?
    @Binding var useCustomBackground: Bool
    @Binding var showingImagePicker: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Custom Background Settings")
                .font(.headline)
            
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else if let savedData = savedImageData, let image = UIImage(data: savedData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                Image(systemName: "photo.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .foregroundColor(.gray)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
            }
            
            Button("Select Custom Background") {
                showingImagePicker = true
            }
            .buttonStyle(.borderedProminent)
            
            if savedImageData != nil {
                Toggle("Use custom background", isOn: $useCustomBackground)
                    .padding(.vertical)
                
                Button("Reset to Default Background") {
                    withAnimation {
                        savedImageData = nil
                        selectedImage = nil
                    }
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(colorScheme == .dark ? .systemGray6 : .systemBackground))
        .cornerRadius(16)
        .shadow(radius: 5)
    }
}

struct BackgroundSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundSettingsView()
            .environmentObject(StoreManager.shared)
    }
}
