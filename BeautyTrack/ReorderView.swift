import SwiftUI

@available(iOS 17.0, *)
struct ReorderView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    
    // Filter by current location and sort ascending so low-stock items (small qty) appear first and high qty last.
    private var lowStockProducts: [Product] {
        inventoryManager.products.filter { $0.stockStatus == .low && $0.location == inventoryManager.currentLocation }
            .sorted { $0.currentStock < $1.currentStock }
    }
    
    private var criticalProducts: [Product] {
        inventoryManager.products.filter { $0.urgencyLevel == .critical && $0.location == inventoryManager.currentLocation }
            .sorted { $0.currentStock < $1.currentStock }
    }
    
    var body: some View {
        NavigationView {
            List {
                if !criticalProducts.isEmpty {
                    Section("Critical - Order Immediately") {
                        ForEach(criticalProducts, id: \.id) { product in
                            ReorderRow(product: product, urgency: .critical)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                let p = criticalProducts[index]
                                inventoryManager.deleteProduct(p)
                            }
                        }
                    }
                }
                
                if !lowStockProducts.isEmpty {
                    Section("Low Stock - Order Soon") {
                        ForEach(lowStockProducts, id: \.id) { product in
                            ReorderRow(product: product, urgency: .low)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                let p = lowStockProducts[index]
                                inventoryManager.deleteProduct(p)
                            }
                        }
                    }
                }
                
                if criticalProducts.isEmpty && lowStockProducts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("All Stock Levels Good")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("No products need reordering at this time")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .navigationTitle("Reorder List")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

@available(iOS 17.0, *)
struct ReorderRow: View {
    let product: Product
    let urgency: UrgencyLevel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(product.name)
                    .font(.headline)
                Spacer()
                Text("$")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Stock: \(product.currentStock)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Min: \(product.minStock)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(product.reorderDays) days remaining")
                    .font(.caption)
                    .foregroundColor(urgencyColor)
                Spacer()
                Button(action: {
                    // Add to reorder list
                }) {
                    Text("Reorder")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var urgencyColor: Color {
        switch urgency {
        case .critical:
            return .red
        case .high:
            return .orange
        case .medium:
            return .yellow
        case .low:
            return .green
        }
    }
}