import SwiftUI
import UniformTypeIdentifiers
import UIKit

@available(iOS 17.0, *)
struct SettingsView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @AppStorage(UserPreferences.appearanceKey) private var appearanceSelection = AppearanceOption.system.rawValue
    @AppStorage(UserPreferences.salonNameKey) private var salonName: String = ""
    @AppStorage(UserPreferences.ownerNameKey) private var ownerName: String = ""
    @AppStorage(UserPreferences.emailKey) private var contactEmail: String = ""
    @State private var notificationsEnabled = false
    @State private var lowStockThreshold = 2
    @State private var criticalStockThreshold = 1
    @State private var customCategories: [String] = SalonCategory.customCategories()
    @State private var newCategoryName: String = ""
    @State private var showingPrivacy = false
    @State private var showingTerms = false
    @State private var shareSheetItem: ShareSheetItem?
    @State private var showingImporter = false
    @State private var alertItem: AlertItem?
    
    var body: some View {
        Form {
            profileSection
            appearanceSection
            categoryReferenceSection
            customCategorySection

            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)

                if notificationsEnabled {
                    Stepper("Low Stock Alert: \(lowStockThreshold) days", value: $lowStockThreshold, in: 1...7)
                    Stepper("Critical Alert: \(criticalStockThreshold) days", value: $criticalStockThreshold, in: 1...3)
                }
            }
            
            Section("Data Management") {
                Button(action: handleExport) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Data")
                    }
                }
                
                Button(action: { showingImporter = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Data")
                    }
                }
                
                Button(role: .destructive) {
                    // TODO: implement reset when requirements are defined
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Reset All Data")
                    }
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    showingPrivacy = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Privacy Policy")
                    }
                }
                .sheet(isPresented: $showingPrivacy) {
                    PolicyDocumentView(title: "Privacy Policy")
                }

                Button(action: {
                    showingTerms = true
                }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text("Terms of Service")
                    }
                }
                .sheet(isPresented: $showingTerms) {
                    PolicyDocumentView(title: "Terms of Service")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $shareSheetItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .sheet(isPresented: $showingImporter) {
            DocumentPickerView(onPick: { url in
                handleImport(from: url)
                showingImporter = false
            }, onCancel: {
                showingImporter = false
            })
        }
        .alert(item: $alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            refreshCustomCategories()
        }
    }
}

@available(iOS 17.0, *)
private extension SettingsView {
    var appearanceOption: AppearanceOption {
        AppearanceOption(rawValue: appearanceSelection) ?? .system
    }

    var profileSection: some View {
        Section("Profile") {
            TextField("Salon name", text: $salonName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            TextField("Owner or manager", text: $ownerName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            TextField("Contact email", text: $contactEmail)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled(true)
        }
    }

    var appearanceSection: some View {
        Section("Appearance") {
            Picker("App appearance", selection: $appearanceSelection) {
                ForEach(AppearanceOption.allCases) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Text(appearanceDescription(for: appearanceOption))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    var categoryReferenceSection: some View {
        Section("Inventory Categories") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(SalonCategory.all) { category in
                    Text(category.name)
                        .font(.headline)
                    if category.id != SalonCategory.all.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    var customCategorySection: some View {
        Section("Custom Categories") {
            if customCategories.isEmpty {
                Text("Add your own salon-specific groups to use in inventory and reporting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(customCategories, id: \.self) { category in
                    Text(category)
                }
                .onDelete { offsets in
                    removeCustomCategories(at: offsets)
                }
            }

            HStack(spacing: 12) {
                TextField("Add another category", text: $newCategoryName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                Button(action: addCustomCategory) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(!canAddCustomCategory)
            }
            .padding(.top, 8)
        }
    }

    func handleExport() {
        do {
            let url = try inventoryManager.createBackupFile()
            shareSheetItem = ShareSheetItem(url: url)
        } catch {
            alertItem = AlertItem(title: "Export Failed", message: error.localizedDescription)
        }
    }

    func handleImport(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            try inventoryManager.restoreBackup(from: data)
            alertItem = AlertItem(title: "Import Complete", message: "Data restored successfully.")
            refreshCustomCategories()
        } catch {
            alertItem = AlertItem(title: "Import Failed", message: error.localizedDescription)
        }
    }

    struct ShareSheetItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    func appearanceDescription(for option: AppearanceOption) -> String {
        switch option {
        case .system:
            return "Matches the iPhone/iPad system setting."
        case .light:
            return "Forces a bright interface for charts and forms."
        case .dark:
            return "Great for low-light stations and evening shifts."
        }
    }

    var canAddCustomCategory: Bool {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let exists = (customCategories + SalonCategory.all.map { $0.name })
            .contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        return !exists
    }

    func addCustomCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        SalonCategory.addCustomCategory(trimmed)
        refreshCustomCategories()
        newCategoryName = ""
    }

    func removeCustomCategories(at offsets: IndexSet) {
        SalonCategory.removeCustomCategories(at: offsets)
        refreshCustomCategories()
    }

    func refreshCustomCategories() {
        customCategories = SalonCategory.customCategories()
    }
}

@available(iOS 17.0, *)
struct ManageLocationsView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(inventoryManager.locations, id: \.self) { loc in
                    HStack {
                        Text(loc.capitalized)
                        Spacer()
                        if loc == inventoryManager.currentLocation {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        inventoryManager.currentLocation = loc
                        dismiss()
                    }
                }
                .onDelete { offsets in
                    inventoryManager.removeLocation(at: offsets)
                    if !inventoryManager.locations.contains(inventoryManager.currentLocation) {
                        inventoryManager.currentLocation = inventoryManager.locations.first ?? ""
                    }
                }
            }
            .navigationTitle("Manage Locations")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Inlined Policy Document View (keeps code inside project sources so Xcode picks it up)
@available(iOS 17.0, *)
struct PolicyDocumentView: View {
    let title: String

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    documentText
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 24)
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

    private var documentText: some View {
        let markdown = contentFor(title: title)
        if let attributed = try? AttributedString(markdown: markdown) {
            return Text(attributed)
        } else {
            return Text(verbatim: markdown)
        }
    }

    private func contentFor(title: String) -> String {
        if title.lowercased().contains("privacy") {
            return privacyContent
        } else {
            return termsContent
        }
    }

    private var privacyContent: String {
        """
        # Privacy Policy

        **Effective Date:** November 30, 2025

        BeautyTrack ("we", "us", or "our") respects your privacy. This Privacy Policy explains how the BeautyTrack mobile application (the "App") collects, uses, and safeguards information when you manage inventory, receipts, and expenses on your iPhone or iPad. By installing or using the App you agree to this Policy. If you disagree with any part, please uninstall the App and discontinue use.

        ## 1. Information We Collect

        - **Inventory and product entries.** Names, stock counts, SKU identifiers, purchase costs, reorder thresholds, and related notes you manually enter.
        - **Expense and receipt information.** Suppliers, amounts, receipt images, parsed receipt data, categories, and notes recorded through manual entry or scanner imports.
        - **Device permissions.** The App requests camera or photo library access when you scan or import receipts. Images are processed locally and remain on your device unless you export them.
        - **Diagnostics.** Anonymous crash logs or performance metrics supplied by Apple. These diagnostics do not include personal identifiers and are used solely to improve stability.

        The App does not require account registration, location data, or payment card details. Any optional personal information you include inside notes remains on-device unless you export data.

        ## 2. How We Use Information

        We use the collected information to:

        - Deliver core functionality, including inventory calculations, usage forecasting, low-stock notifications, and expense summaries.
        - Maintain accurate records when you adjust stock or import receipts.
        - Respond to support requests and troubleshoot defects.
        - Comply with legal obligations and enforce our Terms of Service.

        We do not sell or rent your data and we do not share it with advertisers.

        ## 3. Data Storage and Security

        - **On-device storage.** Inventory, expense, and receipt data are stored locally using Apple’s secure storage frameworks. Removing the App or resetting your device deletes the local database unless you exported a backup.
        - **Backups.** If you enable iCloud or encrypted device backups, copies of the App’s database may be included in those system-level backups. Manage backup retention through your device settings.
        - **Security practices.** BeautyTrack relies on iOS/iPadOS sandboxing, File Protection classes, and biometric/passcode controls. We recommend enabling a device passcode and Face ID or Touch ID.

        ## 4. Data Sharing

        We share information only when necessary:

        - With Apple Inc. to provide system services such as notifications, photo access, or app distribution.
        - With service providers assisting with customer support or crash analytics, subject to confidentiality agreements.
        - When required by law, regulation, subpoena, or court order, or to protect our rights or the rights and safety of others.

        ## 5. Your Choices

        - **Permissions.** You can revoke camera or photo access at any time in iOS/iPadOS Settings. Some features may stop working if permissions are disabled.
        - **Editing and deletion.** You may add, edit, or delete records directly inside the App. Deleting the App removes its local data store from the device.
        - **Notifications.** Adjust low-stock notification preferences within the App or through system Settings > Notifications.

        ## 6. Children’s Privacy

        BeautyTrack is intended for salon professionals and is not directed to children under 13. If we learn that we unintentionally collected information from a child under 13, we will delete it promptly.

        ## 7. International Considerations

        The App stores data on the device where it is installed. Depending on your backup configuration, data may be transferred to Apple servers located in the United States or other jurisdictions where privacy laws may differ.

        ## 8. Changes to This Policy

        We may update this Policy to reflect legal, technical, or business developments. When we make material changes, we will highlight them within the App or release notes. Continued use after an update constitutes acceptance of the revised Policy.

        ## 9. Contact Us

        For privacy inquiries or requests, contact:

        > BeautyTrack Privacy Team  
        > 1234 Market Street, Suite 500  
        > San Francisco, CA 94105  
        > privacy@beautytrack.app

        We aim to acknowledge verified requests within thirty (30) days.
        """
    }

    private var termsContent: String {
        """
        # Terms of Service

        **Effective Date:** November 30, 2025

        These Terms of Service ("Terms") govern your use of the BeautyTrack mobile application (the "App"). By downloading, accessing, or using the App you agree to be bound by these Terms. If you do not agree, do not install or use the App.

        ## 1. License Grant

        We grant you a limited, non-exclusive, non-transferable, revocable license to install and use the App on any iOS or iPadOS device you own or control, strictly in accordance with these Terms and Apple’s App Store Terms of Service.

        ## 2. Permitted Use

        You agree to:

        - Use the App solely for managing salon or retail inventory, expenses, and related business records.
        - Comply with all applicable laws, regulations, and industry standards while using the App.
        - Maintain accurate data and back up records regularly using the built-in export features or your own device backups.

        ## 3. Prohibited Conduct

        You may not:

        - Reverse engineer, decompile, or disassemble any part of the App except where expressly permitted by law.
        - Circumvent security features, use the App for unlawful activities, or transmit malicious code.
        - Rent, lease, sell, sublicense, or redistribute the App or derived datasets to third parties without our written consent.

        ## 4. Data Ownership and Responsibility

        You retain ownership of the inventory, receipt, and expense data you enter. You are solely responsible for the accuracy of that data and for complying with retention or reporting requirements that apply to your business. We provide export and import capabilities so you can maintain independent backups.

        ## 5. Third-Party Services

        The App may integrate with system services provided by Apple (e.g., camera, photo library, notifications). Your use of those services is governed by Apple’s terms and privacy policies. We are not responsible for third-party services beyond our reasonable control.

        ## 6. Updates and Availability

        We may provide updates that add, modify, or remove features. We are under no obligation to continue supporting older versions of the App. Downtime may occur due to maintenance, technical issues, or events beyond our control.

        ## 7. Disclaimers

        THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. YOUR USE OF THE APP IS AT YOUR OWN RISK.

        ## 8. Limitation of Liability

        TO THE MAXIMUM EXTENT PERMITTED BY LAW, BEAUTYTRACK LLC AND ITS OFFICERS, EMPLOYEES, AND AGENTS WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, CONSEQUENTIAL, SPECIAL, OR EXEMPLARY DAMAGES ARISING OUT OF OR IN CONNECTION WITH THE APP, INCLUDING LOST PROFITS, LOST DATA, OR BUSINESS INTERRUPTION, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. OUR TOTAL LIABILITY FOR ANY CLAIMS UNDER THESE TERMS SHALL NOT EXCEED THE AMOUNT YOU PAID (IF ANY) TO DOWNLOAD THE APP.

        ## 9. Indemnification

        You agree to indemnify and hold harmless BeautyTrack LLC from any claims, damages, liabilities, costs, and expenses (including reasonable attorneys’ fees) arising from your misuse of the App, violation of these Terms, or infringement of any third-party rights.

        ## 10. Termination

        We may suspend or terminate your access to the App at any time if we believe you have violated these Terms. Upon termination, the license granted to you ends immediately and you must cease using and uninstall the App.

        ## 11. Governing Law

        These Terms are governed by the laws of the State of California, without regard to its conflict of law principles. You agree to the exclusive jurisdiction of state and federal courts located in San Francisco County, California.

        ## 12. Changes to These Terms

        We may modify these Terms from time to time. Material changes will be communicated through in-app notices or release notes. Continued use after changes become effective constitutes acceptance of the revised Terms.

        ## 13. Contact

        For questions about these Terms, contact:

        > BeautyTrack Legal Department  
        > 1234 Market Street, Suite 500  
        > San Francisco, CA 94105  
        > legal@beautytrack.app
        """
    }
}

// MARK: - UIKit helpers

@available(iOS 17.0, *)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@available(iOS 17.0, *)
struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json], asCopy: true)
        controller.allowsMultipleSelection = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}