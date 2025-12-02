import SwiftUI

@available(iOS 17.0, *)
struct AddProductView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var category = SalonCategory.defaultName
    @State private var supplier = ""
    @State private var initialStock = 0
    @State private var minStock = 2
    @State private var maxStock = 10
    // Unit / pricing
    @State private var costPerUnit = 0.0
    @State private var trackAdvancedFields = false
    @State private var unitType = "Single" // Single or Pack
    @State private var packSize = 1
    @State private var packUnit = "pieces"
    @State private var packUnitCustom = ""
    @State private var addSupplierQuantityToStock = false
    @State private var supplierPackQuantity = 0
    @State private var trackExpiration = false
    @State private var expirationDate = Date()
    @State private var showSuggestions = false
    
    private var categories: [String] {
        SalonCategory.names
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic") {
                    TextField("Item Name", text: $name)
                        .autocorrectionDisabled(true)
                        .onChange(of: name, initial: false) { _, newValue in
                            showSuggestions = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                        }

                    // Suggestions from existing products
                    if showSuggestions {
                        let matches = inventoryManager.products.filter { p in
                            !p.name.isEmpty && p.name.lowercased().contains(name.lowercased())
                        }
                        if !matches.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(matches.prefix(6), id: \.id) { p in
                                    Button {
                                        populateFromProduct(p)
                                        showSuggestions = false
                                    } label: {
                                        HStack {
                                            Text(p.name)
                                                .lineLimit(1)
                                            Spacer()
                                            Text(p.category)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
                            }
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                    }

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }

                    TextField("Supplier (optional)", text: $supplier)
                        .autocorrectionDisabled(true)
                }

                Section("Quantity & Pricing") {
                    Stepper("Quantity: \(initialStock)", value: $initialStock, in: 0...1000)
                    TextField("$0", value: $costPerUnit, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)

                    DisclosureGroup(isExpanded: $trackAdvancedFields) {
                        Picker("Unit", selection: $unitType) {
                            Text("Single").tag("Single")
                            Text("Pack").tag("Pack")
                        }
                        .pickerStyle(.segmented)

                        if unitType == "Pack" {
                            Stepper("Pack Size: \(packSize)", value: $packSize, in: 1...1000)

                            Picker("Pack Unit", selection: $packUnit) {
                                Text("pieces").tag("pieces")
                                Text("ml").tag("ml")
                                Text("oz").tag("oz")
                                Text("size").tag("size")
                                Text("Custom").tag("Custom")
                            }
                            .pickerStyle(.menu)

                            if packUnit == "Custom" {
                                TextField("Custom unit", text: $packUnitCustom)
                                    .autocorrectionDisabled(true)
                            }

                            Toggle("Add supplier pack quantity", isOn: $addSupplierQuantityToStock)

                            if addSupplierQuantityToStock {
                                Stepper("Supplier pack quantity: \(supplierPackQuantity)", value: $supplierPackQuantity, in: 0...100)
                            }
                        }

                        Stepper("Minimum stock: \(minStock)", value: $minStock, in: 0...1000)
                        Stepper("Maximum stock: \(maxStock)", value: $maxStock, in: 1...10000)

                        Toggle("Track expiration date", isOn: $trackExpiration)
                        if trackExpiration {
                            DatePicker("Expiration date", selection: $expirationDate, displayedComponents: .date)
                        }
                    } label: {
                        Text("Advanced options")
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addProduct()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                ensureValidCategory()
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && costPerUnit > 0
    }
    
    private func addProduct() {
        // Check if product already exists
        if let existingProduct = inventoryManager.products.first(where: { $0.name.lowercased() == name.lowercased() }) {
            // Product exists, only update stock if it's actually increasing
            if initialStock > 0 {
                let newStock = existingProduct.currentStock + initialStock
                inventoryManager.adjustStock(product: existingProduct, newStock: newStock)
            }
            dismiss()
            return
        }
        
        var finalStock = initialStock
        if trackAdvancedFields, addSupplierQuantityToStock, supplierPackQuantity > 0 {
            finalStock += supplierPackQuantity * max(1, packSize)
        }

        let product = Product(
            name: name,
            category: category,
            supplier: supplier,
            currentStock: finalStock,
            minStock: trackAdvancedFields ? minStock : max(1, minStock),
            maxStock: trackAdvancedFields ? maxStock : max(minStock * 2, maxStock),
            costPerUnit: costPerUnit,
            location: inventoryManager.currentLocation
        )

        inventoryManager.addProduct(product)
        dismiss()
    }

    private func populateFromProduct(_ p: Product) {
        name = p.name
        category = p.category
        supplier = p.supplier
        initialStock = 0 // Set to 0 for existing products to avoid unwanted stock increase
        minStock = p.minStock
        maxStock = p.maxStock
        costPerUnit = p.costPerUnit
    }

    private func ensureValidCategory() {
        if !categories.contains(category) {
            category = categories.first ?? "Other"
        }
    }
}
