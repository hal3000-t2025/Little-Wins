import Foundation

struct TaskItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var createdAt: Date
    var plannedDate: Date
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
        self.completedAt = completedAt
        self.quadrant = quadrant
        self.sortOrder = sortOrder
        self.carryOverCount = carryOverCount
        self.aiCategory = aiCategory
    }
}
