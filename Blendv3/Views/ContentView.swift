//
//  ContentView.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import SwiftUI
import stellarsdk

struct ContentView: View {
    @StateObject private var viewModel: BlendViewModel
    
    init() {
        print("🚀 DEBUG: ContentView init started")
        
        // Initialize with the provided secret key
        let secretKey = "SDYH3V6ICEM463OTM7EEK7SNHYILXZRHPY45AYZOSK3N4NLF3NQUI4PQ"
        
        do {
            let signer = try KeyPairSigner(secretSeed: secretKey)
            print("🚀 DEBUG: KeyPairSigner created successfully")
            print("🚀 DEBUG: Public key: \(signer.publicKey)")
            _viewModel = StateObject(wrappedValue: BlendViewModel(signer: signer))
        } catch {
            // Fallback - this shouldn't happen with a valid key
            print("🚀 DEBUG: Failed to create KeyPairSigner: \(error)")
            fatalError("Invalid secret key: \(error)")
        }
        
        print("🚀 DEBUG: ContentView init completed")
    }
    
    var body: some View {
        NavigationView {
            BlendDashboardView()
                .environmentObject(viewModel)
                .navigationTitle("Blend USDC Vault")
                .navigationBarTitleDisplayMode(.large)
        }
    }
} 