//
//  SkeletonView.swift
//  SaxWeather
//
//  Created on 13/01/2026
//

import SwiftUI

/// Animated skeleton loading placeholder
struct SkeletonView: View {
    @State private var isAnimating = false
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(cornerRadius)
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 0.3),
                                .init(color: .white, location: 0.7),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: isAnimating ? .leading : .trailing,
                            endPoint: isAnimating ? .trailing : .leading
                        )
                    )
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

/// Weather-specific skeleton loading screen
struct WeatherLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Weather icon placeholder
            SkeletonView(cornerRadius: 75)
                .frame(width: 150, height: 150)
            
            // Temperature placeholder
            SkeletonView(cornerRadius: 12)
                .frame(width: 200, height: 80)
            
            // Feels like placeholder
            SkeletonView(cornerRadius: 8)
                .frame(width: 150, height: 24)
            
            // High/Low placeholder
            HStack(spacing: 20) {
                SkeletonView(cornerRadius: 8)
                    .frame(width: 80, height: 24)
                SkeletonView(cornerRadius: 8)
                    .frame(width: 80, height: 24)
            }
            
            Spacer()
            
            // Weather details grid skeleton
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonView(cornerRadius: 12)
                        .frame(height: 80)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// Preview
#Preview {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()
        WeatherLoadingSkeleton()
    }
}
