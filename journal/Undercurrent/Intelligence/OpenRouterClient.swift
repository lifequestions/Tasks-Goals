import Foundation

/// Anything that can read the journal: Claude directly, or a model through OpenRouter.
protocol AIClient {
    func structured<T: Decodable>(_ type: T.Type, system: String, user: String,
                                  schema: [String: Any], effort: String, maxTokens: Int) async throws -> T
}

extension AIClient {
    func structured<T: Decodable>(_ type: T.Type, system: String, user: String,
                                  schema: [String: Any], effort: String = "medium") async throws -> T {
        try await structured(type, system: system, user: user, schema: schema, effort: effort, maxTokens: 16_000)
    }

    /// A cheap round trip for Settings.
    func check() async throws {
        struct Ok: Decodable { let ok: Bool }
        _ = try await structured(Ok.self,
                                 system: "Reply with ok: true.",
                                 user: "Are you there?",
                                 schema: ["type": "object",
                                          "properties": ["ok": ["type": "boolean"]],
                                          "required": ["ok"],
                                          "additionalProperties": false],
                                 effort: "low",
                                 maxTokens: 2_000)
    }
}

extension ClaudeClient: AIClient {}

/// Uses OpenRouter's credits and its OpenAI-style chat endpoint. The default
/// model is still Claude, so readings match the direct route; any model on
/// openrouter.ai/models can be typed in instead.
struct OpenRouterClient: AIClient {
    static let defaultModel = "anthropic/claude-opus-5"

    var apiKey: String
    var model: String

    private struct Response: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
            let finish_reason: String?
        }
        struct Failure: Decodable { let message: String }
        let choices: [Choice]?
        let error: Failure?
    }

    func structured<T: Decodable>(_: T.Type, system: String, user: String,
                                  schema: [String: Any], effort: String, maxTokens: Int) async throws -> T {
        let schemaText = String(decoding: try JSONSerialization.data(withJSONObject: schema, options: [.sortedKeys]),
                                as: UTF8.self)
        // Not every model on OpenRouter honours response_format, so the schema
        // is also spelled out in the instructions and the reply parsed leniently.
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system",
                 "content": system + "\n\nReply with one JSON object and nothing else. It must match this JSON Schema:\n" + schemaText],
                ["role": "user", "content": user],
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": "reply", "strict": true, "schema": schema],
            ],
        ]

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        request.setValue("Undercurrent", forHTTPHeaderField: "x-title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoded = try? JSONDecoder().decode(Response.self, from: data)
        guard status == 200, let choice = decoded?.choices?.first else {
            let message = decoded?.error?.message ?? String(data: data, encoding: .utf8) ?? "no detail"
            throw ClaudeClient.Failure.http(status, message)
        }
        if choice.finish_reason == "length" { throw ClaudeClient.Failure.cutOff }
        guard let text = choice.message.content, let json = Self.jsonObject(in: text) else {
            throw ClaudeClient.Failure.empty
        }
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    /// The Claude models OpenRouter offers right now (its model list is public).
    static func claudeModels() async throws -> [String] {
        struct List: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://openrouter.ai/api/v1/models")!)
        return try JSONDecoder().decode(List.self, from: data).data
            .map(\.id)
            .filter { $0.hasPrefix("anthropic/claude") && !$0.contains(":") }
            .sorted()
    }

    /// The newest Opus if there is one, else the newest Sonnet.
    static func best(of ids: [String]) -> String? {
        ids.filter { $0.contains("opus") }.max() ?? ids.filter { $0.contains("sonnet") }.max() ?? ids.max()
    }

    /// Makes sure the saved model is one OpenRouter actually has.
    static func settleModel() async {
        guard let ids = try? await claudeModels(), !ids.isEmpty else { return }
        let saved = UserDefaults.standard.string(forKey: Prefs.openRouterModel) ?? ""
        if saved.isEmpty || !ids.contains(saved), let pick = best(of: ids) {
            UserDefaults.standard.set(pick, forKey: Prefs.openRouterModel)
        }
    }

    /// The outermost {...} in the reply, ignoring code fences or stray words around it.
    static func jsonObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        return String(text[start...end])
    }
}
