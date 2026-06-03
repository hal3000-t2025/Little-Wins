import Foundation

enum TaskAIService {
    static let categories = [
        "工作",
        "学习",
        "健康",
        "财务",
        "家庭",
        "创作",
        "社交",
        "生活杂事",
        "其他"
    ]

    static func classify(tasks: [TaskItem], client: DeepSeekClient) async throws -> [UUID: String] {
        guard !tasks.isEmpty else { return [:] }

        let payload = TaskClassificationInput(
            items: tasks.map { TaskClassificationInput.Item(id: $0.id.uuidString, title: $0.title) }
        )
        let inputData = try JSONEncoder().encode(payload)
        let input = String(data: inputData, encoding: .utf8) ?? "{}"

        let system = """
        你是个人功劳簿任务分类器。只能从这些分类中选择一个：\(categories.joined(separator: "、"))。
        返回严格 JSON，不要 Markdown，不要解释。
        JSON 格式：{"items":[{"id":"任务id","category":"分类"}]}
        """
        let user = """
        请给以下事项分类：
        \(input)
        """

        let content = try await client.completeJSON(system: system, user: user)
        let data = Data(content.utf8)
        let response = try JSONDecoder().decode(TaskClassificationResponse.self, from: data)

        var result: [UUID: String] = [:]
        for item in response.items {
            guard let id = UUID(uuidString: item.id) else { continue }
            result[id] = categories.contains(item.category) ? item.category : "其他"
        }
        return result
    }
}

private struct TaskClassificationInput: Encodable {
    var items: [Item]

    struct Item: Encodable {
        var id: String
        var title: String
    }
}

private struct TaskClassificationResponse: Decodable {
    var items: [Item]

    struct Item: Decodable {
        var id: String
        var category: String
    }
}
