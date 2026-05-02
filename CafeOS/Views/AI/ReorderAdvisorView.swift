import SwiftUI

struct ReorderAdvisorView: View {
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @EnvironmentObject var supplierVM: SupplierViewModel
    @EnvironmentObject var aiVM: AIViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header explanation
                VStack(alignment: .leading, spacing: 6) {
                    Text("Smart Reorder Advisor")
                        .font(.title2.bold())
                    Text("AI-powered analysis of your low-stock items. Recommendations are sorted by urgency.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                // No low-stock items state
                if inventoryVM.lowStockItems.isEmpty && !aiVM.isLoading {
                    EmptyStateView(
                        icon: "checkmark.seal.fill",
                        title: "All stocked up!",
                        subtitle: "No items are currently below their reorder threshold."
                    )
                    .padding(.top, 40)

                // Error state
                } else if aiVM.showError {
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
                                await aiVM.fetchRecommendations(
                                    items: inventoryVM.items,
                                    suppliers: supplierVM.suppliers
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brown)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)

                // Loading state
                } else if aiVM.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Analyzing your inventory…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)

                // Results
                } else if aiVM.hasLoaded {
                    if aiVM.recommendations.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.seal.fill",
                            title: "All good!",
                            subtitle: "No reorder recommendations at this time."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(aiVM.sortedRecommendations) { advice in
                                ReorderAdviceCard(advice: advice)
                            }
                        }
                        .padding(.horizontal)
                    }

                // Pre-load state — show low stock summary before tapping refresh
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(inventoryVM.lowStockItems.count) item(s) need attention")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        ForEach(inventoryVM.lowStockItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.subheadline.bold())
                                    Text("\(String(format: "%.1f", item.quantity)) / \(String(format: "%.1f", item.minimumThreshold)) \(item.unit)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("LOW")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red)
                                    .cornerRadius(6)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Reorder Advisor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await aiVM.fetchRecommendations(
                            items: inventoryVM.items,
                            suppliers: supplierVM.suppliers
                        )
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Refresh")
                    }
                }
                .disabled(aiVM.isLoading)
            }
        }
        // Auto-fetch on first appearance only
        .task {
            guard !aiVM.hasLoaded && !inventoryVM.lowStockItems.isEmpty else { return }
            await aiVM.fetchRecommendations(
                items: inventoryVM.items,
                suppliers: supplierVM.suppliers
            )
        }
    }
}

// MARK: — Advice Card

private struct ReorderAdviceCard: View {
    let advice: ReorderAdvice

    var urgencyColor: Color {
        switch advice.urgency {
        case "critical": return .red
        case "high":     return .orange
        default:         return .yellow
        }
    }

    var urgencyIcon: String {
        switch advice.urgency {
        case "critical": return "exclamationmark.triangle.fill"
        case "high":     return "exclamationmark.circle.fill"
        default:         return "info.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: item name + urgency badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(advice.itemName)
                        .font(.headline)
                    Text(advice.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Label(advice.urgency.capitalized, systemImage: urgencyIcon)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(urgencyColor)
                    .cornerRadius(8)
            }

            Divider()

            // Details row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Order Qty")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.0f", advice.recommendedQty)) \(advice.unit)")
                        .font(.subheadline.bold())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Supplier")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(advice.supplierName)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lead Time")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(advice.deliveryDays)d")
                        .font(.subheadline)
                }
                Spacer()
                if advice.orderToday {
                    Text("Order Today")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brown)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
