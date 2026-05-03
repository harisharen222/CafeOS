import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @EnvironmentObject var orderVM: OrderViewModel
    @EnvironmentObject var supplierVM: SupplierViewModel

    @State private var showSignOutAlert = false

    private var userInitials: String {
        let email = appState.currentUserEmail ?? "U"
        let name = email.components(separatedBy: "@").first ?? "U"
        return String(name.prefix(2)).uppercased()
    }

    private var displayEmail: String {
        appState.currentUserEmail ?? "—"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // ── Profile Card ───────────────────────────────────
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.brown, lineWidth: 2)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 68, height: 68)
                        Text(userInitials)
                            .font(.title2.bold())
                            .foregroundColor(.brown)
                    }
                    VStack(spacing: 4) {
                        Text(displayEmail.components(separatedBy: "@").first?.capitalized ?? "Manager")
                            .font(.headline)
                        Text(displayEmail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("CAFÉ MANAGER")
                            .font(.caption2.bold())
                            .foregroundColor(.brown)
                            .kerning(1.5)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top, 8)

                // ── Stats Summary ──────────────────────────────────
                HStack(spacing: 10) {
                    ProfileStatCard(value: "\(inventoryVM.items.count)", label: "Items")
                    ProfileStatCard(value: "\(supplierVM.suppliers.count)", label: "Suppliers")
                    ProfileStatCard(value: "\(orderVM.orders.count)", label: "Orders")
                }
                .padding(.horizontal)

                // ── App Section ────────────────────────────────────
                profileSection(title: "APP") {
                    ProfileMenuRow(icon: "bell.fill", iconColor: .orange,
                                   title: "Notifications",
                                   subtitle: "Low-stock alert at 8:00 AM")
                    Divider().padding(.leading, 58)
                    ProfileMenuRow(icon: "lock.fill", iconColor: .blue,
                                   title: "Security",
                                   subtitle: "Firebase Auth — email/password")
                    Divider().padding(.leading, 58)
                    ProfileMenuRow(icon: "icloud.fill", iconColor: .teal,
                                   title: "Data Sync",
                                   subtitle: "Firestore — real-time")
                }

                // ── About Section ──────────────────────────────────
                profileSection(title: "ABOUT") {
                    ProfileMenuRow(icon: "cup.and.saucer.fill", iconColor: .brown,
                                   title: "CafeOS",
                                   subtitle: "v1.0 — iOS 16.4+")
                    Divider().padding(.leading, 58)
                    ProfileMenuRow(icon: "sparkles", iconColor: .purple,
                                   title: "AI Powered By",
                                   subtitle: "Google Gemini Flash 2.0")
                    Divider().padding(.leading, 58)
                    ProfileMenuRow(icon: "link", iconColor: .gray,
                                   title: "URL Extractor",
                                   subtitle: "Jina.ai Reader API")
                }

                // ── Sign Out ───────────────────────────────────────
                Button {
                    showSignOutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.brown)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .alert("Sign Out", isPresented: $showSignOutAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Sign Out", role: .destructive) {
                        try? appState.signOut()
                    }
                } message: {
                    Text("Are you sure you want to sign out?")
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func profileSection<Content: View>(title: String,
                                               @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .kerning(1.5)
                .padding(.horizontal)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: — Sub-components

private struct ProfileStatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct ProfileMenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
