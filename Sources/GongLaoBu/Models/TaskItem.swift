import Foundation

struct TaskItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var createdAt: Date
    var plannedDate: Date
    var isDateAssigned: Bool
    var completedAt: Date?
    var quadrant: TaskQuadrant?
    var sortOrder: Int
    var carryOverCount: Int
    var aiCategory: String?

    var isCompleted: Bool {
        completedAt != nil
    }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        plannedDate: Date,
        isDateAssigned: Bool = false,
        completedAt: Date? = nil,
        quadrant: TaskQuadrant? = nil,
        sortOrder: Int,
        carryOverCount: Int = 0,
        aiCategory: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.plannedDate = plannedDate
        self.isDateAssigned = isDateAssigned
        self.completedAt = completedAt
        self.quadrant = quadrant
        self.sortOrder = sortOrder
        self.carryOverCount = carryOverCount
        self.aiCategory = aiCategory
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case plannedDate
        case isDateAssigned
        case completedAt
        case quadrant
        case sortOrder
        case carryOverCount
        case aiCategory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        plannedDate = try container.decode(Date.self, forKey: .plannedDate)
        isDateAssigned = try container.decodeIfPresent(Bool.self, forKey: .isDateAssigned) ?? true
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        quadrant = try container.decodeIfPresent(TaskQuadrant.self, forKey: .quadrant)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        carryOverCount = try container.decodeIfPresent(Int.self, forKey: .carryOverCount) ?? 0
        aiCategory = try container.decodeIfPresent(String.self, forKey: .aiCategory)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(plannedDate, forKey: .plannedDate)
        try container.encode(isDateAssigned, forKey: .isDateAssigned)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(quadrant, forKey: .quadrant)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(carryOverCount, forKey: .carryOverCount)
        try container.encodeIfPresent(aiCategory, forKey: .aiCategory)
    }
}
