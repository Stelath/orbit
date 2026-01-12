//
//  SettingsViewModel.swift
//  orbit
//
//  ViewModel for AI provider settings management
//

import Foundation
import SwiftData
import Observation

/// ViewModel for Settings feature
@Observable
final class SettingsViewModel {
    // MARK: - Properties

    private let secureStorage = SecureStorage()

    /// API Keys (in memory, loaded from keychain)
    var openAIKey: String = ""
    var geminiKey: String = ""
    var claudeKey: String = ""
    var openRouterKey: String = ""
    var localLlamaURL: String = ""

    /// UI state for showing/hiding keys
    var showOpenAIKey: Bool = false
    var showGeminiKey: Bool = false
    var showClaudeKey: Bool = false
    var showOpenRouterKey: Bool = false

    /// Save confirmation
    var showingSaveConfirmation: Bool = false

    /// Error message
    var errorMessage: String?

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Public Methods

    /// Load settings from keychain
    func loadSettings() {
        // Load API keys
        if case .success(let key) = secureStorage.retrieve(key: SecureStorage.openAIKey) {
            openAIKey = key
        }

        if case .success(let key) = secureStorage.retrieve(key: SecureStorage.geminiKey) {
            geminiKey = key
        }

        if case .success(let key) = secureStorage.retrieve(key: SecureStorage.claudeKey) {
            claudeKey = key
        }

        if case .success(let key) = secureStorage.retrieve(key: SecureStorage.openRouterKey) {
            openRouterKey = key
        }

        if case .success(let url) = secureStorage.retrieve(key: SecureStorage.localLlamaURL) {
            localLlamaURL = url
        }
    }

    /// Save API key for a provider
    /// - Parameters:
    ///   - provider: AI provider
    ///   - key: API key or URL to save
    func saveAPIKey(provider: AIProvider, key: String) {
        let storageKey = keyForProvider(provider)

        switch secureStorage.save(key: storageKey, value: key) {
        case .success:
            showingSaveConfirmation = true
            errorMessage = nil

            // Update in-memory value
            switch provider {
            case .openAI: openAIKey = key
            case .gemini: geminiKey = key
            case .claude: claudeKey = key
            case .openRouter: openRouterKey = key
            case .localLlama: localLlamaURL = key
            }

            // Auto-dismiss confirmation after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    showingSaveConfirmation = false
                }
            }

        case .failure(let error):
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
        }
    }

    /// Delete API key for a provider
    /// - Parameter provider: AI provider
    func deleteAPIKey(provider: AIProvider) {
        let storageKey = keyForProvider(provider)

        switch secureStorage.delete(key: storageKey) {
        case .success:
            // Clear in-memory value
            switch provider {
            case .openAI: openAIKey = ""
            case .gemini: geminiKey = ""
            case .claude: claudeKey = ""
            case .openRouter: openRouterKey = ""
            case .localLlama: localLlamaURL = ""
            }
            errorMessage = nil

        case .failure(let error):
            errorMessage = "Failed to delete API key: \(error.localizedDescription)"
        }
    }

    /// Check if provider has an API key configured
    /// - Parameter provider: AI provider to check
    /// - Returns: True if key exists
    func hasAPIKey(provider: AIProvider) -> Bool {
        let storageKey = keyForProvider(provider)
        return secureStorage.exists(key: storageKey)
    }

    /// Get API key for provider (for testing/validation)
    /// - Parameter provider: AI provider
    /// - Returns: API key if exists
    func getAPIKey(provider: AIProvider) -> String? {
        switch provider {
        case .openAI: return openAIKey.isEmpty ? nil : openAIKey
        case .gemini: return geminiKey.isEmpty ? nil : geminiKey
        case .claude: return claudeKey.isEmpty ? nil : claudeKey
        case .openRouter: return openRouterKey.isEmpty ? nil : openRouterKey
        case .localLlama: return localLlamaURL.isEmpty ? nil : localLlamaURL
        }
    }

    /// Save provider settings to SwiftData
    /// - Parameters:
    ///   - context: SwiftData model context
    ///   - provider: AI provider
    ///   - model: Selected model
    ///   - baseURL: Base URL (optional, for OpenRouter/LocalLlama)
    func saveProviderSettings(context: ModelContext, provider: AIProvider, model: String, baseURL: String? = nil) {
        // Check if settings already exist
        let fetchDescriptor = FetchDescriptor<AIProviderSettings>(
            predicate: #Predicate { settings in
                settings.provider == provider
            }
        )

        do {
            let existingSettings = try context.fetch(fetchDescriptor)

            if let existing = existingSettings.first {
                // Update existing settings
                existing.updateSettings(model: model, baseURL: baseURL)
            } else {
                // Create new settings
                let newSettings = AIProviderSettings(
                    provider: provider,
                    selectedModel: model,
                    baseURL: baseURL
                )
                context.insert(newSettings)
            }

            try context.save()

        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
        }
    }

    /// Load provider settings from SwiftData
    /// - Parameters:
    ///   - context: SwiftData model context
    ///   - provider: AI provider
    /// - Returns: Provider settings if exists
    func loadProviderSettings(context: ModelContext, provider: AIProvider) -> AIProviderSettings? {
        let fetchDescriptor = FetchDescriptor<AIProviderSettings>(
            predicate: #Predicate { settings in
                settings.provider == provider
            }
        )

        do {
            let settings = try context.fetch(fetchDescriptor)
            return settings.first
        } catch {
            return nil
        }
    }

    /// Test connection to provider (placeholder for future implementation)
    /// - Parameter provider: AI provider to test
    /// - Returns: True if connection successful
    func testConnection(provider: AIProvider) async -> Bool {
        // Placeholder for API connection testing
        // In a real implementation, this would make a test API call
        guard hasAPIKey(provider: provider) else {
            errorMessage = "No API key configured for \(provider.rawValue)"
            return false
        }

        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // For now, just return true if key exists
        return true
    }

    // MARK: - Private Methods

    /// Get storage key for provider
    /// - Parameter provider: AI provider
    /// - Returns: Keychain storage key
    private func keyForProvider(_ provider: AIProvider) -> String {
        switch provider {
        case .openAI: return SecureStorage.openAIKey
        case .gemini: return SecureStorage.geminiKey
        case .claude: return SecureStorage.claudeKey
        case .openRouter: return SecureStorage.openRouterKey
        case .localLlama: return SecureStorage.localLlamaURL
        }
    }
}
