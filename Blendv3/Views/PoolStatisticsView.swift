import SwiftUI

/// SwiftUI view for displaying pool statistics
struct PoolStatisticsView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: PoolViewModel
    
    // MARK: - Initialization
    
    init(poolId: String) {
        _viewModel = StateObject(wrappedValue: PoolViewModel(poolId: poolId))
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Statistics Grid
                statisticsGrid
                
                // Error View
                if let error = viewModel.error {
                    errorView(error)
                }
            }
            .padding()
        }
        .navigationTitle("Pool Statistics")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadPoolData()
        }
        .task {
            await viewModel.loadPoolData()
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("USDC Pool")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Real-time lending statistics")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var statisticsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            // Supply Statistics
            StatisticCard(
                title: "Supply APR",
                value: viewModel.supplyAPR,
                icon: "arrow.up.circle.fill",
                color: .green,
                isLoading: viewModel.isLoading
            )
            
            StatisticCard(
                title: "Supply APY",
                value: viewModel.supplyAPY,
                icon: "percent",
                color: .green,
                isLoading: viewModel.isLoading
            )
            
            // Borrow Statistics
            StatisticCard(
                title: "Borrow APR",
                value: viewModel.borrowAPR,
                icon: "arrow.down.circle.fill",
                color: .orange,
                isLoading: viewModel.isLoading
            )
            
            StatisticCard(
                title: "Borrow APY",
                value: viewModel.borrowAPY,
                icon: "percent",
                color: .orange,
                isLoading: viewModel.isLoading
            )
            
            // Pool Metrics
            StatisticCard(
                title: "Utilization",
                value: viewModel.utilization,
                icon: "chart.pie.fill",
                color: .blue,
                isLoading: viewModel.isLoading
            )
            
            StatisticCard(
                title: "Total Supply",
                value: viewModel.totalSupply,
                icon: "dollarsign.circle.fill",
                color: .purple,
                isLoading: viewModel.isLoading
            )
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Error loading pool data")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await viewModel.loadPoolData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            } else {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

struct PoolStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PoolStatisticsView(poolId: "test-pool-id")
        }
    }
} 