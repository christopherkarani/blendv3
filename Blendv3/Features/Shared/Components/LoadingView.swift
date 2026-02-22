//
//  LoadingView.swift
//  Blendv3
//
//  Created by Chris Karani on 22/05/2025.
//

import SwiftUI

struct LoadingView: View {
    let message: String
    @State private var isAnimating = false
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryBlend))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .opacity(isAnimating ? 0.6 : 1.0)
        }
        .padding(32)
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary
            .ignoresSafeArea()
        
        LoadingView(message: "Loading your data...")
    }
}