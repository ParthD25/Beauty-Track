import SwiftUI

@available(iOS 17.0, *)
struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) var dismiss
    @State private var editingStock = 0
    @State private var isDirty = false
    @State private var selectedCategory = ""
    @State private var editingSupplier = ""

    private var categories: [String] {
        SalonCategory.names
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Product Information") {
                    Text(product.name)
                        .font(.headline)
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .onChange(of: selectedCategory, initial: false) { _, _ in
                        updateDirtyFlag()
                    }
                    TextField("Supplier (optional)", text: $editingSupplier)
                        .foregroundColor(.secondary)
                        .onChange(of: editingSupplier, initial: false) { _, _ in
                            updateDirtyFlag()
                        }
                    if let sku = product.sku {
                        Text("SKU: \(sku)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Stock Information") {
                    HStack {
                        Text("Current Stock")
                        Spacer()
                        Stepper(value: $editingStock, in: 0...100000, step: 1) {
                            Text("\(editingStock)")
                                .font(.headline)
                        }
                        .onChange(of: editingStock, initial: false) { _, _ in
                            updateDirtyFlag()
                        }
                    }
                    
                    HStack {
                        Text("Minimum Stock")
                        Spacer()
                        Text("\(product.minStock)")
                    }
                    
                    HStack {
                        Text("Maximum Stock")
                        Spacer()
                        Text("\(product.maxStock)")
                    }
                    
                    HStack {
                        Text("Reorder Days")
                        Spacer()
                        Text("\(product.reorderDays)")
                            .foregroundColor(product.urgencyLevel == .critical ? .red : .primary)
                    }
                }
                
                Section("Pricing") {
                    HStack {
                        Text("Cost per Unit")
                        Spacer()
                        Text("$" + String(format: "%.2f", product.costPerUnit))
                    }
                }
                
                Section("Status") {
                    HStack {
                        Text("Stock Status")
                        Spacer()
                        Text(String(describing: product.stockStatus))
                            .foregroundColor(statusColor)
                    }
                    
                    HStack {
                        Text("Urgency Level")
                        Spacer()
                        Text(String(describing: product.urgencyLevel))
                            .foregroundColor(urgencyColor)
                    }
                }
            }
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isDirty {
                            Button("Apply") {
                                applyChanges()
                            }
                        }

                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                editingStock = product.currentStock
                selectedCategory = categories.contains(product.category) ? product.category : (categories.first ?? product.category)
                editingSupplier = product.supplier
                updateDirtyFlag()
            }
        }
    }
    
    private var statusColor: Color {
        switch product.stockStatus {
        case .low:
            return .orange
        case .medium:
            return .yellow
        case .high:
            return .green
        }
    }
    
    private var urgencyColor: Color {
        switch product.urgencyLevel {
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

private extension ProductDetailView {
    func applyChanges() {
        let categoryChanged = selectedCategory != product.category
        let stockChanged = editingStock != product.currentStock
        let supplierChanged = editingSupplier.trimmingCharacters(in: .whitespaces) != product.supplier.trimmingCharacters(in: .whitespaces)

        if categoryChanged {
            product.category = selectedCategory
        }

        if supplierChanged {
            product.supplier = editingSupplier.trimmingCharacters(in: .whitespaces)
        }

        if stockChanged {
            inventoryManager.adjustStock(product: product, newStock: editingStock)
        } else if categoryChanged || supplierChanged {
            inventoryManager.updateProduct(product)
        }

        if stockChanged {
            editingStock = product.currentStock
        }

        updateDirtyFlag()
    }

    func updateDirtyFlag() {
        isDirty = (editingStock != product.currentStock) ||
                  (selectedCategory.caseInsensitiveCompare(product.category) != .orderedSame) ||
                  (editingSupplier.trimmingCharacters(in: .whitespaces) != product.supplier.trimmingCharacters(in: .whitespaces))
    }
}
