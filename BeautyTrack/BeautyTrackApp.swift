//
//  BeautyTrackApp.swift
//  BeautyTrack
//
//  Created by System on 11/30/25.
//

import SwiftUI
import SwiftData

@main
struct BeautyTrackApp: App {
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Product.self,
            Expense.self,
            Receipt.self,
            ReceiptItem.self,
        ])

        // Try creating a persistent container first; fall back to in-memory on failure.
        let persistentConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [persistentConfig])
        } catch {
            print("Warning: Could not create persistent ModelContainer: \(error). Falling back to in-memory container.")
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("Could not create even an in-memory ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            if #available(iOS 17.0, *) {
                // Create a single InventoryManager backed by the shared model container
                let inventoryManager = InventoryManager(modelContext: Self.sharedModelContainer.mainContext)
                ContentView()
                    .environmentObject(inventoryManager)
                    .accentColor(.blue)
            } else {
                // Fallback for earlier versions
                Text("BeautyTrack requires iOS 17.0 or later")
                    .padding()
                    .accentColor(.blue)
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
