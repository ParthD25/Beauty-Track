import SwiftUI

@available(iOS 17.0, *)
struct StockUpdateView: View {
    let product: Product
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) var dismiss
    
    @State private var adjustmentType = "Add"
    @State private var quantity = 0
    @State private var notes = ""
    
    let adjustmentTypes = ["Add", "Remove", "Set To"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Product") {
                    Text(product.name)
                        .font(.headline)
                    Text("Current Stock: \(product.currentStock)")
                        .foregroundColor(.secondary)
                }
                
                Section("Adjustment") {
                    Picker("Action", selection: $adjustmentType) {
                        ForEach(adjustmentTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...100)
                    
                    TextField("Notes (optional)", text: $notes)
                }
                
                Section("Preview") {
                    HStack {
                        Text("New Stock Level")
                        Spacer()
                        Text("\(newStockLevel)")
                            .font(.headline)
                            .foregroundColor(stockColor)
                    }
                }
                
                Section {
                    Button(action: updateStock) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Update Stock")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Update Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var newStockLevel: Int {
        switch adjustmentType {
        case "Add":
            return product.currentStock + quantity
        case "Remove":
            return max(0, product.currentStock - quantity)
        case "Set To":
            return quantity
        default:
            return product.currentStock
        }
    }
    
    private var stockColor: Color {
        if newStockLevel <= product.minStock {
            return .red
        } else if newStockLevel <= product.minStock * 2 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func updateStock() {
        switch adjustmentType {
        case "Add":
            product.addStock(quantity)
        case "Remove":
            product.removeStock(quantity)
        case "Set To":
            product.currentStock = quantity
            product.lastUpdated = Date()
        default:
            break
        }
        
        inventoryManager.updateProduct(product)
        dismiss()
    }
}