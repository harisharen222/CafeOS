import SwiftUI

struct AutoDraftOrdersView: View {
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @EnvironmentObject var supplierVM: SupplierViewModel
    @EnvironmentObject var orderVM: OrderViewModel
    @EnvironmentObject var aiVM: AIViewModel
    @Environment(\.dismiss) var dismiss

    @State private var isSubmitting = false

    var groupedAdvice: [(String, [ReorderAdvice])] {
        let dict = Dictionary(grouping: aiVM.recommendations, by: { $0.supplierName })
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            if aiVM.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(Color.dashCrimson)
                    Text("AI is drafting orders…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                    .tint(Color.dashCrimson)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if aiVM.hasLoaded && aiVM.recommendations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    Text("All stocked up!")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("No orders needed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Review Auto-Drafted Orders")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.top)

                            ForEach(groupedAdvice, id: \.0) { supplierName, adviceList in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "box.truck.fill")
                                        Text(supplierName)
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.bottom, 4)

                                    ForEach(adviceList) { advice in
                                        DraftOrderRow(advice: advice)
                                    }
                                }
                                .padding()
                                .background(Color.dashCard)
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 100) // Space for floating button
                    }

                    // Floating action bar
                    VStack {
                        let totalCost = aiVM.recommendations.reduce(0) { $0 + ($1.recommendedQty * $1.costPerUnit) }
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(aiVM.recommendations.count) Orders")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Total: ₹\(Int(totalCost))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Button {
                                submitAllOrders()
                            } label: {
                                HStack {
                                    if isSubmitting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                        Text("Create Orders")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.dashCrimson)
                                .cornerRadius(12)
                            }
                            .disabled(isSubmitting)
                        }
                        .padding(16)
                        .background(Color.dashBackground)
                        .overlay(
                            Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.1)),
                            alignment: .top
                        )
                    }
                }
            }
        }
        .navigationTitle("Auto-Draft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            guard !aiVM.hasLoaded && !inventoryVM.lowStockItems.isEmpty else { return }
            await aiVM.fetchRecommendations(
                items: inventoryVM.items,
                suppliers: supplierVM.suppliers
            )
        }
    }

    private func submitAllOrders() {
        isSubmitting = true
        Task {
            for advice in aiVM.recommendations {
                let order = Order(
                    itemID: advice.itemID,
                    itemName: advice.itemName,
                    supplierID: advice.supplierID,
                    supplierName: advice.supplierName,
                    quantity: advice.recommendedQty,
                    unit: advice.unit,
                    totalCost: advice.recommendedQty * advice.costPerUnit,
                    status: .pending,
                    orderDate: Date(),
                    notes: "Auto-drafted by AI"
                )
                await orderVM.addOrder(order, supplierID: advice.supplierID, itemID: advice.itemID)
            }
            aiVM.clear() // Clear the drafts
            isSubmitting = false
            dismiss()
        }
    }
}

// MARK: — Draft Order Row

private struct DraftOrderRow: View {
    let advice: ReorderAdvice

    var urgencyColor: Color {
        switch advice.urgency {
        case "critical": return Color.dashCrimson
        case "high":     return .orange
        default:         return .yellow
        }
    }

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(urgencyColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(advice.itemName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(advice.reason)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(String(format: "%.0f", advice.recommendedQty)) \(advice.unit)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("₹\(Int(advice.recommendedQty * advice.costPerUnit))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
