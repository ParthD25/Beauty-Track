import SwiftUI

@available(iOS 17.0, *)
struct ReceiptsView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach(inventoryManager.receipts, id: \.id) { receipt in
                    ReceiptRow(receipt: receipt)
                }
            }
            .navigationTitle("Receipts")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

@available(iOS 17.0, *)
struct ReceiptRow: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(receipt.supplier)
                    .font(.headline)
                Spacer()
                Text("$\(receipt.total, specifier: "%.2f")")
                    .font(.headline)
            }
            
            HStack {
                Text("\(receipt.items) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(receipt.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(receipt.location)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}