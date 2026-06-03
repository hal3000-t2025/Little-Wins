import Foundation

enum LedgerDateFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "全部"
        case .today:
            "今天"
        case .week:
            "本周"
        case .month:
            "本月"
        case .year:
            "本年"
        }
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        switch self {
        case .all:
            true
        case .today:
            calendar.isDate(date, inSameDayAs: .now)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: .now)?.contains(date) ?? false
        case .month:
            calendar.dateInterval(of: .month, for: .now)?.contains(date) ?? false
        case .year:
            calendar.dateInterval(of: .year, for: .now)?.contains(date) ?? false
        }
    }
}

enum LedgerQuadrantFilter: Hashable, Identifiable {
    case all
    case unassigned
    case quadrant(TaskQuadrant)

    static var allCases: [LedgerQuadrantFilter] {
        [.all] + TaskQuadrant.allCases.map { .quadrant($0) } + [.unassigned]
    }

    var id: String {
        switch self {
        case .all:
            "all"
        case .unassigned:
            "unassigned"
        case .quadrant(let quadrant):
            quadrant.rawValue
        }
    }

    var title: String {
        switch self {
        case .all:
            "全部象限"
        case .unassigned:
            "未分配"
        case .quadrant(let quadrant):
            quadrant.title
        }
    }

    func matches(_ quadrant: TaskQuadrant?) -> Bool {
        switch self {
        case .all:
            true
        case .unassigned:
            quadrant == nil
        case .quadrant(let expected):
            quadrant == expected
        }
    }
}
