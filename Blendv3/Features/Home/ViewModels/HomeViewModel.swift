//
//  HomeViewModel.swift
//  Blendv3
//
//  Created by Chris Karani on 22/05/2025.
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var welcomeMessage = "Hello, Blend!"
    @Published var isAnimating = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    func onAppear() {
        welcomeMessage = "Welcome to Blendv3!"
    }
    
    func triggerAnimation() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isAnimating.toggle()
        }
        
        // Reset animation state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isAnimating = false
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Future: Add any Combine bindings here
    }
}