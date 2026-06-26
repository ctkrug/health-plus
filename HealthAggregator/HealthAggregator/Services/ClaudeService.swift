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
    /// Conversation model — fast/cheap, many turns.
    private let model = "claude-haiku-4-5-20251001"
    /// Extraction model — forced tool use with a fixed schema; Haiku handles this well and is ~20x cheaper.
    static let extractionModel = "claude-haiku-4-5-20251001"

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

    /// Forces Claude to call a single named tool and returns the tool's `input` JSON object.
    ///
    /// This is the reliable way to get structured data out of a model: with `tool_choice` pinned to
    /// one tool, the output is constrained to that tool's `input_schema` — no prose, no fenced-JSON
    /// guessing, no "say that's everything" loop. Used to turn a free-form setup chat into habits.
    func runTool(model: String? = nil,
                 system: String,
                 messages: [ClaudeMessage],
                 toolName: String,
                 toolDescription: String,
                 inputSchema: [String: Any]) async throws -> [String: Any] {
        guard hasKey else { throw ClaudeError.noApiKey }

        let body: [String: Any] = [
            "model": model ?? self.model,
            "max_tokens": 1024,
            "system": system,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "tools": [[
                "name": toolName,
                "description": toolDescription,
                "input_schema": inputSchema,
            ]],
            "tool_choice": ["type": "tool", "name": toolName],
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ClaudeError.apiError(status: status)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw ClaudeError.apiError(status: -1)
        }
        for block in content where block["type"] as? String == "tool_use" {
            if let input = block["input"] as? [String: Any] { return input }
        }
        throw ClaudeError.apiError(status: -2)   // model returned no tool call
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
