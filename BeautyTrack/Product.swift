import Foundation
import SwiftData

@Model
final class Product {
    var id: UUID
    var name: String
    var sku: String?
    var category: String
    var supplier: String
    var currentStock: Int
    var minStock: Int
    var maxStock: Int
    var usageRate: Double
    var lastUpdated: Date
    var costPerUnit: Double
    var reorderDays: Int
    var location: String
    
    init(
        id: UUID = UUID(),
        name: String,
        sku: String? = nil,
        category: String,
        supplier: String,
        currentStock: Int,
        minStock: Int,
        maxStock: Int,
        costPerUnit: Double,
        location: String
    ) {
        self.id = id
        self.name = name
        self.sku = sku
        self.category = category
        self.supplier = supplier
        self.currentStock = currentStock
        self.minStock = minStock
        self.maxStock = maxStock
        self.costPerUnit = costPerUnit
        self.location = location
        self.usageRate = 0.5
        self.lastUpdated = Date()
        self.reorderDays = 6
    }
    
    var stockStatus: StockStatus {
        if currentStock <= minStock {
            return .low
        } else if currentStock <= minStock * 2 {
            return .medium
        } else {
            return .high
        }
    }
    
    var urgencyLevel: UrgencyLevel {
        if reorderDays <= 1 {
            return .critical
        } else if reorderDays <= 4 {
            return .high
        } else if reorderDays <= 7 {
            return .medium
        } else {
            return .low
        }
    }
    
    func updateUsageRate() {
        // Calculate usage rate based on stock changes
        // Simplified calculation for demo purposes
        usageRate = 0.5 // Default rate
        
        // Calculate days until empty
        if usageRate > 0 {
            reorderDays = Int(Double(currentStock) / usageRate * 7.0)
        } else {
            reorderDays = 999 // Never runs out if no usage
        }
    }
    
    func addStock(_ quantity: Int) {
        currentStock += quantity
        lastUpdated = Date()
        updateUsageRate()
    }
    
    func removeStock(_ quantity: Int) {
        currentStock = max(0, currentStock - quantity)
        lastUpdated = Date()
        updateUsageRate()
    }
}

enum StockStatus {
    case low, medium, high
}

enum UrgencyLevel {
    case critical, high, medium, low
}