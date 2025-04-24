//
//  StoreManager.swift
//  SaxWeather
//

import SwiftUI
import StoreKit

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    private let ProductID = "CustomBackground50c"
    
    @Published var customBackgroundUnlocked = false
    @Published var products: [Product] = []
    @Published var purchaseInProgress = false
    @Published var purchaseError: String?
    
    private init() {
        Task {
            await loadProducts()
            await updatePurchasedState()
        }
        
        // Listen for transactions in real-time
        Task {
            for await result in StoreKit.Transaction.updates {
                await handleTransactionResult(result)
            }
        }
    }
    
    func loadProducts() async {
        do {
            #if DEBUG
            print("🔍 Attempting to load product with ID: \(ProductID)")
            #endif
            
            let storeProducts = try await Product.products(for: [ProductID])
            
            await MainActor.run {
                self.products = storeProducts
                
                if storeProducts.isEmpty {
                    #if DEBUG
                    print("⚠️ No products found with ID: \(ProductID)")
                    #endif
                    self.purchaseError = "Product not found. Check configuration."
                } else {
                    #if DEBUG
                    print("✅ Successfully loaded \(storeProducts.count) products")
                    for product in storeProducts {
                        print("📦 Found: \(product.id) - \(product.displayName)")
                    }
                    #endif
                }
            }
        } catch {
            await MainActor.run {
                #if DEBUG
                print("❌ Error loading products: \(error)")
                #endif
                self.purchaseError = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    func updatePurchasedState() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == ProductID {
                customBackgroundUnlocked = true
                break
            }
        }
    }
    
    func handleTransactionResult(_ result: VerificationResult<StoreKit.Transaction>) async {
        if case .verified(let transaction) = result,
           transaction.productID == ProductID {
            customBackgroundUnlocked = true
            
            // Always finish transactions
            await transaction.finish()
        }
    }
    
    func purchaseCustomBackground() async {
        guard let product = products.first(where: { $0.id == ProductID }) else {
            purchaseError = "Product not found"
            return
        }
        
        purchaseInProgress = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    customBackgroundUnlocked = true
                    await transaction.finish()
                    #if DEBUG
                    print("Purchase successful")
                    #endif
                } else {
                    purchaseError = "Transaction verification failed"
                }
            case .userCancelled:
                #if DEBUG
                print("User cancelled")
                #endif
            case .pending:
                purchaseError = "Purchase pending approval"
            @unknown default:
                purchaseError = "Unknown purchase result"
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            #if DEBUG
            print("Purchase error: \(error)")
            #endif
        }
        
        purchaseInProgress = false
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedState()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }
}
