//
//  AIProviderSettings.swift
//  orbit
//
//  Model for AI provider settings
//

import Foundation
import SwiftData

/// AI provider enum
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case gemini = "Google Gemini"
    case claude = "Anthropic Claude"
    case openRouter = "OpenRouter"
    case localLlama = "Local Llama"

    var id: String { rawValue }

    /// System icon for the provider
    var systemImage: String {
        switch self {
        case .openAI: return "brain"
        case .gemini: return "sparkle"
        case .claude: return "message.fill"
        case .openRouter: return "network"
        case .localLlama: return "desktopcomputer"
        }
    }

    /// Available models for this provider
    var availableModels: [String] {
        switch self {
        case .openAI:
            return [
                "gpt-4",
                "gpt-4-turbo",
                "gpt-3.5-turbo",
                "gpt-3.5-turbo-16k"
            ]
        case .gemini:
            return [
                "gemini-pro",
                "gemini-pro-vision",
                "gemini-ultra"
            ]
        case .claude:
            return [
                "claude-3-opus-20240229",
                "claude-3-sonnet-20240229",
                "claude-3-haiku-20240307",
                "claude-2.1",
                "claude-2.0"
            ]
        case .openRouter:
            return [
                "openai/gpt-4",
                "anthropic/claude-3-opus",
                "anthropic/claude-3-sonnet",
                "google/gemini-pro",
                "meta-llama/llama-3-70b"
            ]
        case .localLlama:
            return [
                "llama2",
                "llama2:13b",
                "llama2:70b",
                "codellama",
                "mistral",
                "mixtral"
            ]
        }
    }

    /// Whether this provider requires an API key
    var requiresAPIKey: Bool {
        return self != .localLlama
    }

    /// Whether this provider requires a base URL
    var requiresBaseURL: Bool {
        return self == .openRouter || self == .localLlama
    }

    /// Default base URL for provider
    var defaultBaseURL: String? {
        switch self {
        case .openRouter:
            return "https://openrouter.ai/api/v1"
        case .localLlama:
            return "http://localhost:11434"
        default:
            return nil
        }
    }
}

/// AI provider settings model
/// Note: API keys are stored in Keychain, not in this model
@Model
final class AIProviderSettings {
    /// Unique identifier
    var id: UUID

    /// Provider type
    var provider: AIProvider

    /// Selected model for this provider
    var selectedModel: String

    /// Base URL (for OpenRouter and LocalLlama)
    var baseURL: String?

    /// Whether this provider is enabled
    var isEnabled: Bool

    /// Last time settings were updated
    var lastUpdated: Date

    // MARK: - Initialization

    init(
        provider: AIProvider,
        selectedModel: String? = nil,
        baseURL: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.provider = provider
        self.selectedModel = selectedModel ?? provider.availableModels.first ?? ""
        self.baseURL = baseURL ?? provider.defaultBaseURL
        self.isEnabled = isEnabled
        self.lastUpdated = Date()
    }

    // MARK: - Methods

    /// Update settings and timestamp
    func updateSettings(model: String, baseURL: String? = nil) {
        self.selectedModel = model
        if let url = baseURL {
            self.baseURL = url
        }
        self.lastUpdated = Date()
    }
}
