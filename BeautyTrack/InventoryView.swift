import SwiftUI

@available(iOS 17.0, *)
struct InventoryView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var searchQuery = ""
    @State private var selectedCategory = "All"
    @State private var sortBy = "Name"
    @State private var showAddProduct = false
    @State private var selectedProduct: Product?
    
    private var categories: [String] {
        ["All"] + SalonCategory.names
    }
    let sortOptions = ["Name", "Stock Level", "Category", "Supplier", "Last Updated"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            VStack(spacing: 12) {
                SearchBar(text: $searchQuery, placeholder: "Search products...")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            CategoryFilterButton(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                }

                HStack {
                    Text("Sort by:")
                        .font(.subheadline)
                    Picker("Sort", selection: $sortBy) {
                        ForEach(sortOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
            }
            .padding(.vertical)
            .background(Color(.systemBackground))

            // Products Grid (responsive)
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 20) {
                    ForEach(filteredProducts, id: \.id) { product in
                        ProductCard(product: product) {
                            selectedProduct = product
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddProduct = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddProduct) {
            AddProductView()
                .environmentObject(inventoryManager)
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
                .environmentObject(inventoryManager)
        }
        .onChange(of: searchQuery) {
            inventoryManager.searchProducts(query: searchQuery)
        }
    }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 32 : 16
    }

    private var gridColumns: [GridItem] {
        let minimumWidth: CGFloat = horizontalSizeClass == .regular ? 260 : 180
        let maximumWidth: CGFloat = horizontalSizeClass == .regular ? 420 : 240
        return [GridItem(.adaptive(minimum: minimumWidth, maximum: maximumWidth), spacing: 20)]
    }

    private var filteredProducts: [Product] {
        var filtered = inventoryManager.products
        
        // Apply category filter
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Apply search filter
        if !searchQuery.isEmpty {
            filtered = inventoryManager.searchResults
        }
        
        // Apply sorting
        switch sortBy {
        case "Name":
            filtered.sort { $0.name < $1.name }
        case "Stock Level":
            filtered.sort { $0.currentStock < $1.currentStock }
        case "Category":
            filtered.sort { $0.category < $1.category }
        case "Supplier":
            filtered.sort { $0.supplier < $1.supplier }
        case "Last Updated":
            filtered.sort { $0.lastUpdated > $1.lastUpdated }
        default:
            break
        }
        
        return filtered
    }
}

@available(iOS 17.0, *)
extension ProductCard {
    private func commitStockEdit() {
        guard let newStock = Int(editingStockText.trimmingCharacters(in: .whitespaces)), newStock >= 0 else {
            // invalid input, reset
            editingStockText = String(product.currentStock)
            isEditingStock = false
            return
        }

        if newStock != product.currentStock {
            // ask inventory manager to adjust stock (will create expense)
            inventoryManager.adjustStock(product: product, newStock: newStock)
        }

        // end editing
        isEditingStock = false
    }
}

@available(iOS 17.0, *)
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

@available(iOS 17.0, *)
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
        }
    }
}

@available(iOS 17.0, *)
struct ProductCard: View {
    let product: Product
    let action: () -> Void
    @EnvironmentObject var inventoryManager: InventoryManager
    @State private var editingStockText: String = ""
    @State private var isEditingStock = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(product.name)
                            .font(.headline)
                            .lineLimit(2)
                        Text(product.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    StockStatusIndicator(status: product.stockStatus)
                }
                
                Divider()
                
                HStack(alignment: .center) {
                    VStack(alignment: .leading) {
                        HStack {
                            if isEditingStock {
                                TextField("Stock", text: $editingStockText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .onSubmit {
                                        commitStockEdit()
                                    }
                                    .onAppear {
                                        editingStockText = String(product.currentStock)
                                    }
                            } else {
                                Text("Stock: \(product.currentStock)")
                                    .font(.subheadline)
                                    .onTapGesture {
                                        isEditingStock = true
                                        editingStockText = String(product.currentStock)
                                    }
                            }

                            Text("Min: \(product.minStock)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(product.reorderDays) days")
                            .font(.caption)
                            .foregroundColor(product.urgencyLevel == .critical ? .red : .secondary)
                        Text("$\(product.costPerUnit, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

@available(iOS 17.0, *)
struct StockStatusIndicator: View {
    let status: StockStatus
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
    }
    
    private var statusColor: Color {
        switch status {
        case .low:
            return .orange
        case .medium:
            return .yellow
        case .high:
            return .green
        }
    }
}