//
//  ContentView.swift
//  orbit
//
//  Created by Alexander Korte on 1/9/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection: Feature? = .aiAssistant

    var body: some View {
        NavigationSplitView {
            List(Feature.allCases, selection: $selection) { feature in
                Label(feature.title, systemImage: feature.systemImage)
                    .tag(feature)
            }
            .navigationTitle("Features")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            Group {
                switch selection {
                case .aiAssistant:
                    SettingsView()
                case .accounts:
                    AccountsView()
                case .email:
                    EmailView()
                case .calendar:
                    CalendarView()
                case .none:
                    Text("Select a feature")
                }
            }
            .navigationTitle(selection?.title ?? "")
        }
    }
}

#Preview {
    ContentView()
}
