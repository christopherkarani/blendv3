import XCTest
@testable import Blendv3

final class ReactiveRateModifierTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private let targetUtilization: Decimal = FixedMath.toFixed(value: 0.8, decimals: 7) // 80%
    private let reactivity: Decimal = FixedMath.toFixed(value: 0.1, decimals: 7) // 10%
    
    // MARK: - Initialization Tests
    
    func testInit_withDefaultValues_createsValidModifier() {
        // Given/When
        let modifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        // Then
        XCTAssertEqual(modifier.currentModifier, ReactiveRateModifier.defaultModifier)
        XCTAssertEqual(modifier.targetUtilization, targetUtilization)
        XCTAssertEqual(modifier.reactivity, reactivity)
        XCTAssertFalse(modifier.isAtMinimum)
        XCTAssertFalse(modifier.isAtMaximum)
    }
    
    func testInit_withCustomModifier_respectsBounds() {
        // Given
        let tooHighModifier = ReactiveRateModifier.maxModifier * 2
        let tooLowModifier = ReactiveRateModifier.minModifier / 2
        
        // When
        let highModifier = ReactiveRateModifier(
            currentModifier: tooHighModifier,
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let lowModifier = ReactiveRateModifier(
            currentModifier: tooLowModifier,
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        // Then
        XCTAssertEqual(highModifier.currentModifier, ReactiveRateModifier.maxModifier)
        XCTAssertTrue(highModifier.isAtMaximum)
        
        XCTAssertEqual(lowModifier.currentModifier, ReactiveRateModifier.minModifier)
        XCTAssertTrue(lowModifier.isAtMinimum)
    }
    
    // MARK: - Rate Modifier Calculation Tests
    
    func testCalculateNewModifier_utilizationAtTarget_noChange() {
        // Given
        let modifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let currentUtilization = targetUtilization
        
        // When
        let newModifier = modifier.calculateNewModifier(currentUtilization: currentUtilization)
        
        // Then
        XCTAssertEqual(newModifier.currentModifier, modifier.currentModifier)
    }
    
    func testCalculateNewModifier_utilizationAboveTarget_increasesModifier() {
        // Given
        let modifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let highUtilization = FixedMath.toFixed(value: 0.9, decimals: 7) // 90%
        let futureTime = Date().addingTimeInterval(3600) // 1 hour later
        
        // When
        let newModifier = modifier.calculateNewModifier(
            currentUtilization: highUtilization,
            currentTime: futureTime
        )
        
        // Then
        XCTAssertGreaterThan(newModifier.currentModifier, modifier.currentModifier)
        XCTAssertEqual(newModifier.lastUpdateTime, futureTime)
    }
    
    func testCalculateNewModifier_utilizationBelowTarget_decreasesModifier() {
        // Given
        let highModifier = ReactiveRateModifier(
            currentModifier: FixedMath.toFixed(value: 2.0, decimals: 7), // 200%
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let lowUtilization = FixedMath.toFixed(value: 0.5, decimals: 7) // 50%
        let futureTime = Date().addingTimeInterval(3600) // 1 hour later
        
        // When
        let newModifier = highModifier.calculateNewModifier(
            currentUtilization: lowUtilization,
            currentTime: futureTime
        )
        
        // Then
        XCTAssertLessThan(newModifier.currentModifier, highModifier.currentModifier)
        XCTAssertEqual(newModifier.lastUpdateTime, futureTime)
    }
    
    func testCalculateNewModifier_respectsMinimumBound() {
        // Given
        let modifier = ReactiveRateModifier(
            currentModifier: ReactiveRateModifier.minModifier,
            targetUtilization: targetUtilization,
            reactivity: FixedMath.toFixed(value: 1.0, decimals: 7) // High reactivity
        )
        
        let veryLowUtilization = FixedMath.toFixed(value: 0.1, decimals: 7) // 10%
        let futureTime = Date().addingTimeInterval(86400) // 24 hours later
        
        // When
        let newModifier = modifier.calculateNewModifier(
            currentUtilization: veryLowUtilization,
            currentTime: futureTime
        )
        
        // Then
        XCTAssertEqual(newModifier.currentModifier, ReactiveRateModifier.minModifier)
        XCTAssertTrue(newModifier.isAtMinimum)
    }
    
    func testCalculateNewModifier_respectsMaximumBound() {
        // Given
        let modifier = ReactiveRateModifier(
            currentModifier: ReactiveRateModifier.maxModifier,
            targetUtilization: targetUtilization,
            reactivity: FixedMath.toFixed(value: 1.0, decimals: 7) // High reactivity
        )
        
        let veryHighUtilization = FixedMath.toFixed(value: 0.99, decimals: 7) // 99%
        let futureTime = Date().addingTimeInterval(86400) // 24 hours later
        
        // When
        let newModifier = modifier.calculateNewModifier(
            currentUtilization: veryHighUtilization,
            currentTime: futureTime
        )
        
        // Then
        XCTAssertEqual(newModifier.currentModifier, ReactiveRateModifier.maxModifier)
        XCTAssertTrue(newModifier.isAtMaximum)
    }
    
    // MARK: - Time-Based Tests
    
    func testCalculateNewModifier_longerTimeDelta_largerChange() {
        // Given
        let modifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let highUtilization = FixedMath.toFixed(value: 0.9, decimals: 7) // 90%
        let shortTime = Date().addingTimeInterval(1800) // 30 minutes
        let longTime = Date().addingTimeInterval(7200) // 2 hours
        
        // When
        let shortDeltaModifier = modifier.calculateNewModifier(
            currentUtilization: highUtilization,
            currentTime: shortTime
        )
        
        let longDeltaModifier = modifier.calculateNewModifier(
            currentUtilization: highUtilization,
            currentTime: longTime
        )
        
        // Then
        XCTAssertGreaterThan(longDeltaModifier.currentModifier, shortDeltaModifier.currentModifier)
    }
    
    func testTimeSinceLastUpdate_calculatesCorrectly() {
        // Given
        let pastTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let modifier = ReactiveRateModifier(
            lastUpdateTime: pastTime,
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        // When
        let timeDelta = modifier.timeSinceLastUpdate
        
        // Then
        XCTAssertGreaterThan(timeDelta, 3590) // Allow for small timing differences
        XCTAssertLessThan(timeDelta, 3610)
    }
    
    // MARK: - Reactivity Tests
    
    func testCalculateNewModifier_highReactivity_largerChange() {
        // Given
        let lowReactivity = FixedMath.toFixed(value: 0.01, decimals: 7) // 1%
        let highReactivity = FixedMath.toFixed(value: 0.5, decimals: 7) // 50%
        
        let lowReactivityModifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: lowReactivity
        )
        
        let highReactivityModifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: highReactivity
        )
        
        let highUtilization = FixedMath.toFixed(value: 0.9, decimals: 7) // 90%
        let futureTime = Date().addingTimeInterval(3600) // 1 hour later
        
        // When
        let lowReactivityResult = lowReactivityModifier.calculateNewModifier(
            currentUtilization: highUtilization,
            currentTime: futureTime
        )
        
        let highReactivityResult = highReactivityModifier.calculateNewModifier(
            currentUtilization: highUtilization,
            currentTime: futureTime
        )
        
        // Then
        let lowChange = lowReactivityResult.currentModifier - lowReactivityModifier.currentModifier
        let highChange = highReactivityResult.currentModifier - highReactivityModifier.currentModifier
        
        XCTAssertGreaterThan(highChange, lowChange)
    }
    
    // MARK: - Utility Methods Tests
    
    func testModifierAsFloat_convertsCorrectly() {
        // Given
        let modifier = ReactiveRateModifier(
            currentModifier: FixedMath.toFixed(value: 1.5, decimals: 7),
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        // When
        let floatValue = modifier.modifierAsFloat
        
        // Then
        XCTAssertEqual(floatValue, 1.5, accuracy: 0.0001)
    }
    
    func testBoundaryChecks_workCorrectly() {
        // Given
        let minModifier = ReactiveRateModifier(
            currentModifier: ReactiveRateModifier.minModifier,
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let maxModifier = ReactiveRateModifier(
            currentModifier: ReactiveRateModifier.maxModifier,
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let normalModifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        // Then
        XCTAssertTrue(minModifier.isAtMinimum)
        XCTAssertFalse(minModifier.isAtMaximum)
        
        XCTAssertFalse(maxModifier.isAtMinimum)
        XCTAssertTrue(maxModifier.isAtMaximum)
        
        XCTAssertFalse(normalModifier.isAtMinimum)
        XCTAssertFalse(normalModifier.isAtMaximum)
    }
    
    // MARK: - Codable Tests
    
    func testCodable_encodesAndDecodesCorrectly() throws {
        // Given
        let originalModifier = ReactiveRateModifier(
            currentModifier: FixedMath.toFixed(value: 1.5, decimals: 7),
            lastUpdateTime: Date(),
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalModifier)
        
        let decoder = JSONDecoder()
        let decodedModifier = try decoder.decode(ReactiveRateModifier.self, from: data)
        
        // Then
        XCTAssertEqual(decodedModifier, originalModifier)
    }
    
    // MARK: - Edge Cases Tests
    
    func testCalculateNewModifier_zeroTimeDelta_noChange() {
        // Given
        let modifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let highUtilization = FixedMath.toFixed(value: 0.9, decimals: 7) // 90%
        let sameTime = modifier.lastUpdateTime
        
        // When
        let newModifier = modifier.calculateNewModifier(
            currentUtilization: highUtilization,
            currentTime: sameTime
        )
        
        // Then
        XCTAssertEqual(newModifier.currentModifier, modifier.currentModifier)
    }
    
    func testCalculateNewModifier_extremeUtilization_handledCorrectly() {
        // Given
        let modifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let zeroUtilization: Decimal = 0
        let maxUtilization = FixedMath.SCALAR_7
        let futureTime = Date().addingTimeInterval(3600)
        
        // When
        let zeroResult = modifier.calculateNewModifier(
            currentUtilization: zeroUtilization,
            currentTime: futureTime
        )
        
        let maxResult = modifier.calculateNewModifier(
            currentUtilization: maxUtilization,
            currentTime: futureTime
        )
        
        // Then
        XCTAssertLessThan(zeroResult.currentModifier, modifier.currentModifier)
        XCTAssertGreaterThan(maxResult.currentModifier, modifier.currentModifier)
    }
    
    // MARK: - Performance Tests
    
    func testCalculateNewModifier_performance() {
        // Given
        let modifier = ReactiveRateModifier(
            targetUtilization: targetUtilization,
            reactivity: reactivity
        )
        
        let utilization = FixedMath.toFixed(value: 0.9, decimals: 7)
        
        // When/Then
        measure {
            for _ in 0..<1000 {
                _ = modifier.calculateNewModifier(currentUtilization: utilization)
            }
        }
    }
} 