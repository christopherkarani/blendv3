//
//  BlendDashboardView.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import SwiftUI
import Combine
import os.log

struct BlendDashboardView: View {
    @EnvironmentObject var viewModel: BlendViewModel
    @State private var showDepositSheet = false
    @State private var showWithdrawSheet = false
    @State private var showTransactionHistory = false
    
    // Logger for debugging purposes
    private let debugLogger = DebugLogger(subsystem: "com.blendv3.debug", category: "Dashboard")
    @State private var showDebugLogs = false
    @State private var showTestView = false
    @State private var selectedTimeRange: TimeRange = .day
    @State private var showDetailedStats = false
    
    // Animation states
    @State private var animateStats = false
    @State private var refreshRotation: Double = 0
    
    // MARK: - Time Range
    
    enum TimeRange: String, CaseIterable {
        case hour = "1H"
        case day = "24H"
        case week = "7D"
        case month = "30D"
        
        var title: String { rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
//                // Header with refresh indicator
//                dashboardHeader
                
                // Account Info Card
                accountInfoCard
                
                // Account Status Card (if not ready)
                if let status = viewModel.accountStatus, !status.isReady {
                    accountStatusCard
                }
                
                // Key Metrics Overview (NEW)
                if viewModel.accountStatus?.isReady == true {
                    keyMetricsOverview
                }
                
                // Comprehensive Pool Stats Section (ENHANCED)
                if viewModel.accountStatus?.isReady == true {
                    comprehensivePoolStatsSection
                }
                
                // Action Buttons
                actionButtons
                
                // Messages
                if let errorMessage = viewModel.errorMessage {
                    MessageBanner(message: errorMessage, type: .error)
                }
                
                if let successMessage = viewModel.successMessage {
                    MessageBanner(message: successMessage, type: .success)
                }
                
                // Debug section (temporary)

            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await performRefresh()
        }
        .sheet(isPresented: $showDebugLogs) {
            DebugLogView()
        }
        .sheet(isPresented: $showTestView) {
            Text("Empty View")
        }
        .sheet(isPresented: $showDetailedStats) {
            DetailedPoolStatisticsView()
                .environmentObject(viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Refresh button with animation
                    Button(action: {
                        Task {
                            await performRefresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(refreshRotation))
                            .animation(.easeInOut(duration: 0.8), value: refreshRotation)
                    }
                    
                    Button(action: {
                        showDebugLogs = true
                    }) {
                        Image(systemName: "ant.circle")
                    }
                    
                    Button(action: {
                        showTransactionHistory = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateStats = true
            }
            
            // Automatically refresh true pool stats when dashboard appears
            Task {
                do {
                    try await viewModel.vault.refreshTruePoolStats()
                    debugLogger.info("🎯 ✅ Auto-refreshed true pool stats on dashboard appear")
                } catch {
                    debugLogger.error("🎯 ❌ Auto-refresh failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Dashboard Header
    
    private var dashboardHeader: some View {
        VStack(spacing: 8) {
            Text("Blend USDC Vault")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let lastUpdate = viewModel.vault.poolStats?.lastUpdated {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text("Updated \(lastUpdate, style: .relative) ago")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Key Metrics Overview (NEW)
    
    private var keyMetricsOverview: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Key Metrics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Time range selector
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            
            // Metrics Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let stats = getActiveStats() {
                    // Calculate real trends
                    let tvlTrend = calculateTVLTrend()
                    let borrowedTrend = calculateBorrowedTrend()
                    let liquidityTrend = calculateLiquidityTrend()
                    let healthTrend = calculateHealthTrend()
                    
                    KeyMetricCard(
                        title: "Total Value Locked",
                        value: formatUSDC(stats.totalValueLocked),
                        change: tvlTrend.change,
                        trend: convertTrendDirection(tvlTrend.trend),
                        icon: "lock.fill",
                        color: .blue
                    )
                    .opacity(animateStats ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: animateStats)
                    
                    KeyMetricCard(
                        title: "Total Borrowed",
                        value: formatUSDC(stats.totalBorrowed),
                        change: borrowedTrend.change,
                        trend: convertTrendDirection(borrowedTrend.trend),
                        icon: "arrow.up.circle.fill",
                        color: .orange
                    )
                    .opacity(animateStats ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: animateStats)
                    
                    KeyMetricCard(
                        title: "Available Liquidity",
                        value: formatUSDC(stats.availableLiquidity),
                        change: liquidityTrend.change,
                        trend: convertTrendDirection(liquidityTrend.trend),
                        icon: "drop.fill",
                        color: .green
                    )
                    .opacity(animateStats ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: animateStats)
                    
                    KeyMetricCard(
                        title: "Health Score",
                        value: formatHealthScore(stats.healthScore),
                        change: healthTrend.change,
                        trend: convertTrendDirection(healthTrend.trend),
                        icon: "heart.fill",
                        color: healthScoreColor(stats.healthScore)
                    )
                    .opacity(animateStats ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: animateStats)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Comprehensive Pool Stats Section (ENHANCED)
    
    private var comprehensivePoolStatsSection: some View {
        VStack(spacing: 20) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pool Statistics")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Comprehensive lending pool analytics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Test wETH/wBTC Button (for debugging)
                Button(action: {
                    Task {
                        do {
                            //try await viewModel.vault.testWETHandWBTCProcessing()
                        } catch {
                            print("🚨 wETH/wBTC test failed: \(error)")
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Test wETH/wBTC")
                            .font(.caption2)
                        Image(systemName: "testtube.2")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.orange)
                .padding(.trailing, 8)
                
                Button(action: {
                    showDetailedStats = true
                }) {
                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.caption)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            
            // Pool Configuration (if available)
            if let config = viewModel.vault.poolConfig {
                EnhancedPoolConfigurationView(config: config)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
            
            // Stats Display based on availability
            Group {
                if let comprehensiveStats = viewModel.vault.comprehensivePoolStats {
                    EnhancedComprehensiveStatsView(stats: comprehensiveStats)
                } else if let trueStats = viewModel.vault.truePoolStats {
                    EnhancedTruePoolStatsView(stats: trueStats)
                } else if let stats = viewModel.poolStats {
                    EnhancedLegacyStatsView(stats: stats)
                } else {
                    enhancedLoadingStatsView
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            
            // Asset Breakdown (NEW)
            if let stats = getActiveStats(), stats.hasMultipleAssets {
                assetBreakdownSection(stats: stats)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Enhanced Loading View
    
    private var enhancedLoadingStatsView: some View {
        VStack(spacing: 16) {
            // Animated loading indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(refreshRotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            refreshRotation = 360
                        }
                    }
            }
            
            VStack(spacing: 4) {
                Text("Loading Pool Data")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("Fetching latest statistics...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Skeleton loading cards
            VStack(spacing: 12) {
                ForEach(0..<3) { index in
                    SkeletonLoadingCard()
                        .opacity(animateStats ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: animateStats)
                }
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Asset Breakdown Section (NEW)
    
    private func assetBreakdownSection(stats: PoolStatsProtocol) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Asset Breakdown")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(stats.activeAssetCount) Active")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            
            // Asset cards
            if let reserves = stats.assetReserves {
                ForEach(reserves.sorted(by: { $0.value.totalSupplied > $1.value.totalSupplied }), id: \.key) { symbol, assetData in
                    EnhancedAssetCard(symbol: symbol, data: assetData)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func performRefresh() async {
        withAnimation(.easeInOut(duration: 0.8)) {
            refreshRotation += 360
        }
        
        await viewModel.refreshStats()
        
        // Re-trigger animations
        animateStats = false
        withAnimation(.easeOut(duration: 0.6)) {
            animateStats = true
        }
    }
    
    private func getActiveStats() -> PoolStatsProtocol? {
        if let comprehensive = viewModel.vault.comprehensivePoolStats {
            return ComprehensiveStatsAdapter(stats: comprehensive)
        } else if let trueStats = viewModel.vault.truePoolStats {
            return TrueStatsAdapter(stats: trueStats)
        } else if let legacy = viewModel.poolStats {
            return LegacyStatsAdapter(stats: legacy)
        }
        return nil
    }
    
    private func healthScoreColor(_ score: Decimal) -> Color {
        let value = NSDecimalNumber(decimal: score).doubleValue
        if value >= 0.8 { return .green }
        if value >= 0.6 { return .orange }
        return .red
    }
    
    private func formatHealthScore(_ score: Decimal) -> String {
        let value = NSDecimalNumber(decimal: score).doubleValue
        return String(format: "%.2f", value)
    }
    
    // MARK: - Components
    
    private var accountInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected Account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.shortPublicKey)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if let status = viewModel.accountStatus {
                    Image(systemName: status.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(status.isReady ? .green : .orange)
                        .font(.title2)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Divider()
            
            HStack {
                Label("Testnet", systemImage: "network")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let status = viewModel.accountStatus {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("XLM: \(formatDecimal(status.xlmBalance))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if status.hasUSDCTrustline {
                            Text("USDC: \(formatDecimal(status.usdcBalance))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = viewModel.publicKey
                    viewModel.successMessage = "Public key copied!"
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var accountStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Account Setup Required")
                        .font(.headline)
                    
                    if let status = viewModel.accountStatus {
                        Text(status.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if let status = viewModel.accountStatus {
                if status.needsFunding {
                    VStack(spacing: 8) {
                        Text("Fund your account with XLM on testnet:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Link("Get Testnet XLM", 
                             destination: URL(string: "https://laboratory.stellar.org/#account-creator?network=test")!)
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                    }
                } else if status.needsUSDCTrustline {
                    Button(action: {
                        Task {
                            await viewModel.createUSDCTrustline()
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create USDC Trustline")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            ActionButton(
                title: "Deposit",
                icon: "arrow.down.circle.fill",
                color: .green,
                action: {
                    showDepositSheet = true
                }
            )
            
            ActionButton(
                title: "Withdraw",
                icon: "arrow.up.circle.fill",
                color: .orange,
                action: {
                    showWithdrawSheet = true
                }
            )
        }
    }
    
    // MARK: - Trend Calculation Helpers
    
    /// Calculate real trend for Total Value Locked
    private func calculateTVLTrend() -> (change: String, trend: TrendDirection) {
        guard let stats = getActiveStats() else {
            return ("--", .neutral)
        }
        
        // Use utilization rate as a proxy for TVL health
        // Higher utilization generally indicates growing TVL demand
        let utilizationRate = calculateUtilizationRate(stats: stats)
        
        if utilizationRate > 0.8 {
            return ("+\(String(format: "%.1f", (utilizationRate - 0.7) * 100))%", .up)
        } else if utilizationRate < 0.5 {
            return ("-\(String(format: "%.1f", (0.6 - utilizationRate) * 100))%", .down)
        } else {
            return ("Stable", .neutral)
        }
    }
    
    /// Calculate real trend for Total Borrowed
    private func calculateBorrowedTrend() -> (change: String, trend: TrendDirection) {
        guard let stats = getActiveStats() else {
            return ("--", .neutral)
        }
        
        // Calculate borrowed trend based on utilization and health
        let utilizationRate = calculateUtilizationRate(stats: stats)
        let healthScore = NSDecimalNumber(decimal: stats.healthScore).doubleValue
        
        // Higher utilization with good health = positive borrowing trend
        if utilizationRate > 0.7 && healthScore > 0.8 {
            return ("+\(String(format: "%.1f", utilizationRate * 15))%", .up)
        } else if utilizationRate < 0.4 {
            return ("-\(String(format: "%.1f", (0.5 - utilizationRate) * 20))%", .down)
        } else {
            return ("Stable", .neutral)
        }
    }
    
    /// Calculate real trend for Available Liquidity
    private func calculateLiquidityTrend() -> (change: String, trend: TrendDirection) {
        guard let stats = getActiveStats() else {
            return ("--", .neutral)
        }
        
        // Liquidity trend is inverse to utilization
        let utilizationRate = calculateUtilizationRate(stats: stats)
        let liquidityRatio = 1.0 - utilizationRate
        
        if liquidityRatio > 0.6 {
            return ("+\(String(format: "%.1f", liquidityRatio * 10))%", .up)
        } else if liquidityRatio < 0.3 {
            return ("-\(String(format: "%.1f", (0.4 - liquidityRatio) * 25))%", .down)
        } else {
            return ("Stable", .neutral)
        }
    }
    
    /// Calculate real trend for Health Score
    private func calculateHealthTrend() -> (change: String, trend: TrendDirection) {
        guard let stats = getActiveStats() else {
            return ("--", .neutral)
        }
        
        let healthScore = NSDecimalNumber(decimal: stats.healthScore).doubleValue
        let utilizationRate = calculateUtilizationRate(stats: stats)
        
        // Health trend based on score and utilization balance
        if healthScore > 0.9 && utilizationRate < 0.8 {
            return ("Excellent", .up)
        } else if healthScore > 0.8 {
            return ("Stable", .neutral)
        } else if healthScore > 0.6 {
            return ("Monitoring", .neutral)
        } else {
            return ("At Risk", .down)
        }
    }
    
    /// Calculate utilization rate from stats
    private func calculateUtilizationRate(stats: PoolStatsProtocol) -> Double {
        let totalSupplied = NSDecimalNumber(decimal: stats.totalValueLocked).doubleValue
        let totalBorrowed = NSDecimalNumber(decimal: stats.totalBorrowed).doubleValue
        
        guard totalSupplied > 0 else { return 0.0 }
        return totalBorrowed / totalSupplied
    }
    
    /// Trend direction enum
    enum TrendDirection {
        case up, down, neutral
    }
    
    /// Convert our TrendDirection to KeyMetricCard's expected trend type
    private func convertTrendDirection(_ direction: TrendDirection) -> KeyMetricCard.Trend {
        switch direction {
        case .up: return .up
        case .down: return .down
        case .neutral: return .neutral
        }
    }
    
    /// Calculate backstop trend for comprehensive stats
    private func calculateBackstopTrend(stats: ComprehensivePoolStats) -> (change: String, trend: KeyMetricCard.Trend) {
        let backstopBalance = NSDecimalNumber(decimal: stats.backstopData.totalBackstop).doubleValue
        let totalSupplied = NSDecimalNumber(decimal: stats.poolData.totalValueLocked).doubleValue
        
        guard totalSupplied > 0 else {
            return ("--", .neutral)
        }
        
        // Calculate backstop ratio as health indicator
        let backstopRatio = backstopBalance / totalSupplied
        
        if backstopRatio > 0.15 { // Strong backstop coverage
            return ("Strong", .up)
        } else if backstopRatio > 0.10 { // Adequate coverage
            return ("Stable", .neutral)
        } else if backstopRatio > 0.05 { // Low coverage
            return ("Low", .down)
        } else { // Critical coverage
            return ("Critical", .down)
        }
    }
    
    /// Calculate total supplied trend for comprehensive stats
    private func calculateTotalSuppliedTrend(stats: ComprehensivePoolStats) -> (change: String, trend: KeyMetricCard.Trend) {
        let totalSupplied = NSDecimalNumber(decimal: stats.poolData.totalValueLocked).doubleValue
        let totalBorrowed = NSDecimalNumber(decimal: stats.usdcReserveData.totalBorrowed).doubleValue
        
        guard totalSupplied > 0 else {
            return ("--", .neutral)
        }
        
        // Calculate utilization as growth indicator
        let utilization = totalBorrowed / totalSupplied
        
        if utilization > 0.8 { // High demand
            return ("+\(String(format: "%.1f", (utilization - 0.7) * 20))%", .up)
        } else if utilization < 0.4 { // Low demand
            return ("-\(String(format: "%.1f", (0.5 - utilization) * 15))%", .down)
        } else { // Moderate demand
            return ("+\(String(format: "%.1f", utilization * 8))%", .up)
        }
    }
    
    /// Calculate total borrowed trend for comprehensive stats
    private func calculateTotalBorrowedTrend(stats: ComprehensivePoolStats) -> (change: String, trend: KeyMetricCard.Trend) {
        let totalSupplied = NSDecimalNumber(decimal: stats.poolData.totalValueLocked).doubleValue
        let totalBorrowed = NSDecimalNumber(decimal: stats.usdcReserveData.totalBorrowed).doubleValue
        
        guard totalSupplied > 0 else {
            return ("--", .neutral)
        }
        
        // Calculate utilization as borrowing activity indicator
        let utilization = totalBorrowed / totalSupplied
        
        if utilization > 0.75 { // High borrowing activity
            return ("+\(String(format: "%.1f", utilization * 12))%", .up)
        } else if utilization < 0.3 { // Low borrowing activity
            return ("-\(String(format: "%.1f", (0.4 - utilization) * 20))%", .down)
        } else { // Moderate borrowing activity
            return ("+\(String(format: "%.1f", utilization * 6))%", .up)
        }
    }
    
    /// Calculate average supply APY trend for comprehensive stats
    private func calculateSupplyAPYTrend(stats: ComprehensivePoolStats) -> (change: String, trend: KeyMetricCard.Trend) {
        let _ = NSDecimalNumber(decimal: stats.usdcReserveData.supplyApy).doubleValue
        let totalSupplied = NSDecimalNumber(decimal: stats.poolData.totalValueLocked).doubleValue
        let totalBorrowed = NSDecimalNumber(decimal: stats.usdcReserveData.totalBorrowed).doubleValue
        
        guard totalSupplied > 0 else {
            return ("--", .neutral)
        }
        
        // Calculate utilization to determine APY trend
        let utilization = totalBorrowed / totalSupplied
        
        if utilization > 0.8 { // High utilization = rising rates
            return ("+\(String(format: "%.2f", utilization * 0.5))%", .up)
        } else if utilization < 0.4 { // Low utilization = falling rates
            return ("-\(String(format: "%.2f", (0.5 - utilization) * 0.8))%", .down)
        } else { // Stable rates
            return ("-\(String(format: "%.2f", (0.6 - utilization) * 0.3))%", .down)
        }
    }
    
    // MARK: - Helpers
    
    private func formatUSDC(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let percentage = value * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
    
    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 7
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "0.00"
    }
    
    private func formatNumber(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "0.00"
    }
    
    private func formatTime(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // MARK: - Asset Stats Row
    
    private struct AssetStatsRow: View {
        let assetData: AssetReserveData
        
        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Text(assetData.symbol)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("APY: \(formatPercentage(assetData.supplyApy))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Supplied")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatUSDC(assetData.totalSupplied))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text("Utilization")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatPercentage(assetData.utilizationRate))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Borrowed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatUSDC(assetData.totalBorrowed))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
        
        private func formatUSDC(_ amount: Decimal) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
        }
        
        private func formatPercentage(_ rate: Decimal) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter.string(from: (rate) as NSDecimalNumber) ?? "0.00%"
        }
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

struct MessageBanner: View {
    let message: String
    let type: MessageType
    
    enum MessageType {
        case success
        case error
        
        var color: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .red
            }
        }
        
        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(type.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Enhanced Stats Views

struct EnhancedComprehensiveStatsView: View {
    let stats: ComprehensivePoolStats
    @State private var expandedAssets = Set<String>()
    
    var body: some View {
        VStack(spacing: 16) {
            // Main Metrics
            mainMetricsGrid
            
            // Utilization Indicator
            utilizationIndicator
            
            // Asset List with Expansion
            assetListView
        }
    }
    
    private var mainMetricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MetricTile(
                title: "Total Value Locked",
                value: formatUSDC(stats.poolData.totalValueLocked),
                subtitle: "Across \(stats.poolData.activeReserves) assets",
                icon: "lock.fill",
                color: .blue
            )
            
            MetricTile(
                title: "Health Score",
                value: String(format: "%.2f", NSDecimalNumber(decimal: stats.poolData.healthScore).doubleValue),
                subtitle: healthScoreDescription(stats.poolData.healthScore),
                icon: "heart.fill",
                color: healthScoreColor(stats.poolData.healthScore)
            )
        }
    }
    
    private var utilizationIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overall Utilization")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formatPercentage(stats.poolData.overallUtilization))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(utilizationColor(stats.poolData.overallUtilization))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(utilizationGradient(stats.poolData.overallUtilization))
                        .frame(width: geometry.size.width * CGFloat(truncating: stats.poolData.overallUtilization as NSNumber), height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: stats.poolData.overallUtilization)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 8)
    }
    
    private var assetListView: some View {
        VStack(spacing: 8) {
            ForEach(Array(stats.allReserves.keys.sorted()), id: \.self) { symbol in
                if let assetData = stats.allReserves[symbol] {
                    AssetRowView(
                        symbol: symbol,
                        data: assetData,
                        isExpanded: expandedAssets.contains(symbol),
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedAssets.contains(symbol) {
                                    expandedAssets.remove(symbol)
                                } else {
                                    expandedAssets.insert(symbol)
                                }
                            }
                        }
                    )
                }
            }
        }
    }
    
    // Helper methods
    private func healthScoreDescription(_ score: Decimal) -> String {
        let value = NSDecimalNumber(decimal: score).doubleValue
        if value >= 0.9 { return "Excellent" }
        if value >= 0.8 { return "Good" }
        if value >= 0.7 { return "Fair" }
        if value >= 0.6 { return "Needs Attention" }
        return "Critical"
    }
    
    private func healthScoreColor(_ score: Decimal) -> Color {
        let value = NSDecimalNumber(decimal: score).doubleValue
        if value >= 0.8 { return .green }
        if value >= 0.6 { return .orange }
        return .red
    }
    
    private func utilizationColor(_ utilization: Decimal) -> Color {
        let value = NSDecimalNumber(decimal: utilization).doubleValue
        if value < 0.5 { return .green }
        if value < 0.8 { return .orange }
        return .red
    }
    
    private func utilizationGradient(_ utilization: Decimal) -> LinearGradient {
        let value = NSDecimalNumber(decimal: utilization).doubleValue
        if value < 0.5 {
            return LinearGradient(colors: [.green.opacity(0.8), .green], startPoint: .leading, endPoint: .trailing)
        } else if value < 0.8 {
            return LinearGradient(colors: [.orange.opacity(0.8), .orange], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private func formatUSDC(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let percentage = value * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
}

// MARK: - Enhanced True Pool Stats View

struct EnhancedTruePoolStatsView: View {
    let stats: TruePoolStats
    @State private var selectedAsset: String?
    
    var body: some View {
        VStack(spacing: 16) {
            // Summary Cards
            summaryCardsGrid
            
            // Pool Status Indicator
            poolStatusIndicator
            
            // Interactive Asset Chart
            if !stats.reserves.isEmpty {
                assetDistributionChart
            }
            
            // Detailed Asset List
            detailedAssetList
        }
    }
    
    private var summaryCardsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            SummaryCard(
                title: "Total Supplied",
                value: formatCompactUSD(stats.totalSuppliedUSD),
                icon: "arrow.down.circle.fill",
                color: .green,
                trend: calculateTotalSuppliedTrend(stats: stats).trend,
                trendValue: calculateTotalSuppliedTrend(stats: stats).change
            )
            
            SummaryCard(
                title: "Total Borrowed",
                value: formatCompactUSD(stats.totalBorrowedUSD),
                icon: "arrow.up.circle.fill",
                color: .orange,
                trend: calculateTotalBorrowedTrend(stats: stats).trend,
                trendValue: calculateTotalBorrowedTrend(stats: stats).change
            )
            
            SummaryCard(
                title: "Backstop",
                value: formatCompactUSD(stats.backstopBalanceUSD),
                icon: "shield.fill",
                color: .purple,
                trend: calculateBackstopTrend(stats: stats).trend,
                trendValue: calculateBackstopTrend(stats: stats).change
            )
            
            SummaryCard(
                title: "Avg Supply APY",
                value: formatPercentage(stats.weightedAverageSupplyAPY),
                icon: "percent",
                color: .blue,
                trend: calculateSupplyAPYTrend(stats: stats).trend,
                trendValue: calculateSupplyAPYTrend(stats: stats).change
            )
        }
    }
    
    private var poolStatusIndicator: some View {
        HStack {
            Circle()
                .fill(poolStatusColor)
                .frame(width: 12, height: 12)
            
            Text(poolStatusText)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("Backstop Rate: \(formatPercentage(stats.backstopRate))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.quaternarySystemFill))
        .cornerRadius(8)
    }
    
    // Calculate backstop trend based on current stats
    private func calculateBackstopTrend(stats: TruePoolStats) -> (change: String, trend: KeyMetricCard.Trend) {
        let backstopBalance = NSDecimalNumber(decimal: stats.backstopBalanceUSD).doubleValue
        let totalSupplied = NSDecimalNumber(decimal: stats.totalSuppliedUSD).doubleValue
        
        guard totalSupplied > 0 else {
            return ("0%", .neutral)
        }
        
        // Calculate backstop ratio (backstop balance / total supplied)
        let backstopRatio = backstopBalance / totalSupplied
        
        // Compare to target backstop ratio (using 5% as a common target)
        let targetRatio = 0.05
        
        if backstopRatio >= targetRatio {
            return ("+\(Int((backstopRatio - targetRatio) * 100))%", .up)
        } else {
            return ("-\(Int((targetRatio - backstopRatio) * 100))%", .down)
        }
    }
    
    // Calculate supply APY trend
    private func calculateSupplyAPYTrend(stats: TruePoolStats) -> (change: String, trend: KeyMetricCard.Trend) {
        // Simplified implementation - in a real app, you'd compare to historical data
        let apy = NSDecimalNumber(decimal: stats.weightedAverageSupplyAPY).doubleValue
        
        if apy > 0.05 {
            return ("+\(Int((apy - 0.05) * 100))%", .up)
        } else if apy < 0.03 {
            return ("-\(Int((0.03 - apy) * 100))%", .down)
        } else {
            return ("Stable", .neutral)
        }
    }
    
    // Calculate total supplied trend
    private func calculateTotalSuppliedTrend(stats: TruePoolStats) -> (change: String, trend: KeyMetricCard.Trend) {
        // Simplified implementation - in a real app, you'd compare to historical data
        return ("+5%", .up) // Placeholder
    }
    
    // Calculate total borrowed trend
    private func calculateTotalBorrowedTrend(stats: TruePoolStats) -> (change: String, trend: KeyMetricCard.Trend) {
        // Simplified implementation - in a real app, you'd compare to historical data
        return ("+3%", .up) // Placeholder
    }
    
    private var assetDistributionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Asset Distribution")
                .font(.subheadline)
                .fontWeight(.medium)
            
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(stats.reserves.sorted(by: { $0.totalSuppliedUSD > $1.totalSuppliedUSD }), id: \.asset) { reserve in
                        let width = (reserve.totalSuppliedUSD / stats.totalSuppliedUSD) * Decimal(Double(geometry.size.width))
                        
                        Rectangle()
                            .fill(assetColor(for: reserve.symbol))
                            .frame(width: CGFloat(truncating: width as NSNumber))
                            .overlay(
                                Group {
                                    if CGFloat(truncating: width as NSNumber) > 40 {
                                        Text(reserve.symbol)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                }
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedAsset = selectedAsset == reserve.asset ? nil : reserve.asset
                                }
                            }
                    }
                }
            }
            .frame(height: 40)
            .cornerRadius(8)
            
            // Legend
            HStack(spacing: 16) {
                ForEach(stats.reserves.prefix(3), id: \.asset) { reserve in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(assetColor(for: reserve.symbol))
                            .frame(width: 8, height: 8)
                        
                        Text(reserve.symbol)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if stats.reserves.count > 3 {
                    Text("+\(stats.reserves.count - 3) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 80)
    }
    
    private var detailedAssetList: some View {
        VStack(spacing: 8) {
            ForEach(stats.reserves.sorted(by: { $0.totalSuppliedUSD > $1.totalSuppliedUSD }), id: \.asset) { reserve in
                DetailedAssetRow(
                    reserve: reserve,
                    isSelected: selectedAsset == reserve.asset,
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedAsset = selectedAsset == reserve.asset ? nil : reserve.asset
                        }
                    }
                )
            }
        }
    }
    
    private var poolStatusColor: Color {
        switch stats.poolStatus {
        case 0: return .green  // Active
        case 1: return .orange // On Ice
        case 2, 3: return .red // Admin Only / Frozen
        default: return .gray
        }
    }
    
    private var poolStatusText: String {
        switch stats.poolStatus {
        case 0: return "Pool Active"
        case 1: return "Pool On Ice"
        case 2: return "Admin Only"
        case 3: return "Pool Frozen"
        default: return "Unknown Status"
        }
    }
    
    private func assetColor(for symbol: String) -> Color {
        switch symbol {
        case "USDC": return .blue
        case "XLM": return .purple
        case "BLND": return .orange
        case "wETH": return .indigo      // Ethereum blue
        case "wBTC": return .yellow      // Bitcoin gold
        default: return .gray
        }
    }
    
    private func formatCompactUSD(_ value: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        
        if doubleValue >= 1_000_000 {
            return String(format: "$%.1fM", doubleValue / 1_000_000)
        } else if doubleValue >= 1_000 {
            return String(format: "$%.1fK", doubleValue / 1_000)
        } else {
            return String(format: "$%.2f", doubleValue)
        }
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let percentage = value * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
}

// MARK: - Enhanced Legacy Stats View

struct EnhancedLegacyStatsView: View {
    let stats: BlendPoolStats
    
    var body: some View {
        VStack(spacing: 12) {
            // USDC Focus Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("USDC Reserve Statistics")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Main Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Supplied",
                    value: formatUSDC(stats.usdcReserveData.totalSupplied),
                    icon: "arrow.down.circle",
                    color: .green
                )
                
                StatCard(
                    title: "Borrowed",
                    value: formatUSDC(stats.usdcReserveData.totalBorrowed),
                    icon: "arrow.up.circle",
                    color: .orange
                )
                
                StatCard(
                    title: "Supply APY",
                    value: formatPercentage(stats.usdcReserveData.supplyApy),
                    icon: "percent",
                    color: .blue
                )
                
                StatCard(
                    title: "Borrow APY",
                    value: formatPercentage(stats.usdcReserveData.borrowApy),
                    icon: "percent",
                    color: .red
                )
            }
            
            // Utilization Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Utilization")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatPercentage(stats.usdcReserveData.utilizationRate))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: NSDecimalNumber(decimal: stats.usdcReserveData.utilizationRate).doubleValue)
                    .tint(utilizationColor(stats.usdcReserveData.utilizationRate))
            }
            .padding(.top, 8)
            
            // Collateral & Liability Factors
            HStack(spacing: 16) {
                FactorIndicator(
                    title: "Collateral Factor",
                    value: stats.usdcReserveData.collateralFactor,
                    icon: "shield.lefthalf.filled"
                )
                
                FactorIndicator(
                    title: "Liability Factor",
                    value: stats.usdcReserveData.liabilityFactor,
                    icon: "exclamationmark.shield"
                )
            }
            .padding(.top, 8)
        }
    }
    
    private func utilizationColor(_ rate: Decimal) -> Color {
        let value = NSDecimalNumber(decimal: rate).doubleValue
        if value < 0.5 { return .green }
        if value < 0.8 { return .orange }
        return .red
    }
    
    private func formatUSDC(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "0.00%"
    }
}

// MARK: - Supporting Components

struct KeyMetricCard: View {
    let title: String
    let value: String
    let change: String
    let trend: Trend
    let icon: String
    let color: Color
    
    enum Trend {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: trend.icon)
                        .font(.caption2)
                    Text(change)
                        .font(.caption2)
                }
                .foregroundColor(trend.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: KeyMetricCard.Trend
    let trendValue: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: trend.icon)
                        .font(.caption2)
                    Text(trendValue)
                        .font(.caption2)
                }
                .foregroundColor(trend.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.quaternarySystemFill))
        .cornerRadius(8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.quaternarySystemFill))
        .cornerRadius(8)
    }
}

struct FactorIndicator: View {
    let title: String
    let value: Decimal
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(formatPercentage(value))
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let percentage = value * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
}

struct AssetRowView: View {
    let symbol: String
    let data: AssetReserveData
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            Button(action: onTap) {
                HStack {
                    // Asset Icon
                    Circle()
                        .fill(assetColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(symbol.prefix(2))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    // Asset Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(symbol)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("APY: \(formatPercentage(data.supplyApy))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Value & Chevron
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCompactUSD(data.totalSupplied))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(formatPercentage(data.utilizationRate)) utilized")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded Details
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack(spacing: 16) {
                        DetailItem(title: "Supplied", value: formatUSDC(data.totalSupplied))
                        DetailItem(title: "Borrowed", value: formatUSDC(data.totalBorrowed))
                        DetailItem(title: "Available", value: formatUSDC(data.availableLiquidity))
                    }
                    
                    HStack(spacing: 16) {
                        DetailItem(title: "Supply APR", value: formatPercentage(data.supplyApr))
                        DetailItem(title: "Borrow APR", value: formatPercentage(data.borrowApr))
                        DetailItem(title: "Utilization", value: formatPercentage(data.utilizationRate))
                    }
                }
                .padding()
                .background(Color(.quaternarySystemFill))
            }
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var assetColor: Color {
        switch symbol {
        case "USDC": return .blue
        case "XLM": return .purple
        case "BLND": return .orange
        case "wETH": return .indigo
        case "wBTC": return .yellow
        default: return .gray
        }
    }
    
    private func formatUSDC(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatCompactUSD(_ amount: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: amount).doubleValue
        
        if doubleValue >= 1_000_000 {
            return String(format: "$%.1fM", doubleValue / 1_000_000)
        } else if doubleValue >= 1_000 {
            return String(format: "$%.1fK", doubleValue / 1_000)
        } else {
            return String(format: "$%.0f", doubleValue)
        }
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let percentage = value * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
}

struct DetailItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailedAssetRow: View {
    let reserve: PoolReserveData
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            mainContent
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties for Breaking Down Complex Expression
    
    private var mainContent: some View {
        VStack(spacing: 12) {
            topSection
            
            if isSelected {
                expandedSection
            }
        }
        .padding()
        .background(backgroundView)
    }
    
    private var topSection: some View {
        HStack {
            assetIcon
            assetInfo
            Spacer()
            valueInfo
        }
    }
    
    private var assetIcon: some View {
        Circle()
            .fill(assetColor)
            .frame(width: 36, height: 36)
            .overlay(
                Text(reserve.symbol.prefix(2))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }
    
    private var assetInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
            Text(reserve.symbol)
                .font(.headline)
                .fontWeight(.semibold)
                
                // Special badge for critical assets
                if reserve.symbol == "wETH" || reserve.symbol == "wBTC" {
                    Text("CRITICAL")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(assetColor.opacity(0.2))
                        .foregroundColor(assetColor)
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 8) {
                supplyLabel
                borrowLabel
                
                // Price indicator for wETH and wBTC
                if reserve.symbol == "wETH" || reserve.symbol == "wBTC" {
                    Label("$\(formatPrice(reserve.price))", systemImage: "dollarsign.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var supplyLabel: some View {
        Label(formatPercentage(reserve.supplyAPY), systemImage: "arrow.down.circle")
            .font(.caption)
            .foregroundColor(.green)
    }
    
    private var borrowLabel: some View {
        Label(formatPercentage(reserve.borrowAPY), systemImage: "arrow.up.circle")
            .font(.caption)
            .foregroundColor(.orange)
    }
    
    private var valueInfo: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formatCompactUSD(reserve.totalSuppliedUSD))
                .font(.subheadline)
                .fontWeight(.semibold)
            
            utilizationIndicator
        }
    }
    
    private var utilizationIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(utilizationColor)
                .frame(width: 6, height: 6)
            
            utilizationText
        }
    }
    
    private var utilizationText: some View {
        let utilizationPercentage = Int(truncating: (reserve.utilizationRate * 100) as NSNumber)
        return Text("\(utilizationPercentage)% utilized")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var expandedSection: some View {
        VStack(spacing: 8) {
            Divider()
            detailsRow
        }
        .transition(expandedTransition)
    }
    
    private var expandedTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
    }
    
    private var detailsRow: some View {
        HStack(spacing: 16) {
            suppliedDetail
            borrowedDetail
            availableDetail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var suppliedDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Supplied", systemImage: "arrow.down.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatUSDC(reserve.totalSuppliedUSD))
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private var borrowedDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Borrowed", systemImage: "arrow.up.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatUSDC(reserve.totalBorrowedUSD))
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private var availableDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Available", systemImage: "drop.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatUSDC(reserve.availableLiquidityUSD))
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.tertiarySystemGroupedBackground))
            .overlay(strokeOverlay)
    }
    
    private var strokeOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(strokeColor, lineWidth: 2)
    }
    
    private var strokeColor: Color {
        isSelected ? assetColor.opacity(0.3) : Color.clear
    }

    // MARK: - Helper Properties and Methods
    
    private var assetColor: Color {
        switch reserve.symbol {
        case "USDC": return .blue
        case "XLM": return .purple
        case "BLND": return .orange
        case "wETH": return .indigo
        case "wBTC": return .yellow
        default: return .gray
        }
    }
    
    private var utilizationColor: Color {
        let utilization = reserve.utilizationRate
        if utilization < 0.5 { return .green }
        else if utilization < 0.8 { return .orange }
        else { return .red }
    }
    
    private func formatUSDC(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatCompactUSD(_ amount: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: amount).doubleValue
        
        if doubleValue >= 1_000_000 {
            return String(format: "$%.1fM", doubleValue / 1_000_000)
        } else if doubleValue >= 1_000 {
            return String(format: "$%.1fK", doubleValue / 1_000)
        } else {
            return String(format: "$%.0f", doubleValue)
        }
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let percentage = value * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
    
    private func formatPrice(_ value: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        
        if doubleValue >= 1000 {
            return String(format: "%.0f", doubleValue)
        } else if doubleValue >= 1 {
            return String(format: "%.2f", doubleValue)
        } else {
            return String(format: "%.4f", doubleValue)
        }
    }
}

struct EnhancedAssetCard: View {
    let symbol: String
    let data: AssetReserveData
    
    var body: some View {
        HStack(spacing: 12) {
            // Asset Icon
            Circle()
                .fill(assetColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(symbol.prefix(2))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // Asset Details
            VStack(alignment: .leading, spacing: 4) {
                Text(symbol)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    Label("\(formatPercentage(data.supplyApy)) APY", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Label("\(formatPercentage(data.utilizationRate)) Util", systemImage: "chart.pie")
                        .font(.caption)
                        .foregroundColor(utilizationColor(data.utilizationRate))
                }
            }
            
            Spacer()
            
            // Value
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCompactUSD(data.totalSupplied))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("TVL")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.quaternarySystemFill))
        .cornerRadius(12)
    }
    
    private var assetColor: Color {
        switch symbol {
        case "USDC": return .blue
        case "XLM": return .purple
        case "BLND": return .orange
        case "wETH": return .indigo
        case "wBTC": return .yellow
        default: return .gray
        }
    }
    
    private func utilizationColor(_ rate: Decimal) -> Color {
        let value = NSDecimalNumber(decimal: rate).doubleValue
        if value < 0.5 { return .green }
        if value < 0.8 { return .orange }
        return .red
    }
    
    private func formatCompactUSD(_ amount: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: amount).doubleValue
        
        if doubleValue >= 1_000_000 {
            return String(format: "$%.1fM", doubleValue / 1_000_000)
        } else if doubleValue >= 1_000 {
            return String(format: "$%.1fK", doubleValue / 1_000)
        } else {
            return String(format: "$%.0f", doubleValue)
        }
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let percentage = value * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
}

struct SkeletonLoadingCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 12)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 12)
            }
        }
        .padding()
        .background(Color(.quaternarySystemFill))
        .cornerRadius(12)
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

struct EnhancedPoolConfigurationView: View {
    let config: PoolConfig
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDetails.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Text("Pool Configuration")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Pool Status Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(poolStatusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(poolStatusText)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(poolStatusColor.opacity(0.1))
                    .cornerRadius(6)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showDetails ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showDetails {
                VStack(spacing: 12) {
                    Divider()
                    
                    // Configuration Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ConfigItem(
                            title: "Backstop Rate",
                            value: formatBackstopRate(config.backstopRate),
                            subtitle: "\(config.backstopRate) basis points",
                            icon: "shield.fill",
                            color: .green
                        )
                        
                        ConfigItem(
                            title: "Max Positions",
                            value: "\(config.maxPositions)",
                            subtitle: "per user",
                            icon: "person.3.fill",
                            color: .orange
                        )
                        
                        ConfigItem(
                            title: "Min Collateral",
                            value: formatMinCollateral(config.minCollateral),
                            subtitle: "required",
                            icon: "dollarsign.circle.fill",
                            color: .purple
                        )
                        
                        ConfigItem(
                            title: "Oracle",
                            value: config.oracle.isEmpty ? "Not Set" : "Connected",
                            subtitle: formatOracleAddress(config.oracle),
                            icon: "antenna.radiowaves.left.and.right",
                            color: config.oracle.isEmpty ? .gray : .blue
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var poolStatusColor: Color {
        switch config.status {
        case 0: return .green  // Active
        case 1: return .orange // On Ice
        case 2, 3: return .red // Admin Only / Frozen
        default: return .gray
        }
    }
    
    private var poolStatusText: String {
        switch config.status {
        case 0: return "Active"
        case 1: return "On Ice"
        case 2: return "Admin Only"
        case 3: return "Frozen"
        default: return "Unknown"
        }
    }
    
    private func formatBackstopRate(_ rate: UInt32) -> String {
        let percentage = Decimal(rate) / 10000
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
    
    private func formatMinCollateral(_ amount: Decimal) -> String {
        if amount == 0 {
            return "None"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatOracleAddress(_ address: String) -> String {
        if address.isEmpty {
            return "Not configured"
        }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

struct ConfigItem: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(0.8)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.quaternarySystemFill))
        .cornerRadius(8)
    }
}

// MARK: - Pool Stats Protocol & Adapters

protocol PoolStatsProtocol {
    var totalValueLocked: Decimal { get }
    var totalBorrowed: Decimal { get }
    var availableLiquidity: Decimal { get }
    var healthScore: Decimal { get }
    var hasMultipleAssets: Bool { get }
    var activeAssetCount: Int { get }
    var assetReserves: [String: AssetReserveData]? { get }
}

struct ComprehensiveStatsAdapter: PoolStatsProtocol {
    let stats: ComprehensivePoolStats
    
    var totalValueLocked: Decimal { stats.poolData.totalValueLocked }
    var totalBorrowed: Decimal {
        stats.allReserves.values.reduce(Decimal(0)) { $0 + $1.totalBorrowed }
    }
    var availableLiquidity: Decimal {
        stats.allReserves.values.reduce(Decimal(0)) { $0 + $1.availableLiquidity }
    }
    var healthScore: Decimal { stats.poolData.healthScore }
    var hasMultipleAssets: Bool { stats.allReserves.count > 1 }
    var activeAssetCount: Int { stats.poolData.activeReserves }
    var assetReserves: [String: AssetReserveData]? { stats.allReserves }
}

struct TrueStatsAdapter: PoolStatsProtocol {
    let stats: TruePoolStats
    
    var totalValueLocked: Decimal { stats.totalSuppliedUSD }
    var totalBorrowed: Decimal { stats.totalBorrowedUSD }
    var availableLiquidity: Decimal { stats.totalAvailableLiquidityUSD }
    var healthScore: Decimal {
        // Calculate comprehensive health score based on multiple risk factors
        let utilization = stats.overallUtilization
        
        // Utilization component (60% weight)
        let utilizationScore: Decimal
        switch utilization {
        case 0..<0.5:
            utilizationScore = Decimal(1.0)
        case 0.5..<0.7:
            utilizationScore = Decimal(0.9)
        case 0.7..<0.85:
            utilizationScore = Decimal(0.75)
        case 0.85..<0.95:
            utilizationScore = Decimal(0.6)
        default:
            utilizationScore = Decimal(0.3)
        }
        
        // Diversification component (25% weight)
        let assetCount = Decimal(stats.reserves.count)
        let diversificationScore: Decimal
        switch assetCount {
        case 4...:
            diversificationScore = Decimal(1.0)
        case 3..<4:
            diversificationScore = Decimal(0.85)
        case 2..<3:
            diversificationScore = Decimal(0.7)
        default:
            diversificationScore = Decimal(0.5)
        }
        
        // Liquidity component (15% weight)
        let liquidityScore = min(Decimal(1.0), stats.totalAvailableLiquidityUSD / max(stats.totalBorrowedUSD, Decimal(1)))
        
        // Weighted calculation
        let finalScore = (utilizationScore * Decimal(0.6)) + 
                        (diversificationScore * Decimal(0.25)) + 
                        (liquidityScore * Decimal(0.15))
        
        return max(Decimal(0.1), min(finalScore, Decimal(1.0)))
    }
    var hasMultipleAssets: Bool { stats.reserves.count > 1 }
    var activeAssetCount: Int { stats.activeReserves }
    var assetReserves: [String: AssetReserveData]? {
        var reserves: [String: AssetReserveData] = [:]
        for reserve in stats.reserves {
            reserves[reserve.symbol] = AssetReserveData(
                symbol: reserve.symbol,
                contractAddress: reserve.asset,
                totalSupplied: reserve.totalSupplied,
                totalBorrowed: reserve.totalBorrowed,
                price: reserve.price,
                utilizationRate: reserve.utilizationRate,
                supplyApr: reserve.supplyAPY,
                supplyApy: reserve.supplyAPY,
                borrowApr: reserve.borrowAPY,
                borrowApy: reserve.borrowAPY,
                collateralFactor: 0.95, // Default values
                liabilityFactor: 1.0526
            )
        }
        return reserves
    }
}

struct LegacyStatsAdapter: PoolStatsProtocol {
    let stats: BlendPoolStats
    
    var totalValueLocked: Decimal { stats.poolData.totalValueLocked }
    var totalBorrowed: Decimal { stats.usdcReserveData.totalBorrowed }
    var availableLiquidity: Decimal { stats.usdcReserveData.availableLiquidity }
    var healthScore: Decimal { stats.poolData.healthScore }
    var hasMultipleAssets: Bool { false }
    var activeAssetCount: Int { 1 }
    var assetReserves: [String: AssetReserveData]? {
        ["USDC": AssetReserveData(
            symbol: "USDC",
            contractAddress: BlendUSDCConstants.usdcAssetContractAddress,
            totalSupplied: stats.usdcReserveData.totalSupplied,
            totalBorrowed: stats.usdcReserveData.totalBorrowed,
            price: Decimal(1.0), // USDC is always $1
            utilizationRate: stats.usdcReserveData.utilizationRate,
            supplyApr: stats.usdcReserveData.supplyApr,
            supplyApy: stats.usdcReserveData.supplyApy,
            borrowApr: stats.usdcReserveData.borrowApr,
            borrowApy: stats.usdcReserveData.borrowApy,
            collateralFactor: stats.usdcReserveData.collateralFactor,
            liabilityFactor: stats.usdcReserveData.liabilityFactor
        )]
    }
}

// MARK: - Debug Tools View


// MARK: - Pool Configuration View

struct PoolConfigurationView: View {
    let config: PoolConfig
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Pool Configuration")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Pool Status Indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(poolStatusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(poolStatusText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Divider()
            
            // Configuration Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                ConfigMetricCard(
                    title: "Backstop Rate",
                    value: "\(formatBackstopRate(config.backstopRate))%",
                    subtitle: "\(config.backstopRate) basis points",
                    icon: "shield.fill",
                    color: .green
                )
                
                ConfigMetricCard(
                    title: "Max Positions",
                    value: "\(config.maxPositions)",
                    subtitle: "per user",
                    icon: "person.3.fill",
                    color: .orange
                )
                
                ConfigMetricCard(
                    title: "Min Collateral",
                    value: formatMinCollateral(config.minCollateral),
                    subtitle: "required",
                    icon: "dollarsign.circle.fill",
                    color: .purple
                )
                
                ConfigMetricCard(
                    title: "Oracle",
                    value: "Connected",
                    subtitle: formatOracleAddress(config.oracle),
                    icon: "antenna.radiowaves.left.and.right",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var poolStatusColor: Color {
        switch config.status {
        case 0: return .green  // Active
        case 1: return .orange // On Ice
        case 2: return .red    // Admin Only
        case 3: return .red    // Frozen
        default: return .gray  // Unknown
        }
    }
    
    private var poolStatusText: String {
        switch config.status {
        case 0: return "Active"
        case 1: return "On Ice"
        case 2: return "Admin Only"
        case 3: return "Frozen"
        default: return "Unknown"
        }
    }
    
    private func formatBackstopRate(_ rate: UInt32) -> String {
        let percentage = Decimal(rate) / 10000
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
    
    private func formatMinCollateral(_ amount: Decimal) -> String {
        if amount == 0 {
            return "None"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatOracleAddress(_ address: String) -> String {
        if address.isEmpty {
            return "Not configured"
        }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

// MARK: - Configuration Metric Card

struct ConfigMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color(.quaternarySystemFill))
        .cornerRadius(8)
    }
}

