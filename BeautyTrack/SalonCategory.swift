import Foundation

/// Represents a recommended inventory category for salon operations.
struct SalonCategory: Identifiable, Hashable {
    let name: String

    var id: String { name }
}

extension SalonCategory {
    /// Concise salon-friendly categories covering the core backbar, retail, and disposable needs.
    static let all: [SalonCategory] = [
        SalonCategory(name: "Color Supplies"),
        SalonCategory(name: "Wash House"),
        SalonCategory(name: "Styling Products"),
        SalonCategory(name: "Treatments & Masks"),
        SalonCategory(name: "Nail Care"),
        SalonCategory(name: "Skin & Body"),
        SalonCategory(name: "Waxing"),
        SalonCategory(name: "Lash & Brow"),
        SalonCategory(name: "Tools & Equipment"),
        SalonCategory(name: "Sanitation & PPE"),
        SalonCategory(name: "Retail Boutique"),
        SalonCategory(name: "Other")
    ]

    static var names: [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for name in all.map({ $0.name }) {
            let key = name.lowercased()
            if seen.insert(key).inserted {
                ordered.append(name)
            }
        }

        for name in customCategories() {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                ordered.append(trimmed)
            }
        }

        return ordered
    }

    static var defaultName: String {
        names.first ?? "General"
    }

    // MARK: - Custom Categories

    private static let customCategoriesKey = "salon.customCategories"

    static func customCategories() -> [String] {
        UserDefaults.standard.stringArray(forKey: customCategoriesKey) ?? []
    }

    static func addCustomCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let existsInCurated = all.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
        var custom = customCategories()
        let existsInCustom = custom.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }

        guard !existsInCurated, !existsInCustom else { return }

        custom.append(trimmed)
        saveCustomCategories(custom)
    }

    static func removeCustomCategories(at offsets: IndexSet) {
        var custom = customCategories()
        for offset in offsets.sorted(by: >) {
            if custom.indices.contains(offset) {
                custom.remove(at: offset)
            }
        }
        saveCustomCategories(custom)
    }

    static func updateCustomCategories(_ categories: [String]) {
        saveCustomCategories(categories)
    }

    private static func saveCustomCategories(_ categories: [String]) {
        UserDefaults.standard.set(categories, forKey: customCategoriesKey)
    }
}
