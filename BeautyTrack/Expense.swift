import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class Expense {
    var id: UUID
    var date: Date
    var amount: Double
    var category: String
    var productName: String?
    var quantity: Int
    var location: String
    var notes: String?

    init(id: UUID = UUID(), date: Date = Date(), amount: Double = 0, category: String = "Supplies", productName: String? = nil, quantity: Int = 0, location: String = "", notes: String? = nil) {
        self.id = id
        self.date = date
        self.amount = amount
        self.category = category
        self.productName = productName
        self.quantity = quantity
        self.location = location
        self.notes = notes
    }
}

extension Expense {
    /// Normalizes legacy category names so UI can render consistent labels.
    static func normalizedCategoryName(from rawValue: String) -> String {
        if rawValue.caseInsensitiveCompare("Stock Adjustment") == .orderedSame {
            return "Stock Spent"
        }
        if rawValue.caseInsensitiveCompare("Stock Spent") == .orderedSame {
            return "Stock Spent"
        }
        if rawValue.caseInsensitiveCompare("Stock Purchase") == .orderedSame {
            return "Stock Purchase"
        }
        return rawValue
    }

    var normalizedCategory: String {
        Expense.normalizedCategoryName(from: category)
    }
}