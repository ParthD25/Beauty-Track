import Foundation
import SwiftData

@Model
final class Receipt {
    var id: UUID
    var supplier: String
    var date: Date
    var total: Double
    var items: Int
    var imageData: Data?
    var location: String
    var ocrText: String?
    
    init(
        id: UUID = UUID(),
        supplier: String,
        date: Date,
        total: Double,
        items: Int,
        location: String,
        imageData: Data? = nil,
        ocrText: String? = nil
    ) {
        self.id = id
        self.supplier = supplier
        self.date = date
        self.total = total
        self.items = items
        self.location = location
        self.imageData = imageData
        self.ocrText = ocrText
    }
}