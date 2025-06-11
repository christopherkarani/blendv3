//
//  HomeView.swift
//  Blendv3
//
//  Created by Chris Karani on 22/05/2025.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, options: .repeating, value: viewModel.isAnimating)
            
            Text(viewModel.welcomeMessage)
                .font(.title2)
                .fontWeight(.medium)
            
            Button("Animate") {
                viewModel.triggerAnimation()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .onAppear {
            viewModel.onAppear()
        }
    }
}

#Preview {
    HomeView()
}