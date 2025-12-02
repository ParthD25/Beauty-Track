import SwiftUI

@available(iOS 17.0, *)
struct ExpensesView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @State private var selectedRange: TimeRange = .today

    private struct CategoryBreakdown: Identifiable {
        let id: String
        let name: String
        let total: Double
    }

    private enum TimeRange: String, CaseIterable, Identifiable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case allTime = "All Time"

        var id: String { rawValue }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                rangeSelector
                overviewSection
                categorySection
                usageSection
                recentUpdatesSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Expenses")
    }

    private var overviewSection: some View {
        let totals = expenseTotals(for: selectedRange)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Total Expense")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(totals.netTotal, format: .currency(code: "USD"))
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(totals.netTotal >= 0 ? Color.blue : Color.red)
                .minimumScaleFactor(0.7)

            Text("Current Inventory Value")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
    }

    private var categorySection: some View {
        let breakdown = categoryBreakdown(for: selectedRange)
        let totalForPercent = breakdown.reduce(0) { $0 + abs($1.total) }

        return VStack(alignment: .leading, spacing: 16) {
            Text("Category Breakdown")
                .font(.headline)

            if breakdown.isEmpty {
                Text("No expense activity for this range.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(breakdown) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .font(.body)
                            Spacer()
                            Text(item.total, format: .currency(code: "USD"))
                                .font(.headline)
                                .foregroundStyle(item.total >= 0 ? Color.primary : Color.red)
                        }

                        if totalForPercent > 0 {
                            let percentage = abs(item.total) / totalForPercent
                            Text(percentage, format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                }
            }
        }
    }

    private var usageSection: some View {
        let usageExpenses = usageExpenses(for: selectedRange)
        let totalUsage = usageExpenses.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Usage-based Expenses")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Usage Cost")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(totalUsage, format: .currency(code: "USD"))
                    .font(.title2.bold())
            }

            if usageExpenses.isEmpty {
                Text("No usage recorded for this range.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(usageExpenses, id: \.id) { expense in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.productName ?? expense.normalizedCategory)
                                    .font(.headline)
                                Text("Quantity Used: \(expense.quantity)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(expense.amount, format: .currency(code: "USD"))
                                .font(.headline)
                        }

                        if let perUnit = perUnitLabel(for: expense) {
                            Text(perUnit)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                }
            }
        }
    }

    private var recentUpdatesSection: some View {
        let recent = recentExpenses(for: selectedRange)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Recent Updates")
                .font(.headline)

            if recent.isEmpty {
                Text("No recent activity in this range.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent, id: \.id) { expense in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.productName ?? expense.normalizedCategory)
                                    .font(.headline)
                                Text(quantityLabel(for: expense))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(expense.amount, format: .currency(code: "USD"))
                                    .font(.headline)
                                Text(relativeTimeString(for: expense.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                }
            }
        }
    }

    private func expenseTotals(for range: TimeRange) -> (netTotal: Double, purchasedTotal: Double, usageTotal: Double) {
        let expenses = filteredExpenses(for: range)
        let purchased = expenses.filter { $0.normalizedCategory != "Stock Spent" }
            .reduce(0) { $0 + $1.amount }
        let usage = expenses.filter { $0.normalizedCategory == "Stock Spent" }
            .reduce(0) { $0 + $1.amount }
        let net = purchased - usage
        return (net, purchased, usage)
    }

    private func categoryBreakdown(for range: TimeRange) -> [CategoryBreakdown] {
        let categoryNames = Set(SalonCategory.names + ["Other"])
        var totals: [String: Double] = [:]
        for name in categoryNames {
            totals[name] = 0
        }

        let expenses = filteredExpenses(for: range)
        for expense in expenses {
            let categoryName = categoryName(for: expense)
            let amount = adjustedAmount(for: expense)
            totals[categoryName, default: 0] += amount
        }

        return totals.compactMap { key, value in
            value == 0 ? nil : CategoryBreakdown(id: key, name: key, total: value)
        }
        .sorted { abs($0.total) > abs($1.total) }
    }

    private func usageExpenses(for range: TimeRange) -> [Expense] {
        filteredExpenses(for: range)
            .filter { $0.normalizedCategory == "Stock Spent" }
            .sorted { $0.date > $1.date }
    }

    private func recentExpenses(for range: TimeRange) -> [Expense] {
        filteredExpenses(for: range)
            .sorted { $0.date > $1.date }
            .prefix(6)
            .map { $0 }
    }

    private func filteredExpenses(for range: TimeRange) -> [Expense] {
        let calendar = Calendar.current
        let now = Date()
        let location = inventoryManager.currentLocation

        return inventoryManager.expenses.filter { expense in
            guard expense.location.isEmpty || expense.location == location else { return false }

            switch range {
            case .today:
                return calendar.isDateInToday(expense.date)
            case .thisWeek:
                guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return false }
                return expense.date >= startOfWeek
            case .thisMonth:
                guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return false }
                return expense.date >= startOfMonth
            case .lastMonth:
                guard
                    let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                    let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth),
                    let endOfLastMonth = calendar.date(byAdding: DateComponents(second: -1), to: startOfThisMonth)
                else {
                    return false
                }
                return expense.date >= startOfLastMonth && expense.date <= endOfLastMonth
            case .allTime:
                return true
            }
        }
    }

    private func perUnitLabel(for expense: Expense) -> String? {
        guard expense.quantity > 0 else { return nil }
        let perUnit = expense.amount / Double(expense.quantity)
        let descriptor = unitDescriptor(for: expense)
        let formatted = perUnit.formatted(.currency(code: "USD"))
        return "\(formatted) / \(descriptor)"
    }

    private func unitDescriptor(for expense: Expense) -> String {
        guard let name = expense.productName?.lowercased() else { return "each" }
        if name.contains("pack") || name.contains("case") || name.contains("box") {
            return "unit"
        }
        return "each"
    }

    private func quantityLabel(for expense: Expense) -> String {
        let descriptor = unitDescriptor(for: expense)
        let quantity = expense.quantity
        let descriptorText = descriptor == "each" ? (quantity == 1 ? "piece" : "pieces") : (quantity == 1 ? "unit" : "units")
        return "\(quantity) \(descriptorText)"
    }

    private func relativeTimeString(for date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "Just now"
        }
        return ExpensesView.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func categoryName(for expense: Expense) -> String {
        guard let productName = expense.productName else {
            return "Other"
        }

        if let product = inventoryManager.products.first(where: { $0.name.caseInsensitiveCompare(productName) == .orderedSame }) {
            return product.category
        }

        return "Other"
    }

    private func adjustedAmount(for expense: Expense) -> Double {
        switch expense.normalizedCategory {
        case "Stock Spent":
            return -expense.amount
        default:
            return expense.amount
        }
    }

    private var rangeSelector: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct ExpenseDetailView: View {
    let expense: Expense
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Expense Details") {
                    LabeledContent("Category", value: expense.normalizedCategory)
                    if let productName = expense.productName {
                        LabeledContent("Product", value: productName)
                    }
                    LabeledContent("Amount", value: expense.amount, format: .currency(code: "USD"))
                    LabeledContent("Quantity", value: "\(expense.quantity)")
                    LabeledContent("Location", value: expense.location)
                    LabeledContent("Date", value: expense.date, format: .dateTime)
                    if let notes = expense.notes {
                        LabeledContent("Notes", value: notes)
                    }
                }
            }
            .navigationTitle("Expense Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProductExpenseHistoryView: View {
    let productName: String
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                let productExpenses = inventoryManager.expenses
                    .filter { $0.productName == productName }
                    .sorted(by: { $0.date > $1.date })
                
                if productExpenses.isEmpty {
                    Text("No expenses found for this product")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(productExpenses, id: \.id) { expense in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(expense.normalizedCategory)
                                    .font(.headline)
                                Spacer()
                                Text(expense.amount, format: .currency(code: "USD"))
                                    .font(.headline)
                            }
                            Text(expense.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let notes = expense.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("\(productName) Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}