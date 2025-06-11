//
//  Blendv3Tests.swift
//  Blendv3Tests
//
//  Created by Chris Karani on 22/05/2025.
//

import Testing
@testable import Blendv3

struct Blendv3Tests {

    @Test func colorHexInitialization() async throws {
        // Test Color hex initialization
        let redColor = Color(hex: "#FF0000")
        let blueColor = Color(hex: "0000FF")
        
        // Colors should be created without throwing
        #expect(redColor != nil)
        #expect(blueColor != nil)
    }
    
    @Test func designSystemColors() async throws {
        // Test that design system colors are available
        let primaryColor = Color.primaryBlend
        let secondaryColor = Color.secondaryBlend
        let accentColor = Color.accentBlend
        
        #expect(primaryColor != nil)
        #expect(secondaryColor != nil)
        #expect(accentColor != nil)
    }
}
