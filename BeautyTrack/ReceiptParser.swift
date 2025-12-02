import Foundation
import Vision
import UIKit

struct ParsedReceiptItem {
    let name: String
    let quantity: Int
    let unitPrice: Double
    let totalPrice: Double
    let category: String?
}

struct ParsedReceipt {
    let supplier: String?
    let total: Double?
    let items: [ParsedReceiptItem]
}

@available(iOS 17.0, *)
class ReceiptParser {
    /// Perform OCR on the provided image and attempt to heuristically parse lines into items and totals.
    static func parse(image: UIImage, completion: @escaping (ParsedReceipt) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(ParsedReceipt(supplier: nil, total: nil, items: []))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            var lines: [String] = []
            if let results = request.results as? [VNRecognizedTextObservation] {
                for obs in results {
                    if let candidate = obs.topCandidates(1).first {
                        lines.append(candidate.string)
                    }
                }
            }

            // Heuristic parsing
            let parsed = parseLines(lines)
            completion(parsed)
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en_US", "en"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(ParsedReceipt(supplier: nil, total: nil, items: []))
            }
        }
    }

    private static func parseLines(_ lines: [String]) -> ParsedReceipt {
        var supplier: String?
        var total: Double?
        var items: [ParsedReceiptItem] = []

        // Simple heuristics:
        // - The supplier is often in the first 1-2 non-empty lines
        // - Totals are lines containing "total" or a standalone price near the end
        // - Item lines: "Name qty price" or "Name price"

        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !cleaned.isEmpty {
            supplier = cleaned.first
        }

        // attempt find total by searching lines containing 'total' or 'subtotal' or last numeric with currency
        for line in cleaned.reversed() {
            let lower = line.lowercased()
            if lower.contains("total") || lower.contains("subtotal") || lower.contains("amount") {
                if let t = extractFirstPrice(from: line) {
                    total = t
                    break
                }
            }
            if total == nil, let t = extractFirstPrice(from: line) {
                // candidate total if it's at end and looks like a grand total (larger than 0)
                total = t
                break
            }
        }

        // parse item-like lines (skip first couple supplier lines and last few total lines)
        let candidateItemLines = cleaned.dropFirst(1).dropLast(3)
        for raw in candidateItemLines {
            if let item = parseItemLine(raw) {
                items.append(item)
            }
        }

        return ParsedReceipt(supplier: supplier, total: total, items: items)
    }

    private static func extractFirstPrice(from text: String) -> Double? {
        // Find something like 12.34 or $12.34
        let pattern = "\\$?([0-9]+(?:\\.[0-9]{1,2})?)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let ns = text as NSString
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
                let priceStr = ns.substring(with: match.range(at: 1))
                return Double(priceStr)
            }
        }
        return nil
    }

    private static func parseItemLine(_ line: String) -> ParsedReceiptItem? {
        // Heuristic: try to capture a price at the end and optional quantity before it.
        // Examples:
        // "CND Shellac Romantique 2 12.99"
        // "Nitrile Powder-Free Gloves 8.99"

        let tokens = line.split(separator: " ").map { String($0) }
        guard !tokens.isEmpty else { return nil }

        // Try to find a price token (last token that matches price regex)
        var priceIndex: Int? = nil
        for i in stride(from: tokens.count - 1, through: 0, by: -1) {
            if let _ = Double(tokens[i].replacingOccurrences(of: "$", with: "")) {
                priceIndex = i
                break
            }
        }

        guard let pIdx = priceIndex else { return nil }
        let priceStr = tokens[pIdx].replacingOccurrences(of: "$", with: "")
        let price = Double(priceStr) ?? 0.0

        var qty = 1
        var nameTokens = tokens[0..<pIdx]

        if nameTokens.count >= 2 {
            // check if the token just before price is an integer qty
            if let possibleQty = Int(tokens[pIdx - 1]) {
                qty = possibleQty
                nameTokens = tokens[0..<(pIdx - 1)]
            }
        }

        let name = nameTokens.joined(separator: " ")
        let totalPrice = Double(qty) * price

        return ParsedReceiptItem(name: name.isEmpty ? "Item" : name, quantity: qty, unitPrice: price, totalPrice: totalPrice, category: nil)
    }
}
