import SwiftUI

// MARK: — Dashboard

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @EnvironmentObject var supplierVM: SupplierViewModel
    @EnvironmentObject var orderVM: OrderViewModel
    @EnvironmentObject var aiVM: AIViewModel

    @State private var notificationScheduled: Bool = false

    // MARK: Derived values
    private var greetingLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "GOOD MORNING" }
        else if hour < 17 { return "GOOD AFTERNOON" }
        else { return "GOOD EVENING" }
    }

    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 17 ? "cup.and.saucer.fill" : "moon.stars.fill"
    }

    private var displayName: String {
        (appState.currentUserEmail?
            .components(separatedBy: "@").first?
            .capitalized) ?? "Manager"
    }

    private var userInitials: String {
        let email = appState.currentUserEmail ?? "U"
        let name = email.components(separatedBy: "@").first ?? "U"
        return String(name.prefix(2)).uppercased()
    }

    private var totalItems: Int        { inventoryVM.items.count }
    private var lowStockCount: Int     { inventoryVM.lowStockItems.count }
    private var outOfStockCount: Int   { inventoryVM.items.filter { $0.quantity == 0 }.count }
    private var pendingOrderCount: Int { orderVM.pendingOrders.count }
    private var totalOwed: Double      { supplierVM.suppliers.reduce(0) { $0 + $1.amountOwed } }

    private var inStockFraction: Double {
        guard totalItems > 0 else { return 0 }
        let healthy = inventoryVM.items.filter { !$0.isLowStock }.count
        return Double(healthy) / Double(totalItems)
    }
    private var lowFraction: Double {
        guard totalItems > 0 else { return 0 }
        let low = inventoryVM.items.filter { $0.isLowStock && $0.quantity > 0 }.count
        return Double(low) / Double(totalItems)
    }
    private var outFraction: Double {
        guard totalItems > 0 else { return 0 }
        return Double(outOfStockCount) / Double(totalItems)
    }

    // MARK: Body
    var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Greeting Card ──────────────────────────
                    greetingCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // ── Inventory Health ───────────────────────
                    sectionHeader("chart.bar.fill", "INVENTORY HEALTH")
                        .padding(.top, 24)

                    inventoryHealthRow
                        .padding(.horizontal, 16)

                    stockDistributionCard
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    // ── Today's Activity ───────────────────────
                    sectionHeader("calendar", "TODAY'S ACTIVITY")
                        .padding(.top, 24)

                    activityRow
                        .padding(.horizontal, 16)

                    // ── AI Insights inline card (no external header) ──
                    aiInsightsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    // ── Spending Insights inline card ──
                    spendingInsightsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // ── Needs Attention ────────────────────────
                    if !inventoryVM.lowStockItems.isEmpty {
                        sectionHeader("exclamationmark.triangle.fill", "NEEDS ATTENTION", color: .red)
                            .padding(.top, 24)

                        needsAttentionList
                            .padding(.horizontal, 16)
                    }

                    // ── Notification status ────────────────────
                    if notificationScheduled {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.dashCrimson)
                                .font(.caption2)
                            Text("Daily 8 AM low-stock alert active")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ProfileView()) {
                    ZStack {
                        Circle()
                            .fill(Color.dashMaroon.opacity(0.3))
                            .frame(width: 32, height: 32)
                        Text(userInitials)
                            .font(.caption.bold())
                            .foregroundColor(Color.dashCrimson)
                    }
                }
            }
        }
        .task {
            inventoryVM.startListening()
            await supplierVM.fetchSuppliers()
            await orderVM.fetchOrders()
            NotificationService.shared.hasPendingLowStockAlert { scheduled in
                notificationScheduled = scheduled
            }
        }
    }

    // MARK: — Section Header

    private func sectionHeader(_ icon: String, _ title: String,
                                color: Color = .dashCrimson) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption.bold())
                .foregroundColor(color)
                .kerning(2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: — Greeting Card

    private var greetingCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.dashCrimson)
                    .kerning(2)
                Text(displayName)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Café Manager")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.dashMaroon.opacity(0.3))
                    .frame(width: 52, height: 52)
                Image(systemName: greetingEmoji)
                    .font(.title3)
                    .foregroundColor(Color.dashCrimson)
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .cornerRadius(16)
    }

    // MARK: — Inventory Health Row (3 equal stat cards)

    private var inventoryHealthRow: some View {
        HStack(spacing: 10) {
            StatCard(icon: "square.stack.3d.up.fill", value: "\(totalItems)",
                     label: "Total Items", iconColor: .blue)
            StatCard(icon: "exclamationmark.triangle.fill", value: "\(lowStockCount)",
                     label: "Low Stock", iconColor: .orange)
            StatCard(icon: "xmark.circle.fill", value: "\(outOfStockCount)",
                     label: "Out of Stock", iconColor: .red)
        }
    }

    // MARK: — Stock Distribution Card

    private var stockDistributionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Stock Distribution")
                .font(.subheadline)
                .foregroundColor(.secondary)

            GeometryReader { geo in
                Group {
                    if totalItems == 0 {
                        // Empty state — full-width gray bar
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: geo.size.width, height: 10)
                    } else {
                        HStack(spacing: 3) {
                            if inStockFraction > 0 {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.green)
                                    .frame(width: max(geo.size.width * CGFloat(inStockFraction), 0))
                            }
                            if lowFraction > 0 {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.orange)
                                    .frame(width: max(geo.size.width * CGFloat(lowFraction), 0))
                            }
                            if outFraction > 0 || outOfStockCount > 0 {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.red)
                                    .frame(width: max(geo.size.width * CGFloat(outFraction),
                                                      outOfStockCount > 0 ? 10 : 0))
                            }
                        }
                        .frame(height: 10)
                    }
                }
            }
            .frame(height: 10)
            .padding(.vertical, 12)

            HStack {
                Label("In Stock", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                Spacer()
                Label("Low", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Spacer()
                Label("Out", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .cornerRadius(16)
    }

    // MARK: — Activity Row (2 fixed-height cards)

    private var activityRow: some View {
        HStack(spacing: 10) {
            ActivityCard(
                icon: "cart.fill",
                iconBg: Color.dashMaroon.opacity(0.25),
                iconColor: Color.dashCrimson,
                value: "\(pendingOrderCount)",
                label: "Pending Orders"
            )
            ActivityCard(
                icon: "indianrupeesign.circle.fill",
                iconBg: Color.blue.opacity(0.15),
                iconColor: .blue,
                value: "₹\(Int(totalOwed).formattedWithCommas)",
                label: "Amount Owed"
            )
        }
    }

    // MARK: — AI Insights Inline Card

    @ViewBuilder
    private var aiInsightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row: internal "INSIGHTS" label + Refresh button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.bold())
                        .foregroundColor(.dashCrimson)
                    Text("INSIGHTS")
                        .font(.caption.bold())
                        .foregroundColor(.dashCrimson)
                        .kerning(2)
                }
                Spacer()
                Button {
                    Task {
                        await aiVM.fetchRecommendations(
                            items: inventoryVM.items,
                            suppliers: supplierVM.suppliers
                        )
                    }
                } label: {
                    Text("Refresh")
                        .font(.caption.bold())
                        .foregroundColor(.dashCrimson)
                }
                .disabled(aiVM.isLoading)
            }

            // Content states
            if aiVM.isLoading {
                VStack(spacing: 8) {
                    ProgressView().tint(.dashCrimson)
                    Text("Analysing inventory…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)

            } else if aiVM.hasLoaded && !aiVM.sortedRecommendations.isEmpty {
                // Top 2 recommendations inline
                VStack(spacing: 8) {
                    ForEach(aiVM.sortedRecommendations.prefix(2)) { advice in
                        InlineAdviceRow(advice: advice)
                    }
                }

                // View all link
                NavigationLink(destination: ReorderAdvisorView()) {
                    HStack(spacing: 4) {
                        Text("View all \(aiVM.recommendations.count) recommendations")
                            .font(.caption)
                            .foregroundColor(.dashCrimson)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.dashCrimson)
                    }
                }
                .padding(.top, 4)

            } else if aiVM.hasLoaded && aiVM.recommendations.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All items well stocked")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            } else if lowStockCount == 0 {
                // No low-stock items, not yet run
                Text("No low-stock items to analyse")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 60)

            } else {
                // Low stock exists but AI not yet run
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(lowStockCount) items need attention — tap Refresh")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 60)
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .cornerRadius(16)
    }

    // MARK: — Spending Insights Inline Card

    @ViewBuilder
    private var spendingInsightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row: internal "SPEND ANALYSIS" label + Refresh button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    Text("SPEND ANALYSIS")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .kerning(2)
                }
                Spacer()
                Button {
                    Task {
                        await aiVM.fetchSpendingInsights(
                            orders: orderVM.orders,
                            suppliers: supplierVM.suppliers
                        )
                    }
                } label: {
                    Text("Refresh")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
                .disabled(aiVM.isLoadingInsights)
            }

            // Content states
            if aiVM.isLoadingInsights {
                VStack(spacing: 8) {
                    ProgressView().tint(.green)
                    Text("Analyzing purchase history…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)

            } else if aiVM.hasLoadedInsights, let insight = aiVM.spendingInsight {
                // Top Insight Line
                Text(insight.summary)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                // View all link
                NavigationLink(destination: SpendingInsightsView()) {
                    HStack(spacing: 4) {
                        Text("View full analysis")
                            .font(.caption)
                            .foregroundColor(.green)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 4)

            } else {
                let deliveredCount = orderVM.orders.filter { $0.status == .received }.count
                if deliveredCount > 0 {
                    // Orders exist but AI not yet run
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("\(deliveredCount) delivered orders ready for analysis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 60)
                } else {
                    Text("No purchase history to analyze")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 60)
                }
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .cornerRadius(16)
    }

    // MARK: — Needs Attention List

    private var needsAttentionList: some View {
        VStack(spacing: 8) {
            ForEach(inventoryVM.lowStockItems.prefix(5)) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("\(String(format: "%.1f", item.quantity)) / \(String(format: "%.1f", item.minimumThreshold)) \(item.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(item.quantity == 0 ? "OUT" : "LOW")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.quantity == 0 ? Color.red : Color.orange)
                        .cornerRadius(6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dashCard)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: — Sub-components

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
            }
            Text(value)
                .font(.title.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dashCard)
        .cornerRadius(16)
    }
}

private struct ActivityCard: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Color.dashCard)
        .cornerRadius(16)
    }
}

private struct InlineAdviceRow: View {
    let advice: ReorderAdvice

    private var urgencyColor: Color {
        switch advice.urgency {
        case "critical": return Color.dashCrimson
        case "high":     return .orange
        default:         return .yellow
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Left urgency bar
            RoundedRectangle(cornerRadius: 2)
                .fill(urgencyColor)
                .frame(width: 3)
                .frame(minHeight: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(advice.itemName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(advice.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(advice.urgency.capitalized)
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(urgencyColor)
                .cornerRadius(6)
        }
    }
}

// Keep MetricCard for backward compat
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(color)
                }
                Spacer()
            }
            Text(value).font(.title.bold()).foregroundColor(.white)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.dashCard)
        .cornerRadius(16)
    }
}
