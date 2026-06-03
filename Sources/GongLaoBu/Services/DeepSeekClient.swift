import Foundation

struct DeepSeekClient {
    var apiKey: String
    var model: String = "deepseek-v4-flash"
    var baseURL = URL(string: "https://api.deepseek.com")!

    func validate() async throws {
        _ = try await complete(
            messages: [
                DeepSeekMessage(role: "system", content: "You are a connection test endpoint."),
                DeepSeekMessage(role: "user", content: "Reply with exactly: ok")
            ],
            maxTokens: 12,
            temperature: 0,
            wantsJSON: false
        )
    }

    func completeJSON(system: String, user: String, maxTokens: Int = 1600) async throws -> String {
        try await complete(
            messages: [
                DeepSeekMessage(role: "system", content: system),
                DeepSeekMessage(role: "user", content: user)
            ],
            maxTokens: maxTokens,
            temperature: 0,
            wantsJSON: true
        )
    }

    private func complete(
        messages: [DeepSeekMessage],
        maxTokens: Int,
        temperature: Double,
        wantsJSON: Bool
    ) async throws -> String {
        let body = DeepSeekChatRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
            stream: false,
            thinking: DeepSeekThinking(type: "disabled"),
            responseFormat: wantsJSON ? DeepSeekResponseFormat(type: "json_object") : nil
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw DeepSeekClientError.http(status: httpResponse.statusCode, message: message)
        }

        let chatResponse = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content, !content.isEmpty else {
            throw DeepSeekClientError.emptyContent
        }
        return content
    }
}

enum DeepSeekClientError: LocalizedError {
    case invalidResponse
    case emptyContent
    case http(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "DeepSeek 返回了无效响应。"
        case .emptyContent:
            "DeepSeek 返回内容为空。"
        case .http(let status, let message):
            "DeepSeek 请求失败：HTTP \(status) \(message)"
        }
    }
}

struct DeepSeekMessage: Codable {
    var role: String
    var content: String
}

private struct DeepSeekThinking: Codable {
    var type: String
}

private struct DeepSeekResponseFormat: Codable {
    var type: String
}

private struct DeepSeekChatRequest: Codable {
    var model: String
    var messages: [DeepSeekMessage]
    var maxTokens: Int
    var temperature: Double
    var stream: Bool
    var thinking: DeepSeekThinking
    var responseFormat: DeepSeekResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case stream
        case thinking
        case responseFormat = "response_format"
    }
}

private struct DeepSeekChatResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String
    }
}
