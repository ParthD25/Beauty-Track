import SwiftUI

@available(iOS 17.0, *)
struct ManualReceiptEntryView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) var dismiss

    @State private var supplier: String = ""
    @State private var total: String = ""
    @State private var location: String = ""
    @State private var items: [ManualItem] = []

    struct ManualItem: Identifiable {
        var id = UUID()
        var name: String = ""
        var quantity: String = "1"
        var price: String = "0.00"
        var category: String = ""
        var column: String = ""
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Receipt")) {
                    TextField("Supplier", text: $supplier)
                    TextField("Total", text: $total)
                        .keyboardType(.decimalPad)
                    TextField("Location", text: $location)
                }

                Section(header: Text("Items")) {
                    ForEach($items) { $item in
                        VStack(alignment: .leading) {
                            TextField("Name", text: $item.name)
                            HStack {
                                TextField("Qty", text: $item.quantity)
                                    .keyboardType(.numberPad)
                                TextField("Price", text: $item.price)
                                    .keyboardType(.decimalPad)
                            }
                            TextField("Category", text: $item.category)
                            TextField("Column", text: $item.column)
                        }
                    }
                    Button("Add Item") {
                        items.append(ManualItem())
                    }
                }
            }
            .navigationTitle("Enter Receipt Manually")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReceipt()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveReceipt() {
        let tot: Double
        if let explicit = Double(total) {
            tot = explicit
        } else {
            tot = items.reduce(0) { acc, it in
                let price = Double(it.price) ?? 0.0
                let qty = Double(it.quantity) ?? 1
                return acc + price * qty
            }
        }
        var parsedItems: [ReceiptItem] = []
        for it in items {
            let qty = Int(it.quantity) ?? 1
            let price = Double(it.price) ?? 0.0
            let totalPrice = Double(qty) * price
            let rItem = ReceiptItem(productName: it.name, quantity: qty, unitPrice: price, totalPrice: totalPrice, confidence: 1.0, status: "new")
            parsedItems.append(rItem)
        }

        inventoryManager.addParsedReceipt(supplier: supplier.isEmpty ? "Manual" : supplier, total: tot, location: location.isEmpty ? inventoryManager.currentLocation : location, parsedItems: parsedItems)
        dismiss()
    }
}
