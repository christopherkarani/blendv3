//
//  MigrationValidationResult.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Migration Validation Models

/// Result of migration validation between old and new implementations
public enum MigrationValidationResult {
    case success
    case differences([String])
    case incomplete(String)
}