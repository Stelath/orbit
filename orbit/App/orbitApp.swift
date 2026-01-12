//
//  orbitApp.swift
//  orbit
//
//  Created by Alexander Korte on 1/9/26.
//

import SwiftUI
import SwiftData

@main
struct orbitApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Settings Models
            AIProviderSettings.self,
            // Accounts Models
            GoogleAccount.self,
            // Email Models
            DownloadedEmail.self,
            SpamFilterRule.self,
            // Calendar Models
            CalendarEvent.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
