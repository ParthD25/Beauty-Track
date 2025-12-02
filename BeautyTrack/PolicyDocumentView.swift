import SwiftUI

@available(iOS 17.0, *)
struct PolicyDocumentView: View {
    let title: String
    let filename: String // resource filename (without extension) in bundle

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let content = loadMarkdown(filename: filename) {
                        // Use AttributedString markdown rendering when available
                        if let attr = try? AttributedString(markdown: content) {
                            Text(attr)
                                .padding()
                        } else {
                            Text(content)
                                .padding()
                        }
                    } else {
                        Text("Document not found.")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    Spacer()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func loadMarkdown(filename: String) -> String? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

struct PolicyDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PolicyDocumentView(title: "Privacy Policy", filename: "PrivacyPolicy")
        }
    }
}
