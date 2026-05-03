import SwiftUI

struct InventoryDetailView: View {
    let item: InventoryItem
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditForm = false
    @State private var showDeleteAlert = false

    private var statusColor: Color {
        if item.quantity == 0 { return Color.dashCrimson }
        if item.isLowStock { return .orange }
        return .green
    }

    private var statusLabel: String {
        if item.quantity == 0 { return "Out of Stock" }
        if item.isLowStock { return "Low Stock" }
        return "In Stock"
    }

    var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // ── Low-stock banner ───────────────────────────
                    if item.isLowStock {
                        HStack(spacing: 10) {
                            Image(systemName: item.quantity == 0
                                  ? "xmark.circle.fill"
                                  : "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                            Text(item.quantity == 0
                                 ? "Out of stock — reorder immediately"
                                 : "Stock is running low. Consider reordering.")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(statusColor)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }

                    // ── Stock Info ─────────────────────────────────
                    detailSection("STOCK INFO") {
                        detailRow("Name", value: item.name)
                        Divider().background(Color.white.opacity(0.07))
                        detailRow("Category", value: item.category)
                        Divider().background(Color.white.opacity(0.07))
                        detailRow("Quantity", value: "\(String(format: "%.2f", item.quantity)) \(item.unit)")
                        Divider().background(Color.white.opacity(0.07))
                        detailRow("Min Threshold", value: "\(String(format: "%.2f", item.minimumThreshold)) \(item.unit)")
                        Divider().background(Color.white.opacity(0.07))
                        HStack {
                            Text("Status")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(statusLabel)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(statusColor)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // ── Pricing & Supplier ─────────────────────────
                    detailSection("PRICING & SUPPLIER") {
                        detailRow("Cost per Unit", value: String(format: "₹%.2f", item.costPerUnit))
                        Divider().background(Color.white.opacity(0.07))
                        detailRow("Supplier", value: item.supplierName ?? "No supplier linked")
                    }

                    // ── Metadata ───────────────────────────────────
                    detailSection("METADATA") {
                        detailRow("Last Updated",
                                  value: item.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                    }

                    // ── Actions ────────────────────────────────────
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Delete Item")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer(minLength: 32)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditForm = true }
                    .foregroundColor(Color.dashCrimson)
            }
        }
        .sheet(isPresented: $showEditForm) {
            InventoryFormView(mode: .edit(item))
        }
        .alert("Delete Item", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await inventoryVM.deleteItem(item); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(item.name)\"? This cannot be undone.")
        }
    }

    @ViewBuilder
    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .kerning(1.5)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.dashCard)
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
