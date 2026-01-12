//
//  SettingsView.swift
//  orbit
//
//  View for AI provider settings configuration
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()

    // State for single provider configuration section
    @State private var selectedProvider: AIProvider = .openAI
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var selectedModel: String = ""
    @State private var showKey: Bool = false
    @State private var isExpanded: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Single provider configuration section
                providerConfigurationSection

                // Footer
                footerSection
            }
            .padding()
        }
        .onAppear {
            loadProviderData(for: selectedProvider)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showingSaveConfirmation {
                SavedConfirmationToast()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: viewModel.showingSaveConfirmation)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Provider Settings", systemImage: "gearshape")
                .font(.title)
                .fontWeight(.bold)

            Text("Configure API keys and models for AI providers")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Provider Configuration Section

    private var providerConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (collapsible)
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("AI Provider Configuration", systemImage: "cpu")
                        .font(.headline)

                    Spacer()

                    // Show checkmark if current provider has API key
                    if viewModel.hasAPIKey(provider: selectedProvider) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                // Provider picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Provider")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Select Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Label(provider.rawValue, systemImage: provider.systemImage)
                                .tag(provider)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedProvider) { _, newProvider in
                        loadProviderData(for: newProvider)
                    }
                }

                Divider()

                // API Key field (shown for all except LocalLlama)
                if selectedProvider.requiresAPIKey {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack {
                            if showKey {
                                TextField("Enter your API key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("Enter your API key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Button {
                                showKey.toggle()
                            } label: {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                            .help(showKey ? "Hide key" : "Show key")
                        }
                    }
                }

                // Base URL field (shown for OpenRouter and LocalLlama)
                if selectedProvider.requiresBaseURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base URL")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Enter base URL", text: $baseURL)
                            .textFieldStyle(.roundedBorder)

                        if let defaultURL = selectedProvider.defaultBaseURL {
                            Text("Default: \(defaultURL)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Model picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Select model", selection: $selectedModel) {
                        ForEach(selectedProvider.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .labelsHidden()
                }

                Divider()

                // Action buttons
                HStack {
                    Button("Save") {
                        saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedProvider.requiresAPIKey && apiKey.isEmpty)

                    if viewModel.hasAPIKey(provider: selectedProvider) {
                        Button("Delete Key", role: .destructive) {
                            viewModel.deleteAPIKey(provider: selectedProvider)
                            apiKey = ""
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 8) {
            Label("Keys are stored securely in your device's keychain", systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("API keys are never shared or transmitted outside of direct API calls")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Methods

    private func loadProviderData(for provider: AIProvider) {
        // Load API key from Keychain
        if let key = viewModel.getAPIKey(provider: provider) {
            apiKey = key
        } else {
            apiKey = ""
        }

        // Load settings from SwiftData
        if let settings = viewModel.loadProviderSettings(context: modelContext, provider: provider) {
            selectedModel = settings.selectedModel
            baseURL = settings.baseURL ?? provider.defaultBaseURL ?? ""
        } else {
            selectedModel = provider.availableModels.first ?? ""
            baseURL = provider.defaultBaseURL ?? ""
        }

        // Reset show key state when switching providers
        showKey = false
    }

    private func saveSettings() {
        // Save API key to Keychain
        if selectedProvider.requiresAPIKey && !apiKey.isEmpty {
            viewModel.saveAPIKey(provider: selectedProvider, key: apiKey)
        } else if selectedProvider == .localLlama && !baseURL.isEmpty {
            viewModel.saveAPIKey(provider: selectedProvider, key: baseURL)
        }

        // Save model selection to SwiftData
        viewModel.saveProviderSettings(
            context: modelContext,
            provider: selectedProvider,
            model: selectedModel,
            baseURL: baseURL.isEmpty ? nil : baseURL
        )
    }
}

// MARK: - Saved Confirmation Toast

struct SavedConfirmationToast: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text("Settings saved")
                .fontWeight(.medium)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(radius: 10)
        .padding(.bottom, 20)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [AIProviderSettings.self], inMemory: true)
}
