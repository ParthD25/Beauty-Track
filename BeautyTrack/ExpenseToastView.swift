import SwiftUI

@available(iOS 17.0, *)
struct ExpenseToastView: View {
    let expense: Expense
    let dismissAction: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Expense Recorded")
                    .font(.headline)
                
                if let productName = expense.productName {
                    Text("\(productName): $\(String(format: "%.2f", expense.amount))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("$\(String(format: "%.2f", expense.amount)) - \(expense.normalizedCategory)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: dismissAction) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding(.horizontal)
        .padding(.top, 50)
    }
}