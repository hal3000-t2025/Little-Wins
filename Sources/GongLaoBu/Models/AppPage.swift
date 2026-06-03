import Foundation

enum AppPage: String, CaseIterable, Hashable, Identifiable {
    case inbox
    case quadrants
    case calendar
    case ledger
    case statistics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox:
            "Inbox"
        case .quadrants:
            "权重"
        case .calendar:
            "日历"
        case .ledger:
            "功劳簿"
        case .statistics:
            "统计"
        }
    }

    var symbolName: String {
        switch self {
        case .inbox:
            "tray.and.arrow.down.fill"
        case .quadrants:
            "square.grid.2x2.fill"
        case .calendar:
            "calendar"
        case .ledger:
            "checklist.checked"
        case .statistics:
            "chart.bar.xaxis"
        }
    }
}
