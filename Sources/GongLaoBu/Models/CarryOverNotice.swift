import Foundation

struct CarryOverNotice: Identifiable, Equatable {
    let id = UUID()
    var count: Int
    var includesOlderTasks: Bool

    var title: String {
        if includesOlderTasks {
            return "\(count) 件未完成事项已转入今天 Inbox"
        }
        return "昨天 \(count) 件未完成，已转入今天 Inbox"
    }
}
