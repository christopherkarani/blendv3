//
//  StateManagementService.swift
//  Blendv3
//
//  Centralized state management service
//

import Foundation
import Combine
import stellarsdk
//
///// State management service providing centralized app state
//class StateManagementService: ObservableObject, StateManagementServiceProtocol {
//    
//    // MARK: - Main Actor Published Properties
//    
//    @MainActor @Published private var _initState: VaultInitState = .notInitialized
//    @MainActor @Published private var _isLoading: Bool = false
//    @MainActor @Published private var _error: BlendVaultError?
//    
//    // MARK: - Private Properties
//    
//    private let logger: DebugLogger
//    @MainActor private var cancellables = Set<AnyCancellable>()
//    private let queue = DispatchQueue(label: "com.blendv3.state.queue", qos: .userInitiated)
//    
//    // MARK: - Protocol Properties (nonisolated)
//    
//    private let initStateSubject = CurrentValueSubject<VaultInitState, Never>(.notInitialized)
//    private let loadingSubject = CurrentValueSubject<Bool, Never>(false)
//    private let errorSubject = CurrentValueSubject<BlendVaultError?, Never>(nil)
//    
//    // These are safe to access from any context
//    var initStatePublisher: Published<VaultInitState>.Publisher { 
//        initStateSubject
//            .handleEvents(receiveOutput: { [weak self] value in
//                Task { @MainActor [weak self] in
//                    self?._initState = value
//                }
//            })
//            .eraseToAnyPublisher() as! Published<VaultInitState>.Publisher
//    }
//    
//    var isLoading: Published<Bool>.Publisher { 
//        loadingSubject
//            .handleEvents(receiveOutput: { [weak self] value in
//                Task { @MainActor [weak self] in
//                    self?._isLoading = value
//                }
//            })
//            .eraseToAnyPublisher() as! Published<Bool>.Publisher
//    }
//    
//    var error: Published<BlendVaultError?>.Publisher { 
//        errorSubject
//            .handleEvents(receiveOutput: { [weak self] value in
//                Task { @MainActor [weak self] in
//                    self?._error = value
//                }
//            })
//            .eraseToAnyPublisher() as! Published<BlendVaultError?>.Publisher
//    }
//    
//    // MARK: - Initialization
//    
//    init() {
//        self.logger = DebugLogger(subsystem: "com.blendv3.state", category: "StateManagement")
//        setupStateLogging()
//    }
//    
//    func setInitState(_ state: VaultInitState) async {
//        let previousState = await currentInitState
//        initStateSubject.send(state)
//        logger.info("Init state changed: \(previousState.description) → \(state.description)")
//        
//        // Clear error when transitioning to ready state
//        if case .ready = state {
//            await setError(nil)
//        }
//    }
//    
//    func setLoading(_ loading: Bool) async {
//        loadingSubject.send(loading)
//        logger.debug("Loading state changed: \(loading)")
//    }
//    
//    func setError(_ error: BlendVaultError?) async {
//        errorSubject.send(error)
//        if let error = error {
//            logger.error("Error state set: \(error.localizedDescription)")
//            
//            // Update init state if error is critical
//            switch error {
//            case .initializationFailed:
//                initStateSubject.send(.failed(error))
//            default:
//                break
//            }
//        } else {
//            logger.debug("Error state cleared")
//        }
//    }
//    
//    func clearError() async {
//        await setError(nil)
//    }
//    
//    // Helper property to safely access current state
//    @MainActor
//    private var currentInitState: VaultInitState {
//        _initState
//    }
//    
//    // MARK: - Additional State Management
//    
//    /// Perform a state transition with validation
//    func transition(to newState: VaultInitState) async throws {
//        let currentState = await currentInitState
//        
//        // Validate state transition
//        guard isValidTransition(from: currentState, to: newState) else {
//            logger.error("Invalid state transition: \(currentState.description) → \(newState.description)")
//            throw BlendVaultError.unknown("Invalid state transition")
//        }
//        
//        await setInitState(newState)
//    }
//    
//    /// Reset all state to initial values
//    func reset() async {
//        logger.info("Resetting all state")
//        initStateSubject.send(.notInitialized)
//        loadingSubject.send(false)
//        errorSubject.send(nil)
//    }
//    
//    // MARK: - Private Methods
//    
//    private func setupStateLogging() {
//        // Log state changes for debugging
//        Task { @MainActor in
//            initStateSubject
//                .sink { [weak self] state in
//                    guard let self = self else { return }
//                    self.logStateChange("Init state", value: state.description)
//                }
//                .store(in: &cancellables)
//            
//            loadingSubject
//                .sink { [weak self] loading in
//                    guard let self = self else { return }
//                    self.logStateChange("Loading", value: String(loading))
//                }
//                .store(in: &cancellables)
//            
//            errorSubject
//                .compactMap { $0 }
//                .sink { [weak self] error in
//                    guard let self = self else { return }
//                    self.logStateChange("Error", value: error.localizedDescription)
//                }
//                .store(in: &cancellables)
//        }
//    }
//    
//    private func logStateChange(_ name: String, value: String) {
//        logger.debug("\(name): \(value)")
//    }
//    
//    /// Validate if a state transition is allowed
//    private func isValidTransition(from currentState: VaultInitState, to newState: VaultInitState) -> Bool {
//        switch (currentState, newState) {
//        case (.notInitialized, .initializing),
//             (.notInitialized, .failed),
//             (.initializing, .ready),
//             (.initializing, .failed),
//             (.failed, .initializing),
//             (.failed, .notInitialized),
//             (.ready, .failed),
//             (.ready, .notInitialized):
//            return true
//        default:
//            return false
//        }
//    }
//}
//
// 
