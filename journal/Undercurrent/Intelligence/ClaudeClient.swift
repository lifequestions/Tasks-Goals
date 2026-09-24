import Foundation

/// Talks to the Claude Messages API directly from the phone. Fine for a journal
/// only you use, with your own key in the Keychain. If this ever ships to other
/// people, put a small server in between so the key never leaves it.
struct ClaudeClient {
    static let defaultModel = "claude-opus-5"

    struct Choice: Identifiable {
        let id: String
        let label: String
    }

    static let models = [
        Choice(id: "claude-opus-5", label: "Claude Opus 5 — deepest reading"),
        Choice(id: "claude-sonnet-5", label: "Claude Sonnet 5 — faster, cheaper"),
    ]

    var apiKey: String
    var model: String

    enum Failure: LocalizedError {
        case http(Int, String)
        case declined
        case cutOff
        case empty

        var errorDescription: String? {
            switch self {
            case .http(let code, let message): "Claude said \(code): \(message)"
            case .declined: "Claude declined to read this one."
            case .cutOff: "The answer ran out of room before it finished."
            case .empty: "Claude sent back nothing to read."
            }
        }
    }

    private struct Response: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        let content: [Block]
        let stop_reason: String?
    }

    private struct ErrorBody: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }

    /// Sends one request whose answer must match `schema`, and decodes it as `T`.
    func structured<T: Decodable>(_: T.Type,
                                  system: String,
                                  user: String,
                                  schema: [String: Any],
                                  effort: String,
                                  maxTokens: Int) async throws -> T {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "thinking": ["type": "adaptive"],
            "output_config": [
                "effort": effort,
                "format": ["type": "json_schema", "schema": schema],
            ],
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // If Opus's safety classifiers decline something — a journal can be dark —
        // let the API retry it on its recommended fallback model rather than fail.
        if model == "claude-opus-5" {
            body["fallbacks"] = "default"
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8) ?? "no detail"
            throw Failure.http(status, message)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        switch decoded.stop_reason ?? "" {
        case "refusal": throw Failure.declined
        case "max_tokens": throw Failure.cutOff
        default: break
        }
        // Thinking blocks come first; the structured answer is the text block.
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else { throw Failure.empty }
        return try JSONDecoder().decode(T.self, from: Data(text.utf8))
    }
}
