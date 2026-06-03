import Foundation

enum TaskQuadrant: String, CaseIterable, Codable, Hashable, Identifiable {
    case urgentImportant
    case importantNotUrgent
    case urgentNotImportant
    case neither

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urgentImportant:
            "紧急重要"
        case .importantNotUrgent:
            "重要不紧急"
        case .urgentNotImportant:
            "紧急不重要"
        case .neither:
            "不紧急不重要"
        }
    }

    var symbolName: String {
        switch self {
        case .urgentImportant:
            "flame.fill"
        case .importantNotUrgent:
            "star.fill"
        case .urgentNotImportant:
            "bolt.fill"
        case .neither:
            "tray.fill"
        }
    }

    var sortRank: Int {
        switch self {
        case .urgentImportant:
            0
        case .importantNotUrgent:
            1
        case .urgentNotImportant:
            2
        case .neither:
            3
        }
    }
}
