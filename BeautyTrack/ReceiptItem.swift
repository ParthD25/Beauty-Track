import Foundation
import SwiftData

@Model
final class ReceiptItem {
    var id: UUID
    var productName: String
    var quantity: Int
    var unitPrice: Double
    var totalPrice: Double
    var confidence: Double
    var status: String // "matched", "partial", "new"
    
    init(
        id: UUID = UUID(),
        productName: String,
        quantity: Int,
        unitPrice: Double,
        totalPrice: Double,
        confidence: Double,
        status: String = "new"
    ) {
        self.id = id
        self.productName = productName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.confidence = confidence
        self.status = status
    }
}