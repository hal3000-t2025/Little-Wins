import Foundation

struct LedgerStats {
    var today: Int
    var week: Int
    var month: Int
    var year: Int
    var total: Int
}

struct CompletedTaskGroup: Identifiable {
    var id: Date { date }
    var date: Date
    var tasks: [TaskItem]
}
