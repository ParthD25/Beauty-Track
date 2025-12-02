import SwiftUI
import PhotosUI
import Vision
import UIKit

@available(iOS 17.0, *)
struct ReceiptScannerView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showingManualEntry = false
    @State private var isProcessing = false
    @State private var alertMessage: String?
    @State private var showingAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            Text("Scan Receipt")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Take a photo of your receipt to automatically add products to your inventory")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }

            Button(action: {
                showingImagePicker = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text(isProcessing ? "Processing…" : "Scan Receipt")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(isProcessing)

            Button(action: {
                showingManualEntry = true
            }) {
                Text("Enter Receipt Manually")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualReceiptEntryView()
                    .environmentObject(inventoryManager)
            }
        }
        .padding()
        .photosPicker(isPresented: $showingImagePicker, selection: $photoItem, matching: .images, photoLibrary: .shared())
        .onChange(of: photoItem) { oldValue, newValue in
            guard let item = newValue else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                        // Directly process the selected image
                        DispatchQueue.main.async {
                            selectedImage = ui
                        }
                        processImage(ui)
                    }
                } catch {
                    DispatchQueue.main.async {
                        alertMessage = "Could not load image: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        }
        .onAppear {
            // No-op
        }
        .alert(alertMessage ?? "", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        ReceiptParser.parse(image: image) { parsed in
            DispatchQueue.main.async {
                isProcessing = false
                let supplier = parsed.supplier ?? "Scanned"
                let total = parsed.total ?? parsed.items.reduce(0) { $0 + $1.totalPrice }
                let location = inventoryManager.currentLocation

                // Convert parsed items to ReceiptItem models
                let rItems = parsed.items.map { p -> ReceiptItem in
                    ReceiptItem(productName: p.name, quantity: p.quantity, unitPrice: p.unitPrice, totalPrice: p.totalPrice, confidence: 0.9, status: "matched")
                }

                inventoryManager.addParsedReceipt(supplier: supplier, total: total, location: location, parsedItems: rItems)
                alertMessage = "Parsed receipt with \(rItems.count) items."
                showingAlert = true
                selectedImage = nil
            }
        }
    }
}

// MARK: - Inlined ReceiptParser
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

        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !cleaned.isEmpty {
            supplier = cleaned.first
        }

        for line in cleaned.reversed() {
            let lower = line.lowercased()
            if lower.contains("total") || lower.contains("subtotal") || lower.contains("amount") {
                if let t = extractFirstPrice(from: line) {
                    total = t
                    break
                }
            }
            if total == nil, let t = extractFirstPrice(from: line) {
                total = t
                break
            }
        }

        let candidateItemLines = cleaned.dropFirst(1).dropLast(3)
        for raw in candidateItemLines {
            if let item = parseItemLine(raw) {
                items.append(item)
            }
        }

        return ParsedReceipt(supplier: supplier, total: total, items: items)
    }

    private static func extractFirstPrice(from text: String) -> Double? {
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
        let tokens = line.split(separator: " ").map { String($0) }
        guard !tokens.isEmpty else { return nil }

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

// MARK: - Inlined ManualReceiptEntryView
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
                    ForEach($items, id: \.id) { $item in
                        ItemRowView(item: $item)
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

        inventoryManager.addParsedReceipt(
            supplier: supplier.isEmpty ? "Manual" : supplier,
            total: tot,
            location: location.isEmpty ? inventoryManager.currentLocation : location,
            parsedItems: parsedItems
        )
        dismiss()
    }
}

@available(iOS 17.0, *)
private struct ItemRowView: View {
    @Binding var item: ManualReceiptEntryView.ManualItem

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: $item.name)
            HStack {
                TextField("Qty", text: $item.quantity)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 80)
                TextField("Price", text: $item.price)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 120)
            }
            TextField("Category", text: $item.category)
            TextField("Column", text: $item.column)
        }
    }
}
