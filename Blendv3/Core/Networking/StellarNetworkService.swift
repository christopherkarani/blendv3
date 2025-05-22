//
//  StellarNetworkService.swift
//  Blendv3
//
//  Service for interacting with the Stellar network
//

import Foundation
import Combine
import stellarsdk

/// Service responsible for Stellar network interactions
final class StellarNetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    
    private let sdk: StellarSDK
    private let network: Network
    private var streamItem: OperationsStreamItem?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(isTestnet: Bool = true) {
        if isTestnet {
            self.sdk = StellarSDK(withHorizonUrl: Constants.Network.testnet)
            self.network = .testnet
        } else {
            self.sdk = StellarSDK(withHorizonUrl: Constants.Network.mainnet)
            self.network = .public
        }
    }
    
    // MARK: - NetworkServiceProtocol Implementation
    
    func submitTransaction(_ transaction: Transaction) async throws -> SubmitTransactionResponse {
        return try await withCheckedThrowingContinuation { continuation in
            sdk.transactions.submitTransaction(transaction: transaction) { response in
                switch response {
                case .success(let details):
                    continuation.resume(returning: details)
                case .destinationRequiresMemo:
                    continuation.resume(throwing: WalletError.transactionFailed("Destination requires memo"))
                case .failure(let error):
                    continuation.resume(throwing: WalletError.networkError(error.localizedDescription))
                }
            }
        }
    }    
    func getAccountDetails(accountId: String) async throws -> AccountResponse {
        return try await withCheckedThrowingContinuation { continuation in
            sdk.accounts.getAccountDetails(accountId: accountId) { response in
                switch response {
                case .success(let details):
                    continuation.resume(returning: details)
                case .failure(let error):
                    continuation.resume(throwing: WalletError.networkError(error.localizedDescription))
                }
            }
        }
    }
    
    func streamAccountUpdates(accountId: String) -> AnyPublisher<AccountResponse, Error> {
        let subject = PassthroughSubject<AccountResponse, Error>()
        
        streamItem = sdk.accounts.stream(
            for: .accountsForAccount(
                account: accountId,
                cursor: nil
            )
        )
        
        streamItem?.onReceive { response in
            switch response {
            case .open:
                break
            case .response(_, let account):
                subject.send(account)
            case .error(let error):
                if let error = error {
                    subject.send(completion: .failure(WalletError.networkError(error.localizedDescription)))
                }
            }
        }
        
        return subject
            .handleEvents(receiveCancel: { [weak self] in
                self?.streamItem?.closeStream()
                self?.streamItem = nil
            })
            .eraseToAnyPublisher()
    }
}