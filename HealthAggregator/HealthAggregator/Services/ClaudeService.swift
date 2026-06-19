import Foundation

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessage]
}

struct ClaudeResponse: Codable {
    struct Content: Codable { let text: String }
    let content: [Content]
}

final class ClaudeService {
    static let shared = ClaudeService()
    private let endpoint = "https://api.anthropic.com/v1/messages"
    private let model = "claude-haiku-4-5-20251001"

    // Key is bundled in Info.plist under "AnthropicAPIKey" — no user setup required.
    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "AnthropicAPIKey") as? String ?? ""
    }

    var hasKey: Bool { !apiKey.isEmpty }

    func send(system: String, history: [ClaudeMessage], userMessage: String) async throws -> String {
        guard hasKey else { throw ClaudeError.noApiKey }

        var messages = history
        messages.append(ClaudeMessage(role: "user", content: userMessage))

        let body = ClaudeRequest(
            model: model,
            max_tokens: 1024,
            system: system,
            messages: messages
        )

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ClaudeError.apiError(status: status)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }
}

enum ClaudeError: Error, LocalizedError {
    case noApiKey
    case apiError(status: Int)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "AI coach is unavailable right now. Try the Library or add habits manually."
        case .apiError(let status):
            return "Couldn't reach the AI coach (error \(status)). Please try again in a moment."
        }
    }
}
