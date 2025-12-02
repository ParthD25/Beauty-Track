import Foundation
import Combine
import SwiftData
import OSLog
import UserNotifications

@available(iOS 17.0, *)
class InventoryManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var receipts: [Receipt] = []
    @Published var expenses: [Expense] = []
    @Published var lastCreatedExpense: Expense? = nil
    @Published var currentLocation: String = "downtown"
    @Published var searchResults: [Product] = []
    @Published var isLoading = false
    @Published var locations: [String] = ["downtown", "midtown", "westside"]
    
    private static let didPurgeSeedDataKey = "inventory.didPurgeSeedData"
    private var modelContext: ModelContext
    private let logger = Logger(subsystem: "com.beautytrack.app", category: "InventoryManager")
    // During startup/sample data load we don't want to show transient toasts
    private var suppressExpenseToasts: Bool = true
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        requestNotificationAuthorization()
        loadSampleData()
        // allow toasts after initial data load
        DispatchQueue.main.async {
            self.suppressExpenseToasts = false
        }
    }

    func addLocation(_ location: String) {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty, !locations.contains(loc) else { return }
        locations.append(loc)
    }

    func removeLocation(at offsets: IndexSet) {
        locations.remove(atOffsets: offsets)
        if !locations.contains(currentLocation) {
            currentLocation = locations.first ?? ""
        }
    }
    
    func loadSampleData() {
        do {
            let productDescriptor = FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\Product.name)]
            )
            var existingProducts = try modelContext.fetch(productDescriptor)

            let receiptDescriptor = FetchDescriptor<Receipt>(
                sortBy: [SortDescriptor(\Receipt.date)]
            )
            var existingReceipts = try modelContext.fetch(receiptDescriptor)

            let expenseDescriptor = FetchDescriptor<Expense>(
                sortBy: [SortDescriptor(\Expense.date, order: .reverse)]
            )
            var existingExpenses = try modelContext.fetch(expenseDescriptor)

            let defaults = UserDefaults.standard
            if !defaults.bool(forKey: Self.didPurgeSeedDataKey) {
                existingProducts.forEach { modelContext.delete($0) }
                existingReceipts.forEach { modelContext.delete($0) }
                existingExpenses.forEach { modelContext.delete($0) }
                try modelContext.save()

                existingProducts.removeAll()
                existingReceipts.removeAll()
                existingExpenses.removeAll()

                defaults.set(true, forKey: Self.didPurgeSeedDataKey)
            }

            products = existingProducts
            receipts = existingReceipts
            expenses = existingExpenses
            searchResults = existingProducts
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    func addProduct(_ product: Product) {
        // Check if product already exists by name
        if let existingProduct = products.first(where: { $0.name.lowercased() == product.name.lowercased() }) {
            // Product exists, update stock instead of creating new expense
            let oldStock = existingProduct.currentStock
            existingProduct.currentStock = product.currentStock
            existingProduct.lastUpdated = Date()
            existingProduct.updateUsageRate()
            notifyIfLowStock(existingProduct)
            
            // Only create expense if stock actually increased
            if product.currentStock > oldStock {
                let delta = product.currentStock - oldStock
                let amt = Double(delta) * product.costPerUnit
                let expense = Expense(date: Date(), amount: amt, category: "Stock Purchase", productName: product.name, quantity: delta, location: currentLocation, notes: "Additional stock for existing product")
                modelContext.insert(expense)
                expenses.append(expense)
                logger.info("Additional stock for existing product '\(product.name, privacy: .public)' amount=\(expense.amount, privacy: .public) qty=\(expense.quantity, privacy: .public)")
                if !suppressExpenseToasts {
                    DispatchQueue.main.async {
                        self.lastCreatedExpense = expense
                    }
                }
            }
        } else {
            // New product
            modelContext.insert(product)
            products.append(product)
            notifyIfLowStock(product)

            // If the product has an initial stock > 0, record an initial Stock Purchase expense
            if product.currentStock > 0 {
                let amt = Double(product.currentStock) * product.costPerUnit
                let expense = Expense(date: Date(), amount: amt, category: "Stock Purchase", productName: product.name, quantity: product.currentStock, location: currentLocation, notes: "Initial stock for new product")
                modelContext.insert(expense)
                expenses.append(expense)
                logger.info("Initial Stock Purchase for new product '\(product.name, privacy: .public)' amount=\(expense.amount, privacy: .public) qty=\(expense.quantity, privacy: .public)")
                if !suppressExpenseToasts {
                    DispatchQueue.main.async {
                        self.lastCreatedExpense = expense
                    }
                }
            }
        }
        
        saveContext()
    }
    
    func addReceipt(_ receipt: Receipt) {
        modelContext.insert(receipt)
        receipts.append(receipt)
        saveContext()
    }
    
    func searchProducts(query: String) {
        if query.isEmpty {
            searchResults = products
            return
        }
        
        searchResults = products.filter { product in
            product.name.lowercased().contains(query.lowercased()) ||
            product.sku?.lowercased().contains(query.lowercased()) ?? false ||
            product.category.lowercased().contains(query.lowercased()) ||
            product.supplier.lowercased().contains(query.lowercased())
        }
    }
    
    func updateProduct(_ product: Product) {
        saveContext()
    }
    
    func deleteProduct(_ product: Product) {
        modelContext.delete(product)
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products.remove(at: index)
        }
        saveContext()
    }
    
    func addReceipt(_ receipt: Receipt, items: [ReceiptItem]) {
        for item in items {
            modelContext.insert(item)
        }
        
        modelContext.insert(receipt)
        receipts.append(receipt)
        
        // Also record an expense for this receipt to track spending
        let expense = Expense(date: Date(), amount: receipt.total, category: "Supplies", productName: nil, quantity: items.count, location: receipt.location, notes: "Receipt from \(receipt.supplier)")
        modelContext.insert(expense)
        expenses.append(expense)
        
        saveContext()
    }
    
    /// Adjust the product stock to a new value. Creates an Expense record reflecting the change (positive = purchase, negative = usage).
    func adjustStock(product: Product, newStock: Int) {
        let old = product.currentStock
        let delta = newStock - old

        // Update product stock
        product.currentStock = newStock
        product.lastUpdated = Date()
        product.updateUsageRate()
        notifyIfLowStock(product)

        // Create an expense reflecting the change in stock
        if delta != 0 {
            let amt = Double(abs(delta)) * product.costPerUnit
            let category = delta > 0 ? "Stock Purchase" : "Stock Spent"
            let notes = delta > 0 ? "Manual stock increase" : "Manual stock decrease"
            let expense = Expense(date: Date(), amount: amt, category: category, productName: product.name, quantity: abs(delta), location: currentLocation, notes: notes)
            modelContext.insert(expense)
            expenses.append(expense)
            logger.info("Created Expense: \(expense.category, privacy: .public) \(expense.amount, privacy: .public) for product=\(expense.productName ?? "—", privacy: .public) qty=\(expense.quantity, privacy: .public)")
            if !suppressExpenseToasts {
                DispatchQueue.main.async {
                    self.lastCreatedExpense = expense
                }
            }
        }

        saveContext()
    }
    
    /// Add a receipt along with its parsed items. Inserts receipt and items into the model context and updates local arrays.
    func addParsedReceipt(supplier: String, total: Double, location: String, parsedItems: [ReceiptItem]) {
        for item in parsedItems {
            modelContext.insert(item)
        }

        let receipt = Receipt(supplier: supplier, date: Date(), total: total, items: parsedItems.count, location: location)
        modelContext.insert(receipt)

        receipts.append(receipt)
        // Also record an expense for this receipt to track spending
        let expense = Expense(date: Date(), amount: total, category: "Supplies", productName: nil, quantity: parsedItems.count, location: location, notes: "Receipt from \(supplier)")
        modelContext.insert(expense)
        expenses.append(expense)

        saveContext()
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                self.logger.error("Notification authorization failed: \(error.localizedDescription)")
            } else {
                self.logger.info("Notification authorization granted: \(granted, privacy: .public)")
            }
        }
    }

    private func notifyIfLowStock(_ product: Product) {
        guard product.stockStatus == .low else { return }

        let content = UNMutableNotificationContent()
        content.title = "Low Stock Alert"
        content.body = "\(product.name) is down to \(product.currentStock) units."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "low-stock-\(product.id.uuidString)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule low stock alert: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Data Export / Import

    func createBackupFile() throws -> URL {
        let bundle = try makeBackupBundle()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "BeautyTrack-Backup-\(timestamp).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func restoreBackup(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(BackupBundle.self, from: data)

        suppressExpenseToasts = true
        lastCreatedExpense = nil

        // Delete existing records
        for product in products { modelContext.delete(product) }
        for receipt in receipts { modelContext.delete(receipt) }
        for expense in expenses { modelContext.delete(expense) }

        products.removeAll()
        receipts.removeAll()
        expenses.removeAll()

        // Restore products
        for item in bundle.products {
            let product = Product(
                id: item.id,
                name: item.name,
                sku: item.sku,
                category: item.category,
                supplier: item.supplier,
                currentStock: item.currentStock,
                minStock: item.minStock,
                maxStock: item.maxStock,
                costPerUnit: item.costPerUnit,
                location: item.location
            )
            product.usageRate = item.usageRate
            product.lastUpdated = item.lastUpdated
            product.reorderDays = item.reorderDays
            modelContext.insert(product)
            products.append(product)
        }

        // Restore receipts
        for item in bundle.receipts {
            let receipt = Receipt(
                id: item.id,
                supplier: item.supplier,
                date: item.date,
                total: item.total,
                items: item.items,
                location: item.location,
                imageData: item.imageData,
                ocrText: item.ocrText
            )
            modelContext.insert(receipt)
            receipts.append(receipt)
        }

        // Restore expenses
        for item in bundle.expenses {
            let expense = Expense(
                id: item.id,
                date: item.date,
                amount: item.amount,
                category: item.category,
                productName: item.productName,
                quantity: item.quantity,
                location: item.location,
                notes: item.notes
            )
            modelContext.insert(expense)
            expenses.append(expense)
        }

        locations = bundle.locations
        currentLocation = bundle.currentLocation

        searchResults = products

        saveContext()

        DispatchQueue.main.async {
            self.suppressExpenseToasts = false
        }
    }

    private func makeBackupBundle() throws -> BackupBundle {
        let productPayload = products.map { product in
            BackupProduct(
                id: product.id,
                name: product.name,
                sku: product.sku,
                category: product.category,
                supplier: product.supplier,
                currentStock: product.currentStock,
                minStock: product.minStock,
                maxStock: product.maxStock,
                usageRate: product.usageRate,
                lastUpdated: product.lastUpdated,
                costPerUnit: product.costPerUnit,
                reorderDays: product.reorderDays,
                location: product.location
            )
        }

        let receiptPayload = receipts.map { receipt in
            BackupReceipt(
                id: receipt.id,
                supplier: receipt.supplier,
                date: receipt.date,
                total: receipt.total,
                items: receipt.items,
                imageData: receipt.imageData,
                location: receipt.location,
                ocrText: receipt.ocrText
            )
        }

        let expensePayload = expenses.map { expense in
            BackupExpense(
                id: expense.id,
                date: expense.date,
                amount: expense.amount,
                category: expense.category,
                productName: expense.productName,
                quantity: expense.quantity,
                location: expense.location,
                notes: expense.notes
            )
        }

        return BackupBundle(
            metadata: BackupMetadata(exportedAt: Date()),
            locations: locations,
            currentLocation: currentLocation,
            products: productPayload,
            receipts: receiptPayload,
            expenses: expensePayload
        )
    }
}

// MARK: - Backup DTOs

@available(iOS 17.0, *)
extension InventoryManager {
    struct BackupBundle: Codable {
        let metadata: BackupMetadata
        let locations: [String]
        let currentLocation: String
        let products: [BackupProduct]
        let receipts: [BackupReceipt]
        let expenses: [BackupExpense]
    }

    struct BackupMetadata: Codable {
        let exportedAt: Date
    }

    struct BackupProduct: Codable {
        let id: UUID
        let name: String
        let sku: String?
        let category: String
        let supplier: String
        let currentStock: Int
        let minStock: Int
        let maxStock: Int
        let usageRate: Double
        let lastUpdated: Date
        let costPerUnit: Double
        let reorderDays: Int
        let location: String
    }

    struct BackupReceipt: Codable {
        let id: UUID
        let supplier: String
        let date: Date
        let total: Double
        let items: Int
        let imageData: Data?
        let location: String
        let ocrText: String?
    }

    struct BackupExpense: Codable {
        let id: UUID
        let date: Date
        let amount: Double
        let category: String
        let productName: String?
        let quantity: Int
        let location: String
        let notes: String?
    }
}