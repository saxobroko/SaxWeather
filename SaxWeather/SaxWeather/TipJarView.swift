//
//  TipJarView.swift
//  SaxWeather
//
//  Created by saxobroko on 2026-01-28
//

import SwiftUI
import StoreKit

struct TipJarView: View {
    @StateObject private var tipStore = TipStoreManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showingThankYou = false
    
    let tips = [
        TipOption(id: "com.saxobroko.SaxWeather.tip1", emoji: "☕️", title: "Coffee", amount: "$0.99"),
        TipOption(id: "com.saxobroko.SaxWeather.tip250", emoji: "🍰", title: "Cake", amount: "$2.49"),
        TipOption(id: "com.saxobroko.SaxWeather.tip5", emoji: "🍕", title: "Pizza", amount: "$4.99"),
        TipOption(id: "com.saxobroko.SaxWeather.tip10", emoji: "🎉", title: "Party", amount: "$9.99")
    ]
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    tipsGrid
                    benefitsSection
                }
                .padding()
            }
            .navigationTitle("Support SaxWeather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Thank You! 🎉", isPresented: $showingThankYou) {
                Button("You're Welcome!") { }
            } message: {
                Text("Your support helps keep SaxWeather free and ad-free for everyone!")
            }
            .alert("Error", isPresented: .constant(tipStore.purchaseError != nil)) {
                Button("OK") {
                    tipStore.purchaseError = nil
                }
            } message: {
                if let error = tipStore.purchaseError {
                    Text(error)
                }
            }
        }
        #elseif os(macOS)
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Support SaxWeather")
                    .font(.title2.bold())
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    tipsGrid
                    benefitsSection
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 700)
        .alert("Thank You! 🎉", isPresented: $showingThankYou) {
            Button("You're Welcome!") { }
        } message: {
            Text("Your support helps keep SaxWeather free and ad-free for everyone!")
        }
        .alert("Error", isPresented: .constant(tipStore.purchaseError != nil)) {
            Button("OK") {
                tipStore.purchaseError = nil
            }
        } message: {
            if let error = tipStore.purchaseError {
                Text(error)
            }
        }
        #endif
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundStyle(.pink.gradient)
            
            Text("Love SaxWeather?")
                .font(.title.bold())
            
            Text("Support development with a tip! Every contribution helps keep the app free and ad-free.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var tipsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(tips) { tip in
                TipButton(tip: tip, isLoading: tipStore.purchaseInProgress) {
                    Task {
                        if await tipStore.purchase(productID: tip.id) {
                            showingThankYou = true
                        }
                    }
                }
            }
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your tips support:")
                .font(.headline)
            
            BenefitRow(icon: "cloud.sun", text: "Accurate weather data")
            BenefitRow(icon: "arrow.clockwise", text: "Regular updates & new features")
            BenefitRow(icon: "lock.shield", text: "No ads, ever")
            BenefitRow(icon: "face.smiling", text: "A happy developer!")
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TipOption: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let amount: String
}

struct TipButton: View {
    let tip: TipOption
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(tip.emoji)
                    .font(.system(size: 50))
                
                Text(tip.title)
                    .font(.headline)
                
                Text(tip.amount)
                    .font(.title3.bold())
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
    }
}

@MainActor
class TipStoreManager: ObservableObject {
    @Published var purchaseInProgress = false
    @Published var purchaseError: String?
    
    func purchase(productID: String) async -> Bool {
        purchaseInProgress = true
        purchaseError = nil
        defer { purchaseInProgress = false }
        
        do {
            #if DEBUG
            print("🔍 Attempting to purchase tip: \(productID)")
            #endif
            
            let products = try await Product.products(for: [productID])
            
            guard let product = products.first else {
                #if DEBUG
                print("⚠️ Product not found: \(productID)")
                #endif
                purchaseError = "Product not found. Please try again later."
                return false
            }
            
            #if DEBUG
            print("✅ Found product: \(product.displayName) - \(product.displayPrice)")
            #endif
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    #if DEBUG
                    print("✅ Purchase successful: \(transaction.productID)")
                    #endif
                    await transaction.finish()
                    return true
                case .unverified:
                    #if DEBUG
                    print("⚠️ Transaction verification failed")
                    #endif
                    purchaseError = "Transaction verification failed"
                    return false
                }
            case .userCancelled:
                #if DEBUG
                print("ℹ️ User cancelled purchase")
                #endif
                return false
            case .pending:
                #if DEBUG
                print("⏳ Purchase pending")
                #endif
                purchaseError = "Purchase pending approval"
                return false
            @unknown default:
                purchaseError = "Unknown purchase result"
                return false
            }
        } catch {
            #if DEBUG
            print("❌ Purchase error: \(error)")
            #endif
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }
}

#Preview {
    TipJarView()
}
