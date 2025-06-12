//
//  Blendv3App.swift
//  Blendv3
//
//  Created by Chris Karani on 22/05/2025.
//

import SwiftUI

@main
struct Blendv3App: App {
    // Dependency container initialized with keychain service
    private let dependencyContainer = DependencyContainer(
        keychainService: MockKeychainService() // Use real KeychainService in production
    )
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencyContainer.makeOracleViewModel())
        }
    }
}
