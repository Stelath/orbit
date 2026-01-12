//
//  GmailAPIClient.swift
//  orbit
//
//  HTTP client for Gmail API
//

import Foundation

/// Gmail API client for fetching emails
class GmailAPIClient {
    // MARK: - Properties

    private let baseURL = "https://gmail.googleapis.com/gmail/v1"

    // MARK: - Response Models

    struct GmailMessageList: Codable {
        let messages: [MessageReference]?
        let nextPageToken: String?
        let resultSizeEstimate: Int?
    }

    struct MessageReference: Codable {
        let id: String
        let threadId: String
    }

    struct GmailMessage: Codable {
        let id: String
        let threadId: String
        let labelIds: [String]?
        let snippet: String?
        let internalDate: String?
        let payload: MessagePayload?
    }

    struct MessagePayload: Codable {
        let headers: [MessageHeader]?
        let body: MessageBody?
        let parts: [MessagePart]?
    }

    struct MessageHeader: Codable {
        let name: String
        let value: String
    }

    struct MessageBody: Codable {
        let data: String?
        let size: Int?
    }

    struct MessagePart: Codable {
        let mimeType: String?
        let body: MessageBody?
        let parts: [MessagePart]?
    }

    // MARK: - Errors

    enum APIError: Error, LocalizedError {
        case invalidURL
        case requestFailed(statusCode: Int)
        case unauthorized
        case invalidResponse
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .requestFailed(let statusCode):
                return "Request failed with status code: \(statusCode)"
            case .unauthorized:
                return "Unauthorized - check your access token"
            case .invalidResponse:
                return "Invalid response from Gmail API"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Public Methods

    /// Fetch list of messages
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - maxResults: Maximum number of messages to return (default: 100, max: 500)
    ///   - pageToken: Token for pagination
    /// - Returns: Message list with IDs and next page token
    func fetchMessages(
        accessToken: String,
        maxResults: Int = 100,
        pageToken: String? = nil
    ) async throws -> GmailMessageList {
        var urlComponents = URLComponents(string: "\(baseURL)/users/me/messages")!
        var queryItems = [
            URLQueryItem(name: "maxResults", value: "\(min(maxResults, 500))")
        ]

        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            let messageList = try JSONDecoder().decode(GmailMessageList.self, from: data)
            return messageList
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Get full message details
    /// - Parameters:
    ///   - id: Message ID
    ///   - accessToken: OAuth access token
    /// - Returns: Full message with headers and body
    func getMessage(
        id: String,
        accessToken: String
    ) async throws -> GmailMessage {
        guard let url = URL(string: "\(baseURL)/users/me/messages/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            let message = try JSONDecoder().decode(GmailMessage.self, from: data)
            return message
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Helper Methods

    /// Parse email from Gmail message
    /// - Parameters:
    ///   - message: Gmail message
    ///   - accountEmail: Google account email
    /// - Returns: Parsed DownloadedEmail model
    func parseEmail(message: GmailMessage, accountEmail: String) -> DownloadedEmail? {
        guard let payload = message.payload,
              let headers = payload.headers else {
            return nil
        }

        // Extract headers
        var subject = ""
        var fromEmail = ""
        var fromName: String?
        var toEmails: [String] = []
        var ccEmails: [String] = []
        var dateString = message.internalDate ?? ""

        for header in headers {
            switch header.name.lowercased() {
            case "subject":
                subject = header.value
            case "from":
                let (email, name) = parseEmailAddress(header.value)
                fromEmail = email
                fromName = name
            case "to":
                toEmails = parseEmailAddressList(header.value)
            case "cc":
                ccEmails = parseEmailAddressList(header.value)
            case "date":
                dateString = header.value
            default:
                break
            }
        }

        // Parse date
        let date: Date
        if let timestamp = Double(message.internalDate ?? "0") {
            date = Date(timeIntervalSince1970: timestamp / 1000.0)
        } else {
            date = Date()
        }

        // Extract body
        let (plainText, htmlText) = extractBody(from: payload)

        // Create DownloadedEmail
        return DownloadedEmail(
            messageID: message.id,
            googleAccountEmail: accountEmail,
            subject: subject,
            fromEmail: fromEmail,
            fromName: fromName,
            toEmails: toEmails,
            ccEmails: ccEmails,
            date: date,
            bodyPlainText: plainText,
            bodyHTML: htmlText,
            snippet: message.snippet ?? "",
            labels: message.labelIds ?? [],
            isRead: !(message.labelIds?.contains("UNREAD") ?? false),
            isStarred: message.labelIds?.contains("STARRED") ?? false
        )
    }

    /// Parse email address from header value
    /// Example: "John Doe <john@example.com>" -> ("john@example.com", "John Doe")
    private func parseEmailAddress(_ value: String) -> (email: String, name: String?) {
        // Simple regex to extract email and name
        let pattern = "(?:\"?([^\"<]+)\"?\\s*)?<([^>]+)>|([^<>]+)"

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else {
            return (value.trimmingCharacters(in: .whitespaces), nil)
        }

        let nameRange = Range(match.range(at: 1), in: value)
        let emailRange = Range(match.range(at: 2), in: value)
        let simpleEmailRange = Range(match.range(at: 3), in: value)

        if let emailRange = emailRange {
            let email = String(value[emailRange])
            let name = nameRange.map { String(value[$0]).trimmingCharacters(in: .whitespaces) }
            return (email, name)
        } else if let simpleEmailRange = simpleEmailRange {
            let email = String(value[simpleEmailRange]).trimmingCharacters(in: .whitespaces)
            return (email, nil)
        }

        return (value.trimmingCharacters(in: .whitespaces), nil)
    }

    /// Parse comma-separated email addresses
    private func parseEmailAddressList(_ value: String) -> [String] {
        return value.split(separator: ",")
            .map { parseEmailAddress(String($0)).email }
    }

    /// Extract plain text and HTML body from message payload
    private func extractBody(from payload: MessagePayload) -> (plain: String?, html: String?) {
        var plainText: String?
        var htmlText: String?

        // Check direct body
        if let bodyData = payload.body?.data {
            plainText = decodeBase64URL(bodyData)
        }

        // Check parts
        if let parts = payload.parts {
            for part in parts {
                if part.mimeType == "text/plain", let bodyData = part.body?.data {
                    plainText = decodeBase64URL(bodyData)
                } else if part.mimeType == "text/html", let bodyData = part.body?.data {
                    htmlText = decodeBase64URL(bodyData)
                }

                // Recursively check nested parts
                if let nestedParts = part.parts {
                    let (nestedPlain, nestedHTML) = extractBodyFromParts(nestedParts)
                    plainText = plainText ?? nestedPlain
                    htmlText = htmlText ?? nestedHTML
                }
            }
        }

        return (plainText, htmlText)
    }

    /// Extract body from nested parts
    private func extractBodyFromParts(_ parts: [MessagePart]) -> (plain: String?, html: String?) {
        var plainText: String?
        var htmlText: String?

        for part in parts {
            if part.mimeType == "text/plain", let bodyData = part.body?.data {
                plainText = decodeBase64URL(bodyData)
            } else if part.mimeType == "text/html", let bodyData = part.body?.data {
                htmlText = decodeBase64URL(bodyData)
            }

            if let nestedParts = part.parts {
                let (nestedPlain, nestedHTML) = extractBodyFromParts(nestedParts)
                plainText = plainText ?? nestedPlain
                htmlText = htmlText ?? nestedHTML
            }
        }

        return (plainText, htmlText)
    }

    /// Decode base64url encoded string
    private func decodeBase64URL(_ string: String) -> String? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
