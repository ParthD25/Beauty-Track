import SwiftUI

@available(iOS 17.0, *)
struct DashboardView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @AppStorage(UserPreferences.salonNameKey) private var salonName: String = ""
    @AppStorage(UserPreferences.ownerNameKey) private var ownerName: String = ""
    @State private var showingAddProduct = false
    @State private var showingScanner = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                header
                reorderSection
                VStack(alignment: .leading) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        QuickActionButton(title: "Add Product", icon: "plus.square.fill", action: {
                            showingAddProduct = true
                        })
                        QuickActionButton(title: "Scan Receipt", icon: "camera.fill", action: {
                            showingScanner = true
                        })
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingAddProduct) {
            AddProductView()
                .environmentObject(inventoryManager)
        }
        .sheet(isPresented: $showingScanner) {
            ReceiptScannerView()
                .environmentObject(inventoryManager)
        }
    }
}

@available(iOS 17.0, *)
private extension DashboardView {
    @ViewBuilder
    var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(displaySalonName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(overviewLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProfileBadge(ownerName: ownerName)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    var reorderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Needs Attention")
                    .font(.headline)
                if !reorderCandidates.isEmpty {
                    Text("\(reorderCandidates.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if reorderCandidates.isEmpty {
                Text("All of your tracked items are above minimums.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 10) {
                    ForEach(reorderCandidates.prefix(3), id: \.id) { product in
                        reorderRow(for: product)
                    }
                    if reorderCandidates.count > 3 {
                        Text("Open Inventory to see the rest.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    func reorderRow(for product: Product) -> some View {
        let badge = urgencyBadge(for: product)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                Text(product.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("On hand: \(product.currentStock)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(badge.text)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badge.color.opacity(0.9))
                    .clipShape(Capsule())
                Text("~\(product.reorderDays) day supply")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    var displaySalonName: String {
        salonName.isEmpty ? "BeautyTrack" : salonName
    }

    var greeting: String {
        guard !ownerName.isEmpty else { return "Welcome back" }
        let firstComponent = ownerName.split(separator: " ").first.map(String.init) ?? ownerName
        return "Welcome back, \(firstComponent)"
    }

    var overviewLine: String {
        guard let next = reorderCandidates.first else {
            return "Everything looks stocked for now."
        }
        return "\(next.name) is the next item to prep for reorder."
    }

    var reorderCandidates: [Product] {
        inventoryManager.products
            .filter { product in
                product.stockStatus == .low || product.urgencyLevel == .critical || product.urgencyLevel == .high
            }
            .sorted { lhs, rhs in
                let lhsRank = urgencyRank(for: lhs.urgencyLevel)
                let rhsRank = urgencyRank(for: rhs.urgencyLevel)
                if lhsRank == rhsRank {
                    return lhs.currentStock < rhs.currentStock
                }
                return lhsRank < rhsRank
            }
    }

    func urgencyBadge(for product: Product) -> (text: String, color: Color) {
        switch product.urgencyLevel {
        case .critical:
            return ("Order today", .red)
        case .high:
            return ("Plan this week", .orange)
        case .medium:
            return ("Monitor", .yellow)
        case .low:
            return ("Comfortable", .green)
        }
    }

    func urgencyRank(for level: UrgencyLevel) -> Int {
        switch level {
        case .critical:
            return 0
        case .high:
            return 1
        case .medium:
            return 2
        case .low:
            return 3
        }
    }
}

@available(iOS 17.0, *)
struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

@available(iOS 17.0, *)
struct ProfileBadge: View {
    let ownerName: String

    private var initials: String {
        guard !ownerName.isEmpty else { return "BT" }
        let parts = ownerName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        if letters.isEmpty, let first = ownerName.first {
            return String(first).uppercased()
        }
        return letters.map { String($0).uppercased() }.joined()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(initials)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(width: 48, height: 48)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.accentColor.opacity(0.35), radius: 6, x: 0, y: 4)
    }
}