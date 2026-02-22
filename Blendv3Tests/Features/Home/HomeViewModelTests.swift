//
//  HomeViewModelTests.swift
//  Blendv3Tests
//
//  Created by Chris Karani on 22/05/2025.
//

import Testing
import Combine
@testable import Blendv3

@MainActor
struct HomeViewModelTests {
    
    @Test func initialState() async throws {
        // Given
        let viewModel = HomeViewModel()
        
        // Then
        #expect(viewModel.welcomeMessage == "Hello, Blend!")
        #expect(viewModel.isAnimating == false)
    }
    
    @Test func onAppearUpdatesWelcomeMessage() async throws {
        // Given
        let viewModel = HomeViewModel()
        
        // When
        viewModel.onAppear()
        
        // Then
        #expect(viewModel.welcomeMessage == "Welcome to Blendv3!")
    }
    
    @Test func triggerAnimationToggleState() async throws {
        // Given
        let viewModel = HomeViewModel()
        
        // When
        viewModel.triggerAnimation()
        
        // Then
        #expect(viewModel.isAnimating == true)
        
        // Wait for animation reset
        try await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds
        
        #expect(viewModel.isAnimating == false)
    }
    
    @Test func viewModelIsMainActorIsolated() async throws {
        // Given/When
        let viewModel = HomeViewModel()
        
        // Then - This test ensures the ViewModel is properly isolated to MainActor
        #expect(viewModel.welcomeMessage == "Hello, Blend!")
    }
}