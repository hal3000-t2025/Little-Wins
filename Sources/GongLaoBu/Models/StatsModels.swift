import Foundation

struct DailyCompletionCount: Identifiable {
    var id: Date { date }
    var date: Date
    var count: Int
}

struct QuadrantCompletionCount: Identifiable {
    var id: String { title }
    var title: String
    var count: Int
    var quadrant: TaskQuadrant?
}

struct DelaySummary: Identifiable {
    var id: UUID { task.id }
    var task: TaskItem
    var count: Int
}
