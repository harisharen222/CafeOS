import SwiftUI

struct SpendingInsightsView: View {
    @EnvironmentObject var orderVM: OrderViewModel
    @EnvironmentObject var supplierVM: SupplierViewModel
    @EnvironmentObject var aiVM: AIViewModel

    var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header explanation
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Spending Intelligence")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("AI-powered analysis of your delivered orders and purchasing patterns.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Error state
                    if aiVM.showError {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text(aiVM.errorMessage ?? AppError.aiServiceFailed.errorDescription ?? "")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            Button("Try Again") {
                                Task {
                                    await aiVM.fetchSpendingInsights(
                                        orders: orderVM.orders,
                                        suppliers: supplierVM.suppliers
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.dashCrimson)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)

                    // Loading state
                    } else if aiVM.isLoadingInsights {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.4)
                                .tint(Color.dashCrimson)
                            Text("Analyzing spending history…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)

                    // Results
                    } else if let insight = aiVM.spendingInsight {
                        VStack(spacing: 16) {
                            
                            // Top Stats Row
                            HStack(spacing: 12) {
                                InsightStatCard(
                                    title: "Top Supplier",
                                    value: insight.topSupplier ?? "N/A",
                                    icon: "building.2.fill",
                                    color: .blue
                                )
                                InsightStatCard(
                                    title: "Top Category",
                                    value: insight.topCategory ?? "N/A",
                                    icon: "tag.fill",
                                    color: .purple
                                )
                            }
                            
                            // Summary Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(Color.dashCrimson)
                                    Text("Executive Summary")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Text(insight.summary)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.dashCard)
                            .cornerRadius(16)
                            
                            // Highlights Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text("Key Highlights")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(insight.highlights, id: \.self) { highlight in
                                        HStack(alignment: .top, spacing: 10) {
                                            Circle()
                                                .fill(Color.dashCrimson)
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 6)
                                            Text(highlight)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.dashCard)
                            .cornerRadius(16)

                        }
                        .padding(.horizontal)

                    // Pre-load state
                    } else {
                        VStack(spacing: 16) {
                            let deliveredCount = orderVM.orders.filter { $0.status == .received }.count
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("\(deliveredCount) delivered orders available for analysis.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Spending Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await aiVM.fetchSpendingInsights(
                            orders: orderVM.orders,
                            suppliers: supplierVM.suppliers
                        )
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Refresh")
                    }
                    .foregroundColor(Color.dashCrimson)
                }
                .disabled(aiVM.isLoadingInsights)
            }
        }
        .task {
            guard !aiVM.hasLoadedInsights else { return }
            let delivered = orderVM.orders.filter { $0.status == .received }
            if !delivered.isEmpty {
                await aiVM.fetchSpendingInsights(
                    orders: orderVM.orders,
                    suppliers: supplierVM.suppliers
                )
            }
        }
    }
}

// MARK: — Insight Stat Card

private struct InsightStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashCard)
        .cornerRadius(16)
    }
}
