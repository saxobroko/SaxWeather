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
            print("🔍 Attempting to load product with ID: \(ProductID)")
            let storeProducts = try await Product.products(for: [ProductID])
            
            await MainActor.run {
                self.products = storeProducts
                
                if storeProducts.isEmpty {
                    print("⚠️ No products found with ID: \(ProductID)")
                    self.purchaseError = "Product not found. Check configuration."
                } else {
                    print("✅ Successfully loaded \(storeProducts.count) products")
                    for product in storeProducts {
                        print("📦 Found: \(product.id) - \(product.displayName)")
                    }
                }
            }
        } catch {
            await MainActor.run {
                print("❌ Error loading products: \(error)")
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
                    print("Purchase successful")
                } else {
                    purchaseError = "Transaction verification failed"
                }
            case .userCancelled:
                print("User cancelled")
            case .pending:
                purchaseError = "Purchase pending approval"
            @unknown default:
                purchaseError = "Unknown purchase result"
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            print("Purchase error: \(error)")
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
