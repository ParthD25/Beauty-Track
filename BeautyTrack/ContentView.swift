//
//  ContentView.swift
//
//  ContentView.swift
//  BeautyTrack
//
//  Created by System on 11/30/25.
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var inventoryManager: InventoryManager
    @State private var selectedTab = 0
    @AppStorage(UserPreferences.appearanceKey) private var appearanceSelection = AppearanceOption.system.rawValue

    private var selectedAppearance: AppearanceOption {
        AppearanceOption(rawValue: appearanceSelection) ?? .system
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            NavigationStack {
                DashboardView()
                    .environmentObject(inventoryManager)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Dashboard")
            }
            .tag(0)

            // Inventory Tab
            NavigationStack {
                InventoryView()
                    .environmentObject(inventoryManager)
            }
            .tabItem {
                Image(systemName: "archivebox.fill")
                Text("Inventory")
            }
            .tag(1)

            // Scan Receipt Tab
            NavigationStack {
                ReceiptScannerView()
                    .environmentObject(inventoryManager)
            }
            .tabItem {
                Image(systemName: "camera.fill")
                Text("Scan Receipt")
            }
            .tag(2)

            // Expenses Tab
            NavigationStack {
                ExpensesView()
                    .environmentObject(inventoryManager)
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Expenses")
            }
            .tag(3)

            // Settings Tab
            NavigationStack {
                SettingsView()
                    .environmentObject(inventoryManager)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(4)
        }
        .accentColor(Color.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("changeTab"))) { note in
            if let idx = note.object as? Int { selectedTab = idx }
        }
        .overlay(alignment: .top) {
            if #available(iOS 17.0, *) {
                if let exp = inventoryManager.lastCreatedExpense {
                    ExpenseToastView(expense: exp) {
                        inventoryManager.lastCreatedExpense = nil
                    }
                    .transition(AnyTransition.move(edge: .top).combined(with: AnyTransition.opacity))
                    .zIndex(1000)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { inventoryManager.lastCreatedExpense = nil }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(selectedAppearance.colorScheme)
    }
}
